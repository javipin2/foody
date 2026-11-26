import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
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
import { CajaMovimientosService } from '../../core/caja/caja-movimientos.service';
import { PedidosEstadoService } from '../pedidos/pedidos-estado.service';
import {
  SQL_WHERE_DOMICILIO_ENTREGADO_IMPAGO,
  SQL_WHERE_PEDIDO_OPERACION_ABIERTA,
} from '../pedidos/pedido-estados';
import { AuditoriaService } from '../auditoria/auditoria.service';
import {
  envolverPaginado,
  resolverPaginacion,
  ResultadoPaginado,
} from '../../compartido/dto/paginacion.dto';

/** Efectivo físico esperado; pagos no efectivos y propinas quedan separados. */
const SQL_SALDO_EFECTIVO_CAJA = `
  COALESCE(SUM(
    CASE
      WHEN tipo = 'apertura' THEN monto
      WHEN tipo IN ('venta', 'ingreso_extra') AND metodo_pago = 'efectivo' THEN monto
      WHEN tipo IN ('retiro', 'gasto') THEN -monto
      WHEN tipo = 'devolucion' AND metodo_pago = 'efectivo' THEN -monto
      ELSE 0
    END
  ), 0)::text AS total`;

@Injectable()
export class CajaService {
  constructor(
    private readonly database: DatabaseService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly pedidosEstado: PedidosEstadoService,
    private readonly cajaMovimientos: CajaMovimientosService,
    private readonly auditoria: AuditoriaService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  async obtenerActiva(
    sucursalId: string,
    opciones: { ocultarSaldo?: boolean } = {},
  ) {
    const caja = await this.database.consultarUno(
      `SELECT c.*,
              u.nombre AS usuario_apertura_nombre,
              ROUND(
                (EXTRACT(EPOCH FROM (NOW() - c.apertura_at)) / 3600.0)::numeric,
                2
              ) AS horas_abierta
       FROM cajas c
       LEFT JOIN usuarios u ON u.id = c.usuario_apertura_id
       WHERE c.sucursal_id = $1 AND c.estado = 'abierta'
       ORDER BY c.apertura_at DESC
       LIMIT 1`,
      [sucursalId],
    );
    if (!caja) return null;

    const resumen = await this.calcularResumenTurno(caja.id as string);
    const horas = Number(
      (caja as { horas_abierta?: number | string }).horas_abierta ?? 0,
    );
    const base = { ...caja, ...resumen, horas_abierta: horas };
    if (horas >= UMBRALES_ALERTA.cajaTurnoHoras) {
      try {
        await this.alertasRiesgo.registrar({
          sucursalId,
          tipo: 'caja_turno_longevo',
          nivel: 'medio',
          descripcion: `Turno abierto ${horas} h (umbral ${UMBRALES_ALERTA.cajaTurnoHoras} h). Cierra caja o haz arqueo.`,
          referenciaId: caja.id as string,
          referenciaTipo: 'caja',
          deduplicar: true,
        });
      } catch {
        // ponytail: no tumbar GET caja si falla la alerta
      }
    }
    if (opciones.ocultarSaldo && caja.arqueo_ciego) {
      const {
        saldo_sistema: _,
        total_ventas: __,
        ...rest
      } = base as Record<string, unknown>;
      return { ...rest, arqueo_ciego: true };
    }
    return base;
  }

  async abrir(dto: AbrirCajaDto, usuarioId: string) {
    try {
      const caja = await this.database.enTransaccion(async (client) => {
        const insert = await client.query<{ id: string }>(
          `INSERT INTO cajas (
             sucursal_id, usuario_apertura_id, monto_inicial, estado, arqueo_ciego
           ) VALUES ($1,$2,$3,'abierta',$4)
           RETURNING id`,
          [
            dto.sucursal_id,
            usuarioId,
            dto.monto_inicial,
            dto.arqueo_ciego ?? false,
          ],
        );
        const cajaId = insert.rows[0].id;

        await this.cajaMovimientos.insertar(client, {
          cajaId,
          sucursalId: dto.sucursal_id,
          tipo: 'apertura',
          monto: dto.monto_inicial,
          descripcion: 'Apertura de caja',
          usuarioId,
        });

        await this.auditoria.registrarEnTransaccion(client, {
          sucursalId: dto.sucursal_id,
          accion: 'ABRIR_CAJA',
          tablaAfectada: 'cajas',
          registroId: cajaId,
          usuarioId,
        });

        return this.obtenerActiva(dto.sucursal_id);
      });
      void this.realtime.cajaMovimiento(dto.sucursal_id, { tipo: 'apertura' });
      return caja;
    } catch (e: unknown) {
      // API-IDEM-03: índice único parcial uq_caja_abierta_sucursal
      const code =
        e && typeof e === 'object' && 'code' in e
          ? String((e as { code: unknown }).code)
          : '';
      if (code === '23505') {
        throw new ConflictException({
          error: 'CAJA_YA_ABIERTA',
          mensaje: 'Ya hay una caja abierta en esta sucursal',
        });
      }
      throw e;
    }
  }

  async cerrar(dto: CerrarCajaDto, usuario: JwtPayload) {
    const usuarioId = usuario.sub;
    const result = await this.database.enTransaccion(async (client) => {
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
      // RBAC-TENANT-01: scope contra la sucursal de la caja, no la del JWT a ciegas
      await this.sucursalScope.resolverEscritura(usuario, fila.sucursal_id);
      if (fila.estado !== 'abierta') {
        throw new ConflictException({
          error: 'CAJA_YA_CERRADA',
          mensaje: 'La caja ya está cerrada',
        });
      }

      await this.pedidosEstado.expirarQrPendientesAlCierreEnTransaccion(
        client,
        fila.sucursal_id,
        usuarioId,
      );

      const pedidosAbiertos = await client.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM pedidos
         WHERE sucursal_id = $1
           AND ${SQL_WHERE_PEDIDO_OPERACION_ABIERTA}`,
        [fila.sucursal_id],
      );
      const operacionAbierta = Number(pedidosAbiertos.rows[0]?.n ?? 0);

      const entregadosSinCobrar = await client.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM pedidos
         WHERE sucursal_id = $1
           AND ${SQL_WHERE_DOMICILIO_ENTREGADO_IMPAGO}`,
        [fila.sucursal_id],
      );
      const domiciliosImpagos = Number(entregadosSinCobrar.rows[0]?.n ?? 0);

      const mesasConOperacion = await client.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM mesas
         WHERE sucursal_id = $1
           AND activa = true
           AND estado_operativo IN ('ocupada', 'pagando')`,
        [fila.sucursal_id],
      );
      const mesasActivas = Number(mesasConOperacion.rows[0]?.n ?? 0);

      if (operacionAbierta > 0 || mesasActivas > 0 || domiciliosImpagos > 0) {
        const mensaje =
          operacionAbierta > 0
            ? `No puedes cerrar la caja: hay ${operacionAbierta} pedido(s) en cocina, listos, pagando o domicilio. Ciérralos o cobra antes de cerrar el turno.`
            : domiciliosImpagos > 0
              ? `No puedes cerrar la caja: hay ${domiciliosImpagos} domicilio(s) entregados sin cobro completo. Registra el pago antes de cerrar.`
              : `No puedes cerrar la caja: hay ${mesasActivas} mesa(s) ocupadas o en cobro. Libera el salón antes de cerrar.`;
        throw new BadRequestException({
          error: 'CAJA_CIERRE_OPERACION_ABIERTA',
          mensaje,
        });
      }

      const movs = await client.query<{ total: string }>(
        `SELECT ${SQL_SALDO_EFECTIVO_CAJA}
         FROM movimientos_caja WHERE caja_id = $1`,
        [dto.caja_id],
      );
      const montoSistema = Number(movs.rows[0]?.total ?? 0);
      const diferencia = dto.monto_final_contado - montoSistema;

      const propinasRow = await client.query<{ total: string }>(
        `SELECT COALESCE(SUM(pp.propina), 0)::text AS total
         FROM pagos_pedido pp
         INNER JOIN cajas c ON c.id = $2
         WHERE pp.sucursal_id = $1
           AND pp.propina > 0
           AND pp.created_at >= c.apertura_at
           AND pp.created_at <= NOW()`,
        [fila.sucursal_id, dto.caja_id],
      );
      const propinasTurno = Number(propinasRow.rows[0]?.total ?? 0);

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

      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId: fila.sucursal_id,
        accion: 'CERRAR_CAJA',
        tablaAfectada: 'cajas',
        registroId: dto.caja_id,
        usuarioId,
        datosDespues: {
          monto_final_contado: dto.monto_final_contado,
          monto_final_sistema: montoSistema,
          diferencia,
        },
      });

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
        sucursal_id: fila.sucursal_id,
        monto_final_sistema: montoSistema,
        monto_final_contado: dto.monto_final_contado,
        diferencia,
        propinas_turno: propinasTurno,
        estado: 'cerrada',
      };
    });
    void this.realtime.cajaMovimiento(result.sucursal_id, {
      tipo: 'cierre',
      caja_id: result.caja_id,
    });
    return result;
  }

  async listarMovimientos(
    cajaId: string,
    sucursalId: string,
    page?: number,
    limit?: number,
  ): Promise<ResultadoPaginado<Record<string, unknown>>> {
    const caja = await this.database.consultarUno(
      `SELECT id FROM cajas WHERE id = $1 AND sucursal_id = $2`,
      [cajaId, sucursalId],
    );
    if (!caja) throw new NotFoundException('Caja no encontrada');

    const pag = resolverPaginacion(page, limit, 50);
    const [items, totalRow] = await Promise.all([
      this.database.consultar(
        `SELECT m.id, m.tipo, m.monto, m.metodo_pago, m.descripcion, m.pedido_id,
                m.created_at, u.nombre AS responsable
         FROM movimientos_caja m
         LEFT JOIN usuarios u ON u.id = m.usuario_id
         WHERE m.caja_id = $1
         ORDER BY m.created_at DESC
         LIMIT $2 OFFSET $3`,
        [cajaId, pag.limit, pag.offset],
      ),
      this.database.consultarUno<{ count: number }>(
        `SELECT COUNT(*)::int AS count FROM movimientos_caja WHERE caja_id = $1`,
        [cajaId],
      ),
    ]);

    return envolverPaginado(
      items as Record<string, unknown>[],
      totalRow?.count ?? 0,
      pag.page,
      pag.limit,
    );
  }

  async listarMovimientosPedido(
    pedidoId: string,
    sucursalId: string,
    page?: number,
    limit?: number,
  ): Promise<ResultadoPaginado<Record<string, unknown>>> {
    const pedido = await this.database.consultarUno(
      `SELECT id FROM pedidos WHERE id = $1 AND sucursal_id = $2`,
      [pedidoId, sucursalId],
    );
    if (!pedido) throw new NotFoundException('Pedido no encontrado');

    const pag = resolverPaginacion(page, limit, 50);
    const [items, totalRow] = await Promise.all([
      this.database.consultar(
        `SELECT m.id, m.caja_id, c.estado AS caja_estado, p.numero_pedido,
                m.tipo, m.monto,
                m.metodo_pago, m.descripcion, m.pedido_id, m.created_at,
                u.nombre AS responsable
         FROM movimientos_caja m
         INNER JOIN cajas c ON c.id = m.caja_id AND c.sucursal_id = m.sucursal_id
         INNER JOIN pedidos p ON p.id = m.pedido_id AND p.sucursal_id = m.sucursal_id
         LEFT JOIN usuarios u ON u.id = m.usuario_id
         WHERE m.pedido_id = $1 AND m.sucursal_id = $2
         ORDER BY m.created_at DESC
         LIMIT $3 OFFSET $4`,
        [pedidoId, sucursalId, pag.limit, pag.offset],
      ),
      this.database.consultarUno<{ count: number }>(
        `SELECT COUNT(*)::int AS count
         FROM movimientos_caja WHERE pedido_id = $1 AND sucursal_id = $2`,
        [pedidoId, sucursalId],
      ),
    ]);

    return envolverPaginado(
      items as Record<string, unknown>[],
      totalRow?.count ?? 0,
      pag.page,
      pag.limit,
    );
  }

  async retiroParcial(
    dto: RetiroCajaDto,
    usuarioId: string,
    sucursalId: string,
  ) {
    await this.exigirCajaAbierta(dto.caja_id, sucursalId);

    const result = await this.database.enTransaccion(async (client) => {
      await this.cajaMovimientos.insertar(client, {
        cajaId: dto.caja_id,
        sucursalId,
        tipo: 'retiro',
        monto: dto.monto,
        descripcion: dto.descripcion ?? 'Retiro parcial',
        usuarioId,
      });
      return { ok: true };
    });
    void this.realtime.cajaMovimiento(sucursalId, {
      tipo: 'retiro',
      caja_id: dto.caja_id,
      monto: dto.monto,
    });
    return result;
  }

  listarCuentasPorCobrar(sucursalId: string, incluirPagadas = false) {
    const filtro = incluirPagadas ? '' : `AND c.estado = 'pendiente'`;
    return this.database.consultar(
      `SELECT c.id, c.pedido_id, c.domiciliario_planta_id,
              c.cliente_nombre, c.cliente_telefono,
              c.monto, c.estado, c.created_at, c.pagada_at,
              p.numero_pedido,
              uc.nombre AS creada_por,
              (SELECT u.nombre FROM auditoria_logs al
                 JOIN usuarios u ON u.id = al.usuario_id
                 WHERE al.tabla_afectada = 'cuentas_por_cobrar'
                   AND al.registro_id = c.id AND al.accion = 'PAGAR_CUENTA'
                 ORDER BY al.created_at DESC LIMIT 1) AS pagada_por,
              GREATEST(0, EXTRACT(day FROM (now() - c.created_at)))::int AS dias_pendiente,
              (c.estado = 'pendiente'
                AND c.created_at < now() - interval '7 days') AS alerta_antigua
       FROM cuentas_por_cobrar c
       LEFT JOIN pedidos p ON p.id = c.pedido_id
       LEFT JOIN usuarios uc ON uc.id = c.usuario_id
       WHERE c.sucursal_id = $1 ${filtro}
       ORDER BY c.created_at DESC`,
      [sucursalId],
    );
  }

  async resumenCuentasPorCobrar(sucursalId: string) {
    const filas = await this.database.consultar<{
      total_pendiente: string;
      cantidad_pendiente: string;
      antiguas_7d: string;
    }>(
      `SELECT
         COALESCE(SUM(monto), 0) AS total_pendiente,
         COUNT(*)::int AS cantidad_pendiente,
         COUNT(*) FILTER (
           WHERE created_at < now() - interval '7 days'
         )::int AS antiguas_7d
       FROM cuentas_por_cobrar
       WHERE sucursal_id = $1 AND estado = 'pendiente'`,
      [sucursalId],
    );
    const r = filas[0] ?? {
      total_pendiente: '0',
      cantidad_pendiente: '0',
      antiguas_7d: '0',
    };
    return {
      total_pendiente: Number(r.total_pendiente),
      cantidad_pendiente: Number(r.cantidad_pendiente),
      antiguas_7d: Number(r.antiguas_7d),
      dias_alerta: 7,
    };
  }

  async crearCuentaPorCobrar(dto: CrearCuentaPorCobrarDto, usuarioId: string) {
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

  pagarCuentaPorCobrar(
    cuentaId: string,
    sucursalId: string,
    usuarioId: string,
    metodoPago = 'efectivo',
  ) {
    return this.database.enTransaccion(async (client) => {
      const cuenta = await client.query<{
        id: string;
        pedido_id: string | null;
        monto: string;
        estado: string;
        domiciliario_planta_id: string | null;
      }>(
        `SELECT id, pedido_id, monto, estado, domiciliario_planta_id
         FROM cuentas_por_cobrar
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [cuentaId, sucursalId],
      );
      const fila = cuenta.rows[0];
      if (!fila) throw new NotFoundException('Cuenta no encontrada');
      if (fila.estado === 'pagada') {
        throw new BadRequestException({
          error: 'CUENTA_YA_PAGADA',
          mensaje: 'La cuenta ya está pagada',
        });
      }
      if (fila.domiciliario_planta_id) {
        throw new BadRequestException({
          error: 'LIQUIDACION_DOMICILIARIO_REQUERIDA',
          message:
            'Esta cuenta corresponde a un domiciliario. Liquídala desde el módulo Domiciliarios para actualizar también el pedido y sus pagos.',
        });
      }

      const monto = Number(fila.monto);

      await client.query(
        `UPDATE cuentas_por_cobrar
         SET estado = 'pagada', pagada_at = now()
         WHERE id = $1`,
        [cuentaId],
      );

      const cajaId = await this.cajaMovimientos.obtenerCajaAbiertaId(
        client,
        sucursalId,
      );
      if (!cajaId) {
        throw new BadRequestException({
          error: 'CAJA_NO_ABIERTA',
          message: 'Abre la caja antes de cobrar una cuenta por cobrar',
        });
      }
      await this.cajaMovimientos.insertar(client, {
        cajaId,
        sucursalId,
        pedidoId: fila.pedido_id,
        tipo: 'venta',
        monto,
        metodoPago: metodoPago,
        descripcion: `Cobro fiado · ${cuentaId}`,
        usuarioId,
      });

      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'PAGAR_CUENTA',
        tablaAfectada: 'cuentas_por_cobrar',
        registroId: cuentaId,
        usuarioId,
      });

