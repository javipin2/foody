import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { CheckoutPlanDto } from './dto/checkout-plan.dto';
import { SincronizarPagoDto } from './dto/sincronizar-pago.dto';
import {
  PRECIO_PLAN_CENTAVOS,
  PlanPago,
  esPlanPago,
} from './pagos-planes.config';
import { WompiEvento, WompiService } from './wompi.service';

@Injectable()
export class PagosService {
  private readonly logger = new Logger(PagosService.name);

  constructor(
    private readonly database: DatabaseService,
    private readonly wompi: WompiService,
    private readonly config: ConfigService,
  ) {}

  async crearCheckout(usuario: JwtPayload, dto: CheckoutPlanDto) {
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Solo dueños de restaurante pueden pagar un plan');
    }
    if (usuario.rol !== 'admin') {
      throw new ForbiddenException('Solo el administrador del restaurante puede mejorar el plan');
    }
    if (!this.wompi.estaConfigurado()) {
      throw new BadRequestException(
        'Pasarela de pago no configurada en el servidor',
      );
    }

    const plan = dto.plan;
    if (!esPlanPago(plan)) {
      throw new BadRequestException('Plan no válido para pago');
    }

    const restaurante = await this.database.consultarUno<{ nombre: string }>(
      `SELECT nombre FROM restaurantes WHERE id = $1`,
      [usuario.restaurante_id],
    );
    if (!restaurante) throw new NotFoundException('Restaurante no encontrado');

    const referencia = this.wompi.generarReferenciaInterna();
    const monto = PRECIO_PLAN_CENTAVOS[plan];

