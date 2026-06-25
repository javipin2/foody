import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { DispatchService } from './dispatch.service';
import { IniciarSesionDto, ResponderOfertaDto, UbicacionDto } from './dto/independiente.dto';

@Injectable()
export class DomiciliariosIndependientesService {
  constructor(
    private readonly database: DatabaseService,
    private readonly dispatch: DispatchService,
    private readonly alertasRiesgo: AlertasRiesgoService,
  ) {}

  async iniciarSesion(domiciliarioId: string, dto: IniciarSesionDto) {
    const dom = await this.obtenerActivo(domiciliarioId);

    await this.database.consultar(
      `UPDATE domiciliarios_sesiones
       SET activa = false, cerrada_at = now(), disponible = false
       WHERE domiciliario_id = $1 AND activa = true`,
      [domiciliarioId],
    );

    const ciudadId = dto.ciudad_id ?? dom.ciudad_id;
    const insert = await this.database.consultarUno<{ id: string }>(
      `INSERT INTO domiciliarios_sesiones (
         domiciliario_id, lat_actual, lng_actual, ciudad_id, disponible, activa
       ) VALUES ($1,$2,$3,$4,true,true)
       RETURNING id`,
      [domiciliarioId, dto.lat, dto.lng, ciudadId],
    );

    return { sesion_id: insert?.id, disponible: true };
  }

  async actualizarUbicacion(domiciliarioId: string, dto: UbicacionDto) {
    const sesion = await this.obtenerSesionActiva(domiciliarioId);
    await this.database.consultar(
      `UPDATE domiciliarios_sesiones
       SET lat_actual = $1, lng_actual = $2
       WHERE id = $3`,
      [dto.lat, dto.lng, sesion.id],
    );
    return { ok: true };
  }

  async cerrarSesion(domiciliarioId: string) {
    await this.database.consultar(
      `UPDATE domiciliarios_sesiones
       SET activa = false, disponible = false, cerrada_at = now()
       WHERE domiciliario_id = $1 AND activa = true`,
      [domiciliarioId],
    );
    return { ok: true };
  }

  async ofertasActivas(domiciliarioId: string) {
    return this.database.consultar(
      `SELECT o.id AS oferta_id,
              o.pedido_id,
              o.radio_busqueda_km,
              o.intento_numero,
              o.expira_at,
              p.numero_pedido,
              p.direccion_entrega,
              p.costo_domicilio,
              p.cliente_nombre,
              p.cliente_telefono,
              s.nombre AS sucursal_nombre,
              s.direccion AS sucursal_direccion,
              r.id AS respuesta_id
       FROM respuestas_oferta r
       JOIN ofertas_pedido o ON o.id = r.oferta_id
       JOIN pedidos p ON p.id = o.pedido_id
       JOIN sucursales s ON s.id = o.sucursal_id
       WHERE r.domiciliario_id = $1
         AND o.estado = 'activa'
         AND o.expira_at > now()
         AND r.respuesta = 'no_vio'
       ORDER BY o.created_at DESC`,
      [domiciliarioId],
    );
  }