      return {
        id: cuentaId,
        estado: 'pagada',
        monto,
        metodo_pago: metodoPago,
        caja_registrada: true,
      };
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
    const result = await this.database.enTransaccion(async (client) => {
      const monto = Number(params.monto);
      if (monto < 0.01) {
        throw new BadRequestException({
          error: 'MONTO_INVALIDO',
          mensaje: 'El monto de devolución debe ser mayor a cero',
        });
      }

      const disponibleTurno =
        await this.cajaMovimientos.netoVentasDisponiblesTurno(
          client,
          params.caja_id,
        );
      if (monto > disponibleTurno + 0.01) {
        throw new BadRequestException({
          error: 'DEVOLUCION_EXCEDE_VENTAS_TURNO',
          mensaje:
            'La devolución supera las ventas cobradas en este turno. Si cancelaste un pedido no cobrado, no registres devolución: cancelar ya ajusta la caja automáticamente cuando hubo cobro.',
        });
      }

      if (params.pedido_id) {
        const netoPedido = await this.cajaMovimientos.netoCobradoPedidoEnCaja(
          client,
          params.pedido_id,
          params.caja_id,
        );
        if (netoPedido < 0.01) {
          throw new BadRequestException({
            error: 'PEDIDO_SIN_COBRO_CAJA',
            mensaje:
              'Este pedido no tiene cobro registrado en caja. Cancelar el pedido es suficiente; no hace falta devolución manual.',
          });
        }
        if (monto > netoPedido + 0.01) {
          throw new BadRequestException({
            error: 'DEVOLUCION_EXCEDE_COBRO_PEDIDO',
            mensaje: `La devolución no puede superar lo cobrado en caja para este pedido (${netoPedido.toFixed(0)}).`,
          });
        }
      }

      await this.cajaMovimientos.insertar(client, {
        cajaId: params.caja_id,
        sucursalId: params.sucursal_id,
        pedidoId: params.pedido_id ?? null,
        tipo: 'devolucion',
        monto: params.monto,
        metodoPago: params.metodo_pago ?? 'efectivo',
        descripcion: params.motivo.trim(),
        usuarioId,
      });
      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId: params.sucursal_id,
        accion: 'DEVOLUCION_CAJA',
        tablaAfectada: 'movimientos_caja',
        registroId: params.pedido_id ?? params.caja_id,
        usuarioId,
        datosDespues: params,
      });
      return { registrado: true, monto: params.monto };
    });
    void this.realtime.cajaMovimiento(params.sucursal_id, {
      tipo: 'devolucion',
      caja_id: params.caja_id,
      monto: params.monto,
      pedido_id: params.pedido_id ?? null,
    });
    return result;
  }

  async registrarGasto(
    dto: GastoCajaDto,
    usuarioId: string,
    sucursalId: string,
  ) {
    await this.exigirCajaAbierta(dto.caja_id, sucursalId);

    const result = await this.database.enTransaccion(async (client) => {
      await client.query(
        `INSERT INTO gastos
           (sucursal_id, caja_id, concepto, monto, categoria, usuario_id, origen, fecha)
         VALUES ($1,$2,$3,$4,$5,$6,'caja', (now() AT TIME ZONE 'America/Bogota')::date)`,
        [
          sucursalId,
          dto.caja_id,
          dto.concepto,
          dto.monto,
          dto.categoria ?? null,
          usuarioId,
        ],
      );
      await this.cajaMovimientos.insertar(client, {
        cajaId: dto.caja_id,
        sucursalId,
        tipo: 'gasto',
        monto: dto.monto,
        descripcion: dto.concepto,
        usuarioId,
      });
      return { ok: true };
    });
    void this.realtime.cajaMovimiento(sucursalId, {
      tipo: 'gasto',
      caja_id: dto.caja_id,
      monto: dto.monto,
    });
    return result;
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
        mensaje: 'No hay caja abierta para esta operación',
      });
    }
  }

  private async calcularResumenTurno(cajaId: string) {
    // Ventas netas: una venta revertida por devolución (p. ej. pedido cancelado)
    // no debe inflar el total. Se conservan ambos movimientos para auditoría,
    // pero el indicador de ventas resta las devoluciones.
    const ventas = await this.database.consultarUno<{ total: string }>(
      `SELECT COALESCE(SUM(
         CASE
           WHEN tipo = 'venta' THEN monto
           WHEN tipo = 'devolucion' THEN -monto
           ELSE 0
         END
       ), 0)::text AS total
       FROM movimientos_caja
       WHERE caja_id = $1 AND tipo IN ('venta', 'devolucion')`,
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
      `SELECT ${SQL_SALDO_EFECTIVO_CAJA}
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