    const pago = await this.database.consultarUno<{ id: string }>(
      `INSERT INTO pagos_suscripcion (
         restaurante_id, usuario_id, plan, monto_centavos, referencia_interna
       ) VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [usuario.restaurante_id, usuario.sub, plan, monto, referencia],
    );

    const redirectBase =
      this.config.get<string>('WOMPI_REDIRECT_URL')?.trim() ||
      'http://localhost:8080/admin/panel?seccion=mejorar_plan';
    const separador = redirectBase.includes('?') ? '&' : '?';
    const redirect = `${redirectBase}${separador}pago_id=${pago!.id}`;

    const enlace = await this.wompi.crearEnlacePago({
      nombre: `Foody plan ${plan}`,
      descripcion: `Suscripción mensual Foody — ${restaurante.nombre}`,
      montoCentavos: monto,
      referenciaInterna: referencia,
      redirectUrl: redirect,
    });

    await this.database.consultar(
      `UPDATE pagos_suscripcion SET
         payment_link_id = $2, referencia_wompi = $3, updated_at = now()
       WHERE id = $1`,
      [pago!.id, enlace.id, referencia],
    );

    return {
      pago_id: pago!.id,
      plan,
      monto_centavos: monto,
      monto_cop: monto / 100,
      checkout_url: enlace.url,
      payment_link_id: enlace.id,
      referencia_interna: referencia,
      clave_publica: this.wompi.clavePublica(),
    };
  }

  async estadoRestaurante(restauranteId: string) {
    const suscripcion = await this.database.consultarUno<{
      estado: string;
      plan: string;
      fecha_vencimiento: Date;
    }>(
      `SELECT estado, plan, fecha_vencimiento
       FROM suscripciones_restaurante WHERE restaurante_id = $1`,
      [restauranteId],
    );

    const ultimoPago = await this.database.consultarUno<{
      id: string;
      plan: string;
      estado: string;
      monto_centavos: number;
      created_at: Date;
      checkout_url: string | null;
    }>(
      `SELECT p.id, p.plan, p.estado, p.monto_centavos, p.created_at,
              NULL::text AS checkout_url
       FROM pagos_suscripcion p
       WHERE p.restaurante_id = $1
       ORDER BY p.created_at DESC
       LIMIT 1`,
      [restauranteId],
    );

    return {
      suscripcion,
      ultimo_pago: ultimoPago,
      precios: PRECIO_PLAN_CENTAVOS,
    };
  }

  /**
   * Tras pagar en Wompi (sandbox o prod), sincroniza el plan si el webhook no llegó (localhost).
   */
  async sincronizarPago(restauranteId: string, dto: SincronizarPagoDto) {
    let pago = dto.pago_id
      ? await this.database.consultarUno<{
          id: string;
          restaurante_id: string;
          plan: PlanPago;
          estado: string;
          monto_centavos: number;
          payment_link_id: string | null;
          referencia_interna: string;
        }>(
          `SELECT id, restaurante_id, plan, estado, monto_centavos,
                  payment_link_id, referencia_interna
           FROM pagos_suscripcion
           WHERE id = $1 AND restaurante_id = $2`,
          [dto.pago_id, restauranteId],
        )
      : await this.database.consultarUno<{
          id: string;
          restaurante_id: string;
          plan: PlanPago;
          estado: string;
          monto_centavos: number;
          payment_link_id: string | null;
          referencia_interna: string;
        }>(
          `SELECT id, restaurante_id, plan, estado, monto_centavos,
                  payment_link_id, referencia_interna
           FROM pagos_suscripcion
           WHERE restaurante_id = $1 AND estado = 'pendiente'
           ORDER BY created_at DESC LIMIT 1`,
          [restauranteId],
        );

    if (!pago) {
      throw new NotFoundException('No hay un pago pendiente para sincronizar');
    }
    if (pago.restaurante_id !== restauranteId) {
      throw new ForbiddenException('El pago no pertenece a este restaurante');
    }
    if (pago.estado === 'aprobado') {
      return {
        sincronizado: true,
        motivo: 'ya_aprobado',
        plan: pago.plan,
        pago_id: pago.id,
      };
    }

    if (!dto.transaccion_wompi_id?.trim()) {
      throw new BadRequestException(
        'Indica el ID de transacción Wompi del comprobante (ej. 1969957-1782290934-46563)',
      );
    }

    const tx = await this.wompi.consultarTransaccion(dto.transaccion_wompi_id);

    if (tx.payment_link_id && pago.payment_link_id && tx.payment_link_id !== pago.payment_link_id) {
      throw new BadRequestException('La transacción no corresponde a este checkout');
    }
    if (tx.amount_in_cents !== pago.monto_centavos) {
      throw new BadRequestException('El monto de la transacción no coincide con el plan');
    }

    if (tx.status === 'APPROVED') {
      await this.aprobarPago(pago, {
        transaccionId: tx.id,
        metodo: tx.payment_method_type,
        referenciaWompi: tx.reference,
      });
      return {
        sincronizado: true,
        plan: pago.plan,
        pago_id: pago.id,
        transaccion_wompi_id: tx.id,
      };
    }

    if (['DECLINED', 'VOIDED', 'ERROR'].includes(tx.status)) {
      await this.database.consultar(
        `UPDATE pagos_suscripcion SET
           estado = 'rechazado',
           transaccion_wompi_id = $2,
           metodo = COALESCE($3, metodo),
           updated_at = now()
         WHERE id = $1`,
        [pago.id, tx.id, tx.payment_method_type],
      );
      throw new BadRequestException(`El pago fue ${tx.status.toLowerCase()} en Wompi`);
    }

    return {
      sincronizado: false,
      motivo: `transaccion_${tx.status.toLowerCase()}`,
      pago_id: pago.id,
    };
  }

  private async aprobarPago(
    pago: { id: string; restaurante_id: string; plan: PlanPago },
    tx: { transaccionId: string; metodo: string | null; referenciaWompi: string },
  ) {
    const yaProcesado = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM pagos_suscripcion
       WHERE transaccion_wompi_id = $1 AND estado = 'aprobado'`,
      [tx.transaccionId],
    );
    if (yaProcesado) return;

