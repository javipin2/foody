import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import {
  AlertasRiesgoService,
  UMBRALES_ALERTA,
} from '../alertas/alertas-riesgo.service';
import { AbrirCajaDto } from './dto/abrir-caja.dto';
import { CerrarCajaDto } from './dto/cerrar-caja.dto';
import { GastoCajaDto } from './dto/gasto-caja.dto';
import { CrearCuentaPorCobrarDto } from './dto/crear-cuenta-por-cobrar.dto';
import { RetiroCajaDto } from './dto/retiro-caja.dto';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';

@Injectable()
export class CajaService {
  constructor(
    private readonly database: DatabaseService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  async obtenerActiva(sucursalId: string, opciones: { ocultarSaldo?: boolean } = {}) {
    const caja = await this.database.consultarUno(
      `SELECT c.*,
              u.nombre AS usuario_apertura_nombre
       FROM cajas c
       LEFT JOIN usuarios u ON u.id = c.usuario_apertura_id
       WHERE c.sucursal_id = $1 AND c.estado = 'abierta'
       ORDER BY c.apertura_at DESC
       LIMIT 1`,
      [sucursalId],
    );
    if (!caja) return null;

    const resumen = await this.calcularResumenTurno(caja.id as string);
    const base = { ...caja, ...resumen };
    if (opciones.ocultarSaldo && caja.arqueo_ciego) {
      const { saldo_sistema: _, total_ventas: __, ...rest } = base as Record<string, unknown>;
      return { ...rest, arqueo_ciego: true };
    }
    return base;
  }

  async abrir(dto: AbrirCajaDto, usuarioId: string) {
    const activa = await this.database.consultarUno(
      `SELECT id FROM cajas WHERE sucursal_id = $1 AND estado = 'abierta' LIMIT 1`,
      [dto.sucursal_id],
    );
    if (activa) {
      throw new BadRequestException({
        error: 'CAJA_YA_ABIERTA',
        message: 'Ya hay una caja abierta en esta sucursal',
      });
    }

    const caja = await this.database.enTransaccion(async (client) => {
      const insert = await client.query<{ id: string }>(
        `INSERT INTO cajas (
           sucursal_id, usuario_apertura_id, monto_inicial, estado, arqueo_ciego
         ) VALUES ($1,$2,$3,'abierta',$4)
         RETURNING id`,
        [dto.sucursal_id, usuarioId, dto.monto_inicial, dto.arqueo_ciego ?? false],
      );
      const cajaId = insert.rows[0].id;

      await client.query(
        `INSERT INTO movimientos_caja (
           caja_id, sucursal_id, tipo, monto, descripcion, usuario_id
         ) VALUES ($1,$2,'apertura',$3,$4,$5)`,
        [
          cajaId,
          dto.sucursal_id,
          dto.monto_inicial,
          'Apertura de caja',
          usuarioId,
        ],
      );

      await client.query(
        `INSERT INTO auditoria_logs (sucursal_id, usuario_id, accion, tabla_afectada, registro_id)
         VALUES ($1,$2,'ABRIR_CAJA','cajas',$3)`,
        [dto.sucursal_id, usuarioId, cajaId],
      );

      return this.obtenerActiva(dto.sucursal_id);
    });
    void this.realtime.cajaMovimiento(dto.sucursal_id, { tipo: 'apertura' });
    return caja;
  }

  async cerrar(dto: CerrarCajaDto, usuarioId: string) {
    return this.database.enTransaccion(async (client) => {
      const caja = await client.query<{
        id: string;
        sucursal_id: string;
        estado: string;
        monto_inicial: string;
      }>(
        `SELECT id, sucursal_id, estado, monto_inicial FROM cajas
         WHERE id = $1 FOR UPDATE`,
        [dto.caja_id],
      );
      const fila = caja.rows[0];
      if (!fila) throw new NotFoundException('Caja no encontrada');
      if (fila.estado !== 'abierta') {
        throw new BadRequestException('La caja ya está cerrada');
      }

      const pedidosAbiertos = await client.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM pedidos
         WHERE sucursal_id = $1
           AND estado IN ('pendiente_aprobacion', 'pendiente', 'confirmado', 'en_cocina', 'listo', 'pagando', 'asignado', 'en_camino')`,
        [fila.sucursal_id],
      );
      const operacionAbierta = Number(pedidosAbiertos.rows[0]?.n ?? 0);

      const movs = await client.query<{ total: string }>(
        `SELECT COALESCE(SUM(
           CASE
             WHEN tipo IN ('venta', 'ingreso_extra', 'apertura') THEN monto
             WHEN tipo IN ('retiro', 'gasto', 'devolucion') THEN -monto
             ELSE 0
           END
         ), 0)::text AS total
         FROM movimientos_caja WHERE caja_id = $1`,
        [dto.caja_id],
      );
      const montoSistema = Number(movs.rows[0]?.total ?? 0);
      const diferencia = dto.monto_final_contado - montoSistema;

      await client.query(
        `UPDATE cajas SET
           estado = 'cerrada',
           usuario_cierre_id = $1,
           monto_final_contado = $2,
           monto_final_sistema = $3,
           diferencia = $4,
           observaciones_cierre = $5,
           cierre_at = now()
         WHERE id = $6`,
        [
          usuarioId,
          dto.monto_final_contado,
          montoSistema,
          diferencia,
          dto.observaciones_cierre ?? null,
          dto.caja_id,
        ],
      );

      await client.query(
        `INSERT INTO auditoria_logs (sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues)
         VALUES ($1,$2,'CERRAR_CAJA','cajas',$3,$4::jsonb)`,
        [
          fila.sucursal_id,
          usuarioId,
          dto.caja_id,
          JSON.stringify({
            monto_final_contado: dto.monto_final_contado,
            monto_final_sistema: montoSistema,
            diferencia,
          }),
        ],
      );

      if (Math.abs(diferencia) > UMBRALES_ALERTA.cuadreCajaCOP) {
        await this.alertasRiesgo.registrarEnTransaccion(client, {
          sucursalId: fila.sucursal_id,
          tipo: 'cuadre_caja_diferencia',
          nivel: 'alto',
          descripcion: `Cierre de caja con diferencia de $${Math.round(diferencia).toLocaleString('es-CO')} (contado ${dto.monto_final_contado}, sistema ${Math.round(montoSistema)})`,
          referenciaId: dto.caja_id,
          referenciaTipo: 'caja',
          deduplicar: true,
        });
      }

      return {
        caja_id: dto.caja_id,
        monto_final_sistema: montoSistema,
        monto_final_contado: dto.monto_final_contado,
        diferencia,
        estado: 'cerrada',
        advertencias:
          operacionAbierta > 0
            ? [
                `${operacionAbierta} pedido(s) aún en operación (cocina, listo, pagando o domicilio).`,
              ]
            : [],
      };
    });
  }

  async listarMovimientos(cajaId: string, sucursalId: string) {
    const caja = await this.database.consultarUno(
      `SELECT id FROM cajas WHERE id = $1 AND sucursal_id = $2`,
      [cajaId, sucursalId],
    );
    if (!caja) throw new NotFoundException('Caja no encontrada');

    return this.database.consultar(
      `SELECT id, tipo, monto, metodo_pago, descripcion, pedido_id, created_at
       FROM movimientos_caja
       WHERE caja_id = $1
       ORDER BY created_at DESC`,
      [cajaId],
    );
  }

  async retiroParcial(dto: RetiroCajaDto, usuarioId: string, sucursalId: string) {
    await this.exigirCajaAbierta(dto.caja_id, sucursalId);

    return this.database.enTransaccion(async (client) => {
      await client.query(
        `INSERT INTO movimientos_caja (
           caja_id, sucursal_id, tipo, monto, descripcion, usuario_id
         ) VALUES ($1,$2,'retiro',$3,$4,$5)`,
        [
          dto.caja_id,
          sucursalId,
          dto.monto,
          dto.descripcion ?? 'Retiro parcial',
          usuarioId,
        ],
      );
      return { ok: true };
    });
  }

  listarCuentasPorCobrar(sucursalId: string, soloPendientes = true) {
    const filtro = soloPendientes ? `AND c.estado = 'pendiente'` : '';
    return this.database.consultar(
      `SELECT c.id, c.pedido_id, c.cliente_nombre, c.cliente_telefono,
              c.monto, c.estado, c.created_at, c.pagada_at,
              p.numero_pedido
       FROM cuentas_por_cobrar c
       LEFT JOIN pedidos p ON p.id = c.pedido_id
       WHERE c.sucursal_id = $1 ${filtro}
       ORDER BY c.created_at DESC`,
      [sucursalId],
    );
  }

  async crearCuentaPorCobrar(
    dto: CrearCuentaPorCobrarDto,
    usuarioId: string,
  ) {
    if (dto.pedido_id) {
      const pedido = await this.database.consultarUno(
        `SELECT id FROM pedidos WHERE id = $1 AND sucursal_id = $2`,
        [dto.pedido_id, dto.sucursal_id],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');
    }

    const fila = await this.database.consultarUno(
      `INSERT INTO cuentas_por_cobrar (
         sucursal_id, pedido_id, cliente_nombre, cliente_telefono,
         monto, usuario_id
       ) VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING id, cliente_nombre, monto, estado, created_at`,
      [
        dto.sucursal_id,
        dto.pedido_id ?? null,
        dto.cliente_nombre,
        dto.cliente_telefono ?? null,
        dto.monto,
        usuarioId,
      ],
    );
    return fila;
  }

  pagarCuentaPorCobrar(cuentaId: string, sucursalId: string, usuarioId: string) {
    return this.database.enTransaccion(async (client) => {
      const cuenta = await client.query<{
        id: string;
        pedido_id: string | null;
        monto: string;
        estado: string;
      }>(
        `SELECT id, pedido_id, monto, estado FROM cuentas_por_cobrar
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [cuentaId, sucursalId],
      );
      const fila = cuenta.rows[0];
      if (!fila) throw new NotFoundException('Cuenta no encontrada');
      if (fila.estado === 'pagada') {
        throw new BadRequestException('La cuenta ya está pagada');
      }

      const monto = Number(fila.monto);

      await client.query(
        `UPDATE cuentas_por_cobrar
         SET estado = 'pagada', pagada_at = now()
         WHERE id = $1`,
        [cuentaId],
      );

      const caja = await client.query<{ id: string }>(
        `SELECT id FROM cajas
         WHERE sucursal_id = $1 AND estado = 'abierta'
         ORDER BY apertura_at DESC LIMIT 1`,
        [sucursalId],
      );
      const cajaId = caja.rows[0]?.id;
      if (cajaId) {
        await client.query(
          `INSERT INTO movimientos_caja (
             caja_id, sucursal_id, pedido_id, tipo, monto,
             metodo_pago, descripcion, usuario_id
           ) VALUES ($1,$2,$3,'venta',$4,'efectivo',$5,$6)`,
          [
            cajaId,
            sucursalId,
            fila.pedido_id,
            monto,
            `Cobro fiado · ${cuentaId}`,
            usuarioId,
          ],
        );
      }

      await client.query(
        `INSERT INTO auditoria_logs (sucursal_id, usuario_id, accion, tabla_afectada, registro_id)
         VALUES ($1,$2,'PAGAR_CUENTA','cuentas_por_cobrar',$3)`,
        [sucursalId, usuarioId, cuentaId],
      );

      return { id: cuentaId, estado: 'pagada', monto, caja_registrada: !!cajaId };
    });
  }

