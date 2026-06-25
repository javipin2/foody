import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { FacturacionService } from '../facturacion/facturacion.service';
import { AlertasRiesgoService, UMBRALES_ALERTA } from '../alertas/alertas-riesgo.service';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { PedidosSoporteService } from './pedidos-soporte.service';

/** Subdominio: descuentos manuales en pedidos abiertos. */
@Injectable()
export class PedidosDescuentoService {
  constructor(
    private readonly database: DatabaseService,
    private readonly facturacion: FacturacionService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly soporte: PedidosSoporteService,
  ) {}

  async aplicarDescuento(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    dto: AplicarDescuentoDto,
    contexto: { rol: string; permisos: string[] },
  ) {
    if (!contexto.permisos.includes('aplicar_descuento')) {
      throw new ForbiddenException('No tienes permiso para aplicar descuentos');
    }
    if (dto.monto == null && dto.porcentaje == null) {
      throw new BadRequestException('Indica monto o porcentaje de descuento');
    }
    if (dto.monto != null && dto.porcentaje != null) {
      throw new BadRequestException('Usa solo monto o porcentaje, no ambos');
    }
    if (!dto.motivo?.trim()) {
      throw new BadRequestException('El motivo del descuento es obligatorio');
    }

    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await this.soporte.consultarUnoCliente<{
        id: string;
        estado: string;
        subtotal: string;
        costo_domicilio: string;
        descuento: string;
        total: string;
      }>(
        client,
        `SELECT id, estado, subtotal, costo_domicilio, descuento, total
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');

      if (['cancelado', 'entregado', 'pagado', 'rechazado'].includes(pedido.estado)) {
        throw new BadRequestException('No se puede descontar un pedido en este estado');
      }

      const base =
        Number(pedido.subtotal) + Number(pedido.costo_domicilio);
      let descuento =
        dto.monto ?? Math.round((base * dto.porcentaje!) / 100);
      descuento = Math.min(Math.max(descuento, 0), base);
      const pctBase = base > 0 ? (descuento / base) * 100 : 0;

      const esElevado = contexto.rol === 'admin' || contexto.rol === 'gerente';
      if (pctBase > 20 && !esElevado) {
        throw new BadRequestException(
          'Descuentos mayores al 20% requieren admin o gerente',
        );
      }

      const total = base - descuento;
      const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(
        client,
        sucursalId,
        total,
      );

      await client.query(
        `UPDATE pedidos SET
           descuento = $1, motivo_descuento = $2, total = $3,
           iva_porcentaje = $4, iva_valor = $5
         WHERE id = $6`,
        [descuento, dto.motivo.trim(), total, iva.iva_porcentaje, iva.iva_valor, pedidoId],
      );

      if (pctBase > UMBRALES_ALERTA.descuentoPorcentajeAlto) {
        await this.alertasRiesgo.registrarEnTransaccion(client, {
          sucursalId,
          tipo: 'descuento_manual_excesivo',
          nivel: 'alto',
          descripcion: `Descuento del ${Math.round(pctBase)}% (${descuento} COP) — ${dto.motivo.trim()}`,
          referenciaId: pedidoId,
          referenciaTipo: 'pedido',
          deduplicar: true,
        });
      }

      await client.query(
        `INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id,
           datos_antes, datos_despues
         ) VALUES ($1,$2,'APLICAR_DESCUENTO','pedidos',$3,$4::jsonb,$5::jsonb)`,
        [
          sucursalId,
          usuarioId,
          pedidoId,
          JSON.stringify({
            descuento_anterior: Number(pedido.descuento),
            total_anterior: Number(pedido.total),
          }),
          JSON.stringify({
            descuento,
            porcentaje: Math.round(pctBase * 100) / 100,
            motivo: dto.motivo.trim(),
            total,
            iva_valor: iva.iva_valor,
          }),
        ],
      );

      return {
        id: pedidoId,
        estado: pedido.estado,
        descuento,
        porcentaje: Math.round(pctBase * 100) / 100,
        total,
        iva_valor: iva.iva_valor,
      };
    });
    this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, result.estado);
    return result;
  }
}
