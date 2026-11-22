import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { ROL_GERENTE_CADENA } from '../../core/auth/roles-food';
import {
  PRECIO_PLAN_CENTAVOS,
  PlanPago,
  esPlanPago,
} from './pagos-planes.config';
import { WompiService } from './wompi.service';

type FuentePagoRow = {
  id: string;
  restaurante_id: string;
  wompi_payment_source_id: string;
  tipo: string;
  estado_wompi: string | null;
  ultimos_cuatro: string | null;
  marca: string | null;
  customer_email: string | null;
  activa: boolean;
  ultimo_cobro_at: Date | null;
  ultimo_intento_at: Date | null;
};

type SuscripcionRenovacion = {
  restaurante_id: string;
  plan: string;
  estado: string;
  fecha_vencimiento: Date;
  fuente_id: string;
  wompi_payment_source_id: string;
  customer_email: string | null;
};

/** Renovación automática con fuentes de pago Wompi (P1-10). */
@Injectable()
export class PagosRecurrentesService {
  private readonly logger = new Logger(PagosRecurrentesService.name);

  constructor(
    private readonly database: DatabaseService,
    private readonly wompi: WompiService,
  ) {}

  async obtenerFuenteActiva(
    restauranteId: string,
  ): Promise<FuentePagoRow | null> {
    return this.database.consultarUno<FuentePagoRow>(
      `SELECT id, restaurante_id, wompi_payment_source_id, tipo, estado_wompi,
              ultimos_cuatro, marca, customer_email, activa,
              ultimo_cobro_at, ultimo_intento_at
       FROM fuentes_pago
       WHERE restaurante_id = $1 AND activa = true
       LIMIT 1`,
      [restauranteId],
    );
  }

  resumenFuente(fuente: FuentePagoRow | null) {
    if (!fuente) return null;
    return {
      activa: fuente.activa,
      tipo: fuente.tipo,
      ultimos_cuatro: fuente.ultimos_cuatro,
      marca: fuente.marca,
      renovacion_automatica: true,
      ultimo_cobro_at: fuente.ultimo_cobro_at,
    };
  }

  /**
   * Tras un pago aprobado, guarda la fuente Wompi si la transacción la incluye.
   */
  async registrarFuenteDesdeTransaccion(
    restauranteId: string,
    transaccionId: string,
    paymentSourceIdDirecto?: string | null,
  ): Promise<void> {
    if (!this.wompi.estaConfigurado()) return;

    let paymentSourceId = paymentSourceIdDirecto?.trim() || null;
    let customerEmail: string | null = null;
    let metodo: string | null = null;

    try {
      const tx = await this.wompi.consultarTransaccion(transaccionId);
      paymentSourceId = paymentSourceId ?? tx.payment_source_id;
      customerEmail = tx.customer_email;
      metodo = tx.payment_method_type;
    } catch (e) {
      const mensaje = e instanceof Error ? e.message : String(e);
      this.logger.error(
        `No se pudo consultar TX ${transaccionId} para fuente: ${mensaje}`,
      );
      // BN-EXC-03: sin source id no hay renovación — fallar para que pagos.service audite.
      if (!paymentSourceId) {
        throw new BadRequestException(
          `No se pudo obtener fuente de pago desde la transacción: ${mensaje}`,
        );
      }
    }

    if (!paymentSourceId) {
      throw new BadRequestException(
        'La transacción aprobada no incluye payment_source_id (renovación automática no disponible)',
      );
    }

    let ultimosCuatro: string | null = null;
    let marca: string | null = null;
    let estadoWompi: string | null = null;
    let tipo = this.mapearTipoFuente(metodo);

    try {
      const fuente = await this.wompi.consultarFuentePago(paymentSourceId);
      estadoWompi = fuente.status;
      tipo = fuente.type ?? tipo;
      ultimosCuatro = fuente.public_data?.last_four ?? null;
      marca = fuente.public_data?.brand ?? null;
      if (!['AVAILABLE', 'APPROVED'].includes(fuente.status)) {
        this.logger.error(
          `Fuente Wompi ${paymentSourceId} no disponible: ${fuente.status}`,
        );
      }
    } catch (e) {
      // BN-EXC-04: no tumbar el registro del source id; metadata queda null y queda auditable vía log.
      const mensaje = e instanceof Error ? e.message : String(e);
      this.logger.error(
        `Consulta fuente ${paymentSourceId} falló (se guarda id sin metadata): ${mensaje}`,
      );
      estadoWompi = estadoWompi ?? 'consulta_fallida';
    }

    await this.database.consultar(
      `UPDATE fuentes_pago SET activa = false, updated_at = now()
       WHERE restaurante_id = $1 AND activa = true
         AND wompi_payment_source_id <> $2`,
      [restauranteId, paymentSourceId],
    );

    await this.database.consultar(
      `INSERT INTO fuentes_pago (
         restaurante_id, wompi_payment_source_id, tipo, estado_wompi,
         ultimos_cuatro, marca, customer_email, activa
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, true)
       ON CONFLICT (restaurante_id, wompi_payment_source_id)
       DO UPDATE SET
         tipo = EXCLUDED.tipo,
         estado_wompi = EXCLUDED.estado_wompi,
         ultimos_cuatro = COALESCE(EXCLUDED.ultimos_cuatro, fuentes_pago.ultimos_cuatro),
         marca = COALESCE(EXCLUDED.marca, fuentes_pago.marca),
         customer_email = COALESCE(EXCLUDED.customer_email, fuentes_pago.customer_email),
         activa = true,
         updated_at = now()`,
      [
        restauranteId,
        paymentSourceId,
        tipo,
        estadoWompi,
        ultimosCuatro,
        marca,
        customerEmail,
      ],
    );

    this.logger.log(
      `Fuente de pago registrada restaurante=${restauranteId} wompi=${paymentSourceId}`,
    );
  }