    await this.database.enTransaccion(async (client) => {
      await client.query(
        `UPDATE pagos_suscripcion SET
           estado = 'aprobado',
           metodo = $2,
           transaccion_wompi_id = $3,
           referencia_wompi = COALESCE($4, referencia_wompi),
           updated_at = now()
         WHERE id = $1`,
        [pago.id, tx.metodo, tx.transaccionId, tx.referenciaWompi],
      );

      await client.query(
        `UPDATE suscripciones_restaurante SET
           estado = 'activa',
           plan = $2,
           fecha_vencimiento = now() + interval '30 days',
           motivo_bloqueo = NULL
         WHERE restaurante_id = $1`,
        [pago.restaurante_id, pago.plan],
      );

      await client.query(
        `UPDATE suscripciones_restaurante SET
           aviso_3d_enviado_at = NULL,
           aviso_vence_hoy_enviado_at = NULL
         WHERE restaurante_id = $1`,
        [pago.restaurante_id],
      );
    });

    this.logger.log(
      `Pago aprobado restaurante=${pago.restaurante_id} plan=${pago.plan}`,
    );
  }

  async procesarWebhookWompi(
    eventoRaw: Record<string, unknown>,
    checksumHeader?: string,
  ): Promise<{ procesado: boolean; motivo?: string }> {
    const evento = eventoRaw as unknown as WompiEvento;
    if (!this.wompi.validarFirmaEvento(evento, checksumHeader)) {
      this.logger.warn('Webhook Wompi con firma inválida');
      throw new BadRequestException('Firma de evento inválida');
    }

    if (evento.event !== 'transaction.updated') {
      return { procesado: false, motivo: 'evento_ignorado' };
    }

    const tx = evento.data['transaction'] as Record<string, unknown> | undefined;
    if (!tx) {
      return { procesado: false, motivo: 'sin_transaccion' };
    }

    const estadoTx = String(tx['status'] ?? '');
    const transaccionId = String(tx['id'] ?? '');
    const paymentLinkId = tx['payment_link_id']
      ? String(tx['payment_link_id'])
      : null;
    const sku = tx['sku'] ? String(tx['sku']) : null;
    const metodo = tx['payment_method_type']
      ? String(tx['payment_method_type'])
      : null;

    if (!transaccionId) {
      return { procesado: false, motivo: 'sin_id_transaccion' };
    }

    const pago = await this.buscarPagoPendiente(paymentLinkId, sku);
    if (!pago) {
      return { procesado: false, motivo: 'pago_no_encontrado' };
    }

    if (estadoTx === 'APPROVED') {
      const yaProcesado = await this.database.consultarUno<{ id: string }>(
        `SELECT id FROM pagos_suscripcion
         WHERE transaccion_wompi_id = $1 AND estado = 'aprobado'`,
        [transaccionId],
      );
      if (yaProcesado) {
        return { procesado: true, motivo: 'idempotente' };
      }

      await this.aprobarPago(pago, {
        transaccionId,
        metodo,
        referenciaWompi: String(tx['reference'] ?? ''),
      });

      return { procesado: true };
    }

    if (['DECLINED', 'VOIDED', 'ERROR'].includes(estadoTx)) {
      await this.database.consultar(
        `UPDATE pagos_suscripcion SET
           estado = 'rechazado',
           transaccion_wompi_id = COALESCE(transaccion_wompi_id, $2),
           metodo = COALESCE($3, metodo),
           updated_at = now()
         WHERE id = $1 AND estado = 'pendiente'`,
        [pago.id, transaccionId, metodo],
      );
      return { procesado: true, motivo: `transaccion_${estadoTx.toLowerCase()}` };
    }

    return { procesado: false, motivo: `estado_${estadoTx}` };
  }

  private async buscarPagoPendiente(
    paymentLinkId: string | null,
    sku: string | null,
  ) {
    if (paymentLinkId) {
      const porLink = await this.database.consultarUno<{
        id: string;
        restaurante_id: string;
        plan: PlanPago;
      }>(
        `SELECT id, restaurante_id, plan FROM pagos_suscripcion
         WHERE payment_link_id = $1
         ORDER BY created_at DESC LIMIT 1`,
        [paymentLinkId],
      );
      if (porLink) return porLink;
    }

    if (sku) {
      return this.database.consultarUno<{
        id: string;
        restaurante_id: string;
        plan: PlanPago;
      }>(
        `SELECT id, restaurante_id, plan FROM pagos_suscripcion
         WHERE referencia_interna = $1
         ORDER BY created_at DESC LIMIT 1`,
        [sku],
      );
    }

    return null;
  }
}