  async registrarDevolucion(
    params: {
      caja_id: string;
      sucursal_id: string;
      pedido_id?: string;
      monto: number;
      motivo: string;
      metodo_pago?: string;
    },
    usuarioId: string,
  ) {
    await this.exigirCajaAbierta(params.caja_id, params.sucursal_id);
    return this.database.enTransaccion(async (client) => {
      await client.query(
        `INSERT INTO movimientos_caja (
           caja_id, sucursal_id, pedido_id, tipo, monto, metodo_pago, descripcion, usuario_id
         ) VALUES ($1,$2,$3,'devolucion',$4,$5,$6,$7)`,
        [
          params.caja_id,
          params.sucursal_id,
          params.pedido_id ?? null,
          params.monto,
          params.metodo_pago ?? 'efectivo',
          params.motivo.trim(),
          usuarioId,
        ],
      );
      await client.query(
        `INSERT INTO auditoria_logs (sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues)
         VALUES ($1,$2,'DEVOLUCION_CAJA','movimientos_caja',$3,$4::jsonb)`,
        [
          params.sucursal_id,
          usuarioId,
          params.pedido_id ?? params.caja_id,
          JSON.stringify(params),
        ],
      );
      return { registrado: true, monto: params.monto };
    });
  }

  async registrarGasto(dto: GastoCajaDto, usuarioId: string, sucursalId: string) {
    await this.exigirCajaAbierta(dto.caja_id, sucursalId);

    return this.database.enTransaccion(async (client) => {
      await client.query(
        `INSERT INTO gastos (sucursal_id, caja_id, concepto, monto, categoria, usuario_id)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [
          sucursalId,
          dto.caja_id,
          dto.concepto,
          dto.monto,
          dto.categoria ?? null,
          usuarioId,
        ],
      );
      await client.query(
        `INSERT INTO movimientos_caja (
           caja_id, sucursal_id, tipo, monto, descripcion, usuario_id
         ) VALUES ($1,$2,'gasto',$3,$4,$5)`,
        [
          dto.caja_id,
          sucursalId,
          dto.monto,
          dto.concepto,
          usuarioId,
        ],
      );
      return { ok: true };
    });
  }

  private async exigirCajaAbierta(cajaId: string, sucursalId: string) {
    const caja = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM cajas
       WHERE id = $1 AND sucursal_id = $2 AND estado = 'abierta'`,
      [cajaId, sucursalId],
    );
    if (!caja) {
      throw new BadRequestException({
        error: 'CAJA_NO_ABIERTA',
        message: 'No hay caja abierta para esta operación',
      });
    }
  }

  private async calcularResumenTurno(cajaId: string) {
    const ventas = await this.database.consultarUno<{ total: string }>(
      `SELECT COALESCE(SUM(monto), 0)::text AS total
       FROM movimientos_caja
       WHERE caja_id = $1 AND tipo = 'venta'`,
      [cajaId],
    );
    const gastos = await this.database.consultarUno<{ total: string }>(
      `SELECT COALESCE(SUM(monto), 0)::text AS total
       FROM movimientos_caja
       WHERE caja_id = $1 AND tipo = 'gasto'`,
      [cajaId],
    );
    const retiros = await this.database.consultarUno<{ total: string }>(
      `SELECT COALESCE(SUM(monto), 0)::text AS total
       FROM movimientos_caja
       WHERE caja_id = $1 AND tipo = 'retiro'`,
      [cajaId],
    );
    const saldo = await this.database.consultarUno<{ total: string }>(
      `SELECT COALESCE(SUM(
         CASE
           WHEN tipo IN ('venta', 'ingreso_extra', 'apertura') THEN monto
           WHEN tipo IN ('retiro', 'gasto', 'devolucion') THEN -monto
           ELSE 0
         END
       ), 0)::text AS total
       FROM movimientos_caja WHERE caja_id = $1`,
      [cajaId],
    );

    return {
      total_ventas: Number(ventas?.total ?? 0),
      total_gastos: Number(gastos?.total ?? 0),
      total_retiros: Number(retiros?.total ?? 0),
      saldo_sistema: Number(saldo?.total ?? 0),
    };
  }
}