  async responderOferta(
    ofertaId: string,
    domiciliarioId: string,
    dto: ResponderOfertaDto,
  ) {
    return this.database.enTransaccion(async (client) => {
      const oferta = await this.consultarUnoCliente<{
        id: string;
        pedido_id: string;
        sucursal_id: string;
        estado: string;
        expira_at: Date;
      }>(
        client,
        `SELECT id, pedido_id, sucursal_id, estado, expira_at
         FROM ofertas_pedido WHERE id = $1 FOR UPDATE`,
        [ofertaId],
      );

      if (!oferta) throw new NotFoundException('Oferta no encontrada');
      if (oferta.estado !== 'activa' || new Date(oferta.expira_at) <= new Date()) {
        throw new BadRequestException('La oferta expiró o ya no está activa');
      }

      const respuesta = await this.consultarUnoCliente<{ id: string; respuesta: string }>(
        client,
        `SELECT id, respuesta FROM respuestas_oferta
         WHERE oferta_id = $1 AND domiciliario_id = $2 FOR UPDATE`,
        [ofertaId, domiciliarioId],
      );
      if (!respuesta) {
        throw new BadRequestException('No fuiste notificado para esta oferta');
      }
      if (respuesta.respuesta !== 'no_vio') {
        throw new BadRequestException('Ya respondiste esta oferta');
      }

      if (dto.respuesta === 'rechazada') {
        await client.query(
          `UPDATE respuestas_oferta SET respuesta = 'rechazada', respondido_at = now()
           WHERE id = $1`,
          [respuesta.id],
        );
        return { oferta_id: ofertaId, respuesta: 'rechazada' };
      }

      const ocupado = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE domiciliario_independiente_id = $1
           AND estado IN ('asignado', 'en_camino')`,
        [domiciliarioId],
      );
      if (ocupado) {
        throw new BadRequestException('Ya tienes un pedido activo');
      }

      const pedido = await this.consultarUnoCliente<{
        id: string;
        estado: string;
        costo_domicilio: string;
      }>(
        client,
        `SELECT id, estado, costo_domicilio FROM pedidos
         WHERE id = $1 FOR UPDATE`,
        [oferta.pedido_id],
      );
      if (!pedido || pedido.estado !== 'listo') {
        throw new BadRequestException('El pedido ya no está disponible');
      }

      const yaAsignado = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`,
        [oferta.pedido_id],
      );
      if (yaAsignado) {
        await client.query(
          `UPDATE ofertas_pedido SET estado = 'cancelada' WHERE id = $1`,
          [ofertaId],
        );
        throw new BadRequestException('Otro domiciliario ya tomó el pedido');
      }

      await client.query(
        `UPDATE ofertas_pedido SET estado = 'aceptada' WHERE id = $1`,
        [ofertaId],
      );
      await client.query(
        `UPDATE respuestas_oferta SET respuesta = 'aceptada', respondido_at = now()
         WHERE oferta_id = $1 AND domiciliario_id = $2`,
        [ofertaId, domiciliarioId],
      );
      await client.query(
        `UPDATE respuestas_oferta SET respuesta = 'rechazada', respondido_at = now()
         WHERE oferta_id = $1 AND domiciliario_id != $2 AND respuesta = 'no_vio'`,
        [ofertaId, domiciliarioId],
      );

      const asignacion = await client.query<{ id: string }>(
        `INSERT INTO asignaciones_domicilio (
           pedido_id, sucursal_id, domiciliario_independiente_id,
           tipo_domiciliario, estado
         ) VALUES ($1,$2,$3,'independiente','asignado')
         RETURNING id`,
        [oferta.pedido_id, oferta.sucursal_id, domiciliarioId],
      );
      const asignacionId = asignacion.rows[0].id;

      await client.query(
        `UPDATE pedidos SET estado = 'asignado' WHERE id = $1`,
        [oferta.pedido_id],
      );
      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, motivo)
         VALUES ($1, 'listo', 'asignado', 'Domiciliario independiente aceptó oferta')`,
        [oferta.pedido_id],
      );

      await client.query(
        `UPDATE domiciliarios_sesiones SET disponible = false
         WHERE domiciliario_id = $1 AND activa = true`,
        [domiciliarioId],
      );

      const costo = Number(pedido.costo_domicilio ?? 0);
      const { comision, ganancia } = this.dispatch.calcularGanancias(costo);
      if (costo > 0) {
        await client.query(
          `INSERT INTO ganancias_domiciliario (
             domiciliario_id, asignacion_id, valor_domicilio,
             comision_foody, ganancia_domiciliario
           ) VALUES ($1,$2,$3,$4,$5)`,
          [domiciliarioId, asignacionId, costo, comision, ganancia],
        );
      }

      await client.query(
        `UPDATE domiciliarios_independientes
         SET total_entregas = total_entregas + 1
         WHERE id = $1`,
        [domiciliarioId],
      );

      return {
        oferta_id: ofertaId,
        respuesta: 'aceptada',
        pedido_id: oferta.pedido_id,
        asignacion_id: asignacionId,
        estado: 'asignado',
      };
    });
  }

  async pedidosActivos(domiciliarioId: string) {
    return this.database.consultar(
      `SELECT p.id,
              p.numero_pedido,
              p.estado,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.total,
              p.metodo_pago,
              p.costo_domicilio,
              ad.estado AS estado_asignacion,
              ad.asignado_at,
              s.nombre AS sucursal_nombre,
              s.direccion AS sucursal_direccion,
              s.lat AS sucursal_lat,
              s.lng AS sucursal_lng
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       JOIN sucursales s ON s.id = ad.sucursal_id
       WHERE ad.domiciliario_independiente_id = $1
         AND ad.estado IN ('asignado', 'en_camino')
       ORDER BY ad.asignado_at ASC`,
      [domiciliarioId],
    );
  }

  async marcarEnCamino(pedidoId: string, domiciliarioId: string) {
    return this.database.enTransaccion(async (client) => {
      const asignacion = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_independiente_id = $2
           AND estado = 'asignado' FOR UPDATE`,
        [pedidoId, domiciliarioId],
      );
      if (!asignacion) {
        throw new BadRequestException('Pedido no asignado a ti');
      }