  async listarCandidatasRenovacionAutomatica(): Promise<SuscripcionRenovacion[]> {
    return this.database.consultar<SuscripcionRenovacion>(
      `SELECT s.restaurante_id, s.plan, s.estado, s.fecha_vencimiento,
              f.id AS fuente_id, f.wompi_payment_source_id, f.customer_email
       FROM suscripciones_restaurante s
       INNER JOIN fuentes_pago f
         ON f.restaurante_id = s.restaurante_id AND f.activa = true
       WHERE s.estado = 'activa'
         AND s.plan IN ('basico', 'pro', 'enterprise')
         AND s.fecha_vencimiento IS NOT NULL
         AND s.fecha_vencimiento <= now() + interval '2 days'
         AND s.fecha_vencimiento > now() - interval '12 hours'
         AND (f.ultimo_intento_at IS NULL OR f.ultimo_intento_at < now() - interval '20 hours')
         AND NOT EXISTS (
           SELECT 1 FROM pagos_suscripcion p
           WHERE p.restaurante_id = s.restaurante_id
             AND p.estado IN ('pendiente', 'aprobado')
             AND p.created_at > now() - interval '5 days'
             AND p.plan = s.plan
         )`,
    );
  }

  /**
   * Crea fila en pagos_suscripcion y dispara cobro Wompi con fuente guardada.
   */
  async intentarCobroRenovacion(
    restauranteId: string,
    planForzado?: PlanPago,
  ): Promise<{
    iniciado: boolean;
    motivo: string;
    pago_id?: string;
    transaccion_wompi_id?: string;
    estado_transaccion?: string;
  }> {
    if (!this.wompi.estaConfigurado()) {
      return { iniciado: false, motivo: 'wompi_no_configurado' };
    }

    const suscripcion = await this.database.consultarUno<{
      plan: string;
      estado: string;
    }>(
      `SELECT plan, estado FROM suscripciones_restaurante WHERE restaurante_id = $1`,
      [restauranteId],
    );
    if (!suscripcion) {
      throw new NotFoundException('Suscripción no encontrada');
    }

    const plan = planForzado ?? suscripcion.plan;
    if (!esPlanPago(plan)) {
      return { iniciado: false, motivo: 'plan_no_pagable' };
    }

    const fuente = await this.obtenerFuenteActiva(restauranteId);
    if (!fuente) {
      return { iniciado: false, motivo: 'sin_fuente_pago' };
    }

    const email =
      fuente.customer_email ??
      (await this.emailAdminRestaurante(restauranteId));
    if (!email) {
      return { iniciado: false, motivo: 'sin_email_cobro' };
    }

    const referencia = this.wompi.generarReferenciaInterna();
    const monto = PRECIO_PLAN_CENTAVOS[plan];

    const pago = await this.database.consultarUno<{ id: string }>(
      `INSERT INTO pagos_suscripcion (
         restaurante_id, plan, monto_centavos, referencia_interna, metodo
       ) VALUES ($1, $2, $3, $4, 'renovacion_automatica')
       RETURNING id`,
      [restauranteId, plan, monto, referencia],
    );

    await this.database.consultar(
      `UPDATE fuentes_pago SET ultimo_intento_at = now(), updated_at = now()
       WHERE id = $1`,
      [fuente.id],
    );

    try {
      const tx = await this.wompi.crearTransaccionRecurrente({
        referenciaInterna: referencia,
        montoCentavos: monto,
        customerEmail: email,
        paymentSourceId: fuente.wompi_payment_source_id,
      });

      await this.database.consultar(
        `UPDATE pagos_suscripcion SET
           transaccion_wompi_id = $2,
           referencia_wompi = $3,
           updated_at = now()
         WHERE id = $1`,
        [pago!.id, tx.id, tx.reference],
      );

      if (tx.status === 'APPROVED') {
        await this.database.consultar(
          `UPDATE pagos_suscripcion SET estado = 'aprobado', updated_at = now()
           WHERE id = $1`,
          [pago!.id],
        );
        await this.extenderSuscripcion(restauranteId, plan);
        await this.database.consultar(
          `UPDATE fuentes_pago SET ultimo_cobro_at = now(), updated_at = now()
           WHERE id = $1`,
          [fuente.id],
        );
      }

      return {
        iniciado: true,
        motivo:
          tx.status === 'APPROVED'
            ? 'cobro_aprobado'
            : 'cobro_pendiente_webhook',
        pago_id: pago!.id,
        transaccion_wompi_id: tx.id,
        estado_transaccion: tx.status,
      };
    } catch (e) {
      await this.database.consultar(
        `UPDATE pagos_suscripcion SET estado = 'error', updated_at = now()
         WHERE id = $1`,
        [pago!.id],
      );
      throw e;
    }
  }