      await client.query(
        `UPDATE asignaciones_domicilio SET estado = 'en_camino' WHERE id = $1`,
        [asignacion.id],
      );
      await client.query(`UPDATE pedidos SET estado = 'en_camino' WHERE id = $1`, [
        pedidoId,
      ]);
      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, motivo)
         VALUES ($1, 'asignado', 'en_camino', 'Domiciliario independiente en camino')`,
        [pedidoId],
      );

      return { pedido_id: pedidoId, estado: 'en_camino' };
    });
  }

  async confirmarEntrega(pedidoId: string, domiciliarioId: string) {
    return this.database.enTransaccion(async (client) => {
      const asignacion = await this.consultarUnoCliente<{ id: string }>(
        client,
        `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_independiente_id = $2
           AND estado = 'en_camino' FOR UPDATE`,
        [pedidoId, domiciliarioId],
      );
      if (!asignacion) {
        throw new BadRequestException('El pedido debe estar en camino');
      }

      await client.query(
        `UPDATE asignaciones_domicilio
         SET estado = 'entregado', entregado_at = now()
         WHERE id = $1`,
        [asignacion.id],
      );
      await client.query(`UPDATE pedidos SET estado = 'entregado' WHERE id = $1`, [
        pedidoId,
      ]);
      await client.query(
        `INSERT INTO estados_pedido_historial
           (pedido_id, estado_anterior, estado_nuevo, motivo)
         VALUES ($1, 'en_camino', 'entregado', 'Entrega confirmada por independiente')`,
        [pedidoId],
      );
      await client.query(
        `UPDATE domiciliarios_sesiones SET disponible = true
         WHERE domiciliario_id = $1 AND activa = true`,
        [domiciliarioId],
      );

      const pedido = await this.consultarUnoCliente<{ sucursal_id: string }>(
        client,
        `SELECT sucursal_id FROM pedidos WHERE id = $1`,
        [pedidoId],
      );
      if (pedido) {
        await this.alertasRiesgo.evaluarDemoraEntrega(
          client,
          pedidoId,
          pedido.sucursal_id,
        );
      }

      return { pedido_id: pedidoId, estado: 'entregado' };
    });
  }

  async ganancias(domiciliarioId: string) {
    return this.database.consultar(
      `SELECT id, valor_domicilio, comision_foody, ganancia_domiciliario,
              pagado, created_at
       FROM ganancias_domiciliario
       WHERE domiciliario_id = $1
       ORDER BY created_at DESC
       LIMIT 50`,
      [domiciliarioId],
    );
  }

  private async obtenerActivo(domiciliarioId: string) {
    const dom = await this.database.consultarUno<{
      id: string;
      ciudad_id: string;
      estado_cuenta: string;
    }>(
      `SELECT id, ciudad_id, estado_cuenta
       FROM domiciliarios_independientes WHERE id = $1`,
      [domiciliarioId],
    );
    if (!dom || dom.estado_cuenta !== 'activo') {
      throw new ForbiddenException('Cuenta no activa');
    }
    return dom;
  }

  private async obtenerSesionActiva(domiciliarioId: string) {
    const sesion = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM domiciliarios_sesiones
       WHERE domiciliario_id = $1 AND activa = true
       ORDER BY iniciada_at DESC LIMIT 1`,
      [domiciliarioId],
    );
    if (!sesion) {
      throw new BadRequestException('Inicia tu turno antes de actualizar ubicación');
    }
    return sesion;
  }

  private async consultarUnoCliente<T extends QueryResultRow>(
    client: PoolClient,
    sql: string,
    params: unknown[],
  ): Promise<T | null> {
    const r = await client.query<T>(sql, params);
    return r.rows[0] ?? null;
  }
}