  async extenderSuscripcion(restauranteId: string, plan: string): Promise<void> {
    await this.database.consultar(
      `UPDATE suscripciones_restaurante SET
         estado = 'activa',
         plan = $2,
         fecha_vencimiento = GREATEST(
           COALESCE(fecha_vencimiento, now()),
           now()
         ) + interval '30 days',
         motivo_bloqueo = NULL,
         aviso_3d_enviado_at = NULL,
         aviso_vence_hoy_enviado_at = NULL
       WHERE restaurante_id = $1`,
      [restauranteId, plan],
    );
  }

  private async emailAdminRestaurante(
    restauranteId: string,
  ): Promise<string | null> {
    const fila = await this.database.consultarUno<{ correo: string }>(
      `SELECT correo FROM usuarios
       WHERE restaurante_id = $1
         AND rol IN ('admin', '${ROL_GERENTE_CADENA}')
         AND activo = true
       ORDER BY CASE WHEN rol = 'admin' THEN 0 ELSE 1 END, created_at ASC
       LIMIT 1`,
      [restauranteId],
    );
    return fila?.correo ?? null;
  }

  private mapearTipoFuente(metodo: string | null): string {
    if (!metodo) return 'OTRO';
    const m = metodo.toUpperCase();
    if (m.includes('CARD')) return 'CARD';
    if (m.includes('NEQUI')) return 'NEQUI';
    if (m.includes('BANCOLOMBIA')) return 'BANCOLOMBIA_TRANSFER';
    return 'OTRO';
  }
}
