import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { ReemplazarItemPedidoDto } from './dto/reemplazar-item-pedido.dto';
import { ActualizarItemPedidoDto } from './dto/actualizar-item-pedido.dto';
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosCrearService } from './pedidos-crear.service';
import { PedidosDescuentoService } from './pedidos-descuento.service';
import { PedidosEstadoService } from './pedidos-estado.service';
import { PedidosItemsService } from './pedidos-items.service';
import { PedidosPagosService } from './pedidos-pagos.service';
import { sqlWherePedidoAbiertoOperativo } from './pedido-estados';
import {
  envolverPaginado,
  resolverPaginacion,
  ResultadoPaginado,
} from '../../compartido/dto/paginacion.dto';
import { OpcionesStaffPedido } from './pedidos-soporte.service';

@Injectable()
export class PedidosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly sucursalScope: SucursalScopeService,
    private readonly cuentaMesa: PedidosCuentaMesaService,
    private readonly estado: PedidosEstadoService,
    private readonly crearPedido: PedidosCrearService,
    private readonly items: PedidosItemsService,
    private readonly descuento: PedidosDescuentoService,
    private readonly pagos: PedidosPagosService,
  ) {}

  async listarPorSucursal(
    sucursalId: string,
    opciones: {
      soloActivos?: boolean;
      limite?: number;
      page?: number;
      paginar?: boolean;
      meseraId?: string;
      busqueda?: string;
    } = {},
  ) {
    const params: unknown[] = [sucursalId];
    const filtroActivos = opciones.soloActivos
      ? `AND ${sqlWherePedidoAbiertoOperativo('p')}`
      : '';
    let filtroMesera = '';
    if (opciones.meseraId) {
      params.push(opciones.meseraId);
      const idx = params.length;
      filtroMesera = ` AND (
        p.mesera_id = $${idx}
        OR m.mesera_asignada_id = $${idx}
        OR (p.tipo = 'mesa' AND p.mesera_id IS NULL AND m.mesera_asignada_id IS NULL)
      )`;
    }
    let filtroBusqueda = '';
    if (opciones.busqueda) {
      params.push(`%${opciones.busqueda}%`);
      const idx = params.length;
      filtroBusqueda = ` AND (
        p.numero_pedido::text ILIKE $${idx}
        OR COALESCE(p.cliente_nombre, '') ILIKE $${idx}
        OR COALESCE(p.cliente_telefono, '') ILIKE $${idx}
        OR COALESCE(m.nombre, '') ILIKE $${idx}
      )`;
    }

    const fromJoin = `
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       LEFT JOIN usuarios u_mesera ON u_mesera.id = p.mesera_id
       LEFT JOIN LATERAL (
         SELECT ad.domiciliario_planta_id
         FROM asignaciones_domicilio ad
         WHERE ad.pedido_id = p.id
           AND ad.estado IN ('asignado', 'en_camino', 'entregado')
         ORDER BY ad.asignado_at DESC
         LIMIT 1
       ) ad ON true
       LEFT JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
       LEFT JOIN usuarios u_dom ON u_dom.id = dp.usuario_id
       LEFT JOIN LATERAL (
         SELECT fecha FROM estados_pedido_historial
         WHERE pedido_id = p.id AND estado_nuevo = p.estado
         ORDER BY fecha DESC
         LIMIT 1
       ) h ON true
       WHERE p.sucursal_id = $1 ${filtroActivos}${filtroMesera}${filtroBusqueda}`;

    const selectCols = `SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.cliente_nombre,
              p.cliente_telefono, p.direccion_entrega, p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado, p.metodo_pago,
              p.created_at, p.mesa_id,
              p.mesera_id, u_mesera.nombre AS mesera_nombre,
              m.nombre AS mesa_nombre,
              m.mesera_asignada_id,
              u_dom.nombre AS domiciliario_nombre,
              COALESCE(h.fecha, p.created_at) AS estado_desde`;

    if (!opciones.paginar) {
      const limite = opciones.limite ?? 100;
      params.push(limite);
      const limIdx = params.length;
      const filas = await this.database.consultar(
        `${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limIdx}`,
        params,
      );
      return this.adjuntarItemsResumen(
        filas as Array<Record<string, unknown> & { id: string }>,
      );
    }

    const { page, limit, offset } = resolverPaginacion(
      opciones.page,
      opciones.limite,
      20,
    );

    const countParams = [...params];
    params.push(limit, offset);
    const limitIdx = params.length - 1;
    const offsetIdx = params.length;

    const [filas, totalRow] = await Promise.all([
      this.database.consultar(
        `${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
        params,
      ),
      this.database.consultarUno<{ count: number }>(
        `SELECT COUNT(*)::int AS count ${fromJoin}`,
        countParams,
      ),
    ]);

    const conItems = await this.adjuntarItemsResumen(
      filas as Array<Record<string, unknown> & { id: string }>,
    );
    return envolverPaginado(
      conItems,
      totalRow?.count ?? 0,
      page,
      limit,
    ) as ResultadoPaginado<(typeof conItems)[number]>;
  }

  /** Pedidos terminales creados hoy (sección «Cerrados hoy»). */
  async listarCerradosHoy(
    sucursalId: string,
    opciones: {
      limite?: number;
      page?: number;
      paginar?: boolean;
      meseraId?: string;
    } = {},
  ) {
    const params: unknown[] = [sucursalId];
    let filtroMesera = '';
    if (opciones.meseraId) {
      params.push(opciones.meseraId);
      const idx = params.length;
      filtroMesera = ` AND p.mesera_id = $${idx}`;
    }
    const where = `WHERE p.sucursal_id = $1
         AND (
           p.estado IN ('pagado', 'cancelado', 'rechazado')
           OR (
             p.estado = 'entregado'
             AND COALESCE(p.monto_pagado, 0) >= p.total - 0.01
           )
         )
         AND p.created_at >= date_trunc('day', NOW())
         ${filtroMesera}`;
    const fromJoin = `FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       LEFT JOIN usuarios u_mesera ON u_mesera.id = p.mesera_id
       ${where}`;
    const selectCols = `SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.cliente_nombre,
              p.cliente_telefono, p.direccion_entrega, p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado, p.metodo_pago,
              p.created_at, p.mesa_id,
              p.mesera_id, u_mesera.nombre AS mesera_nombre,
              m.nombre AS mesa_nombre,
              m.mesera_asignada_id,
              NULL::text AS domiciliario_nombre,
              p.created_at AS estado_desde`;

    if (!opciones.paginar) {
      const limite = opciones.limite ?? 50;
      params.push(limite);
      const limIdx = params.length;
      const filas = await this.database.consultar(
        `${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limIdx}`,
        params,
      );
      return this.adjuntarItemsResumen(
        filas as Array<Record<string, unknown> & { id: string }>,
      );
    }

    const { page, limit, offset } = resolverPaginacion(
      opciones.page,
      opciones.limite,
      30,
    );
    const countParams = [...params];
    params.push(limit, offset);
    const limitIdx = params.length - 1;
    const offsetIdx = params.length;
    const [filas, totalRow] = await Promise.all([
      this.database.consultar(
        `${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
        params,
      ),
      this.database.consultarUno<{ count: number }>(
        `SELECT COUNT(*)::int AS count ${fromJoin}`,
        countParams,
      ),
    ]);
    const conItems = await this.adjuntarItemsResumen(
      filas as Array<Record<string, unknown> & { id: string }>,
    );
    return envolverPaginado(conItems, totalRow?.count ?? 0, page, limit);
  }

  /** Detalle staff: cabecera + items_resumen (modal kanban). */
  async obtenerDetalleAdmin(pedidoId: string, sucursalId: string) {
    const fila = await this.database.consultarUno<{
      id: string;
      numero_pedido: string;
      tipo: string;
      estado: string;
      cliente_nombre: string | null;
      cliente_telefono: string | null;
      direccion_entrega: string | null;
      total: string;
      monto_pagado: string;
      metodo_pago: string | null;
      pagos_resumen: Array<{
        metodo_pago: string;
        monto: number;
      }>;
      propina_recibida: string;
      devoluciones_caja_vinculadas: string;
      recaudo_neto_caja_vinculado: string;
      created_at: string;
      mesa_id: string | null;
      mesera_id: string | null;
      mesera_nombre: string | null;
      mesa_nombre: string | null;
      domiciliario_nombre: string | null;
      estado_desde: string;
      observaciones: string | null;
    }>(
      `SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.cliente_nombre,
              p.cliente_telefono, p.direccion_entrega, p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado, p.metodo_pago,
              COALESCE(pagos.resumen, '[]'::jsonb) AS pagos_resumen,
              COALESCE(pagos.propina, 0) AS propina_recibida,
              COALESCE(caja.devoluciones, 0) AS devoluciones_caja_vinculadas,
              COALESCE(caja.ventas, 0) - COALESCE(caja.devoluciones, 0)
                AS recaudo_neto_caja_vinculado,
              p.created_at, p.mesa_id, p.observaciones,
              p.mesera_id, u_mesera.nombre AS mesera_nombre,
              m.nombre AS mesa_nombre,
              m.mesera_asignada_id,
              NULL::text AS domiciliario_nombre,
              COALESCE(h.fecha, p.created_at) AS estado_desde
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       LEFT JOIN usuarios u_mesera ON u_mesera.id = p.mesera_id
       LEFT JOIN LATERAL (
         SELECT fecha FROM estados_pedido_historial
         WHERE pedido_id = p.id AND estado_nuevo = p.estado
         ORDER BY fecha DESC LIMIT 1
       ) h ON true
       LEFT JOIN LATERAL (
         SELECT jsonb_agg(jsonb_build_object(
           'metodo_pago', pagos.metodo_pago,
           'monto', pagos.monto
         ) ORDER BY pagos.metodo_pago) AS resumen,
         SUM(pagos.propina) AS propina
         FROM (
           SELECT metodo_pago, SUM(monto) AS monto, SUM(propina) AS propina
           FROM pagos_pedido
           WHERE pedido_id = p.id AND sucursal_id = p.sucursal_id
           GROUP BY metodo_pago
         ) pagos
       ) pagos ON true
       LEFT JOIN LATERAL (
         SELECT SUM(m.monto) FILTER (WHERE m.tipo = 'devolucion') AS devoluciones,
                SUM(m.monto) FILTER (WHERE m.tipo = 'venta') AS ventas
         FROM movimientos_caja m
         WHERE m.pedido_id = p.id
           AND m.sucursal_id = p.sucursal_id
           AND m.tipo IN ('venta', 'devolucion')
       ) caja ON true
       WHERE p.id = $1 AND p.sucursal_id = $2`,
      [pedidoId, sucursalId],
    );
    if (!fila) throw new NotFoundException('Pedido no encontrado');
    const [conItems] = await this.adjuntarItemsResumen([
      fila as Record<string, unknown> & { id: string },
    ]);
    return conItems;
  }

  /** Adjunta preview de ítems para cards/modal (sin precios calculados en cliente). */
  private async adjuntarItemsResumen(
    filas: Array<Record<string, unknown> & { id: string }>,
  ): Promise<
    Array<Record<string, unknown> & { id: string; items_resumen: unknown[] }>
  > {
    if (filas.length === 0) return [];
    const ids = filas.map((f) => f.id);
    const items = await this.database.consultar<{
      pedido_id: string;
      item_id: string;
      producto_id: string | null;
      nombre: string;
      cantidad: number;
      observaciones: string | null;
      estado_cocina: string;
      tiene_toppings: boolean;
      tiene_bebidas: boolean;
      toppings_nombres: string | null;
      bebidas_nombres: string | null;
      topping_ids: string[] | null;
    }>(
      `SELECT pi.pedido_id::text AS pedido_id,
              pi.id::text AS item_id,
              pi.producto_id::text AS producto_id,
              COALESCE(pr.nombre, 'Ítem') AS nombre,
              pi.cantidad,
              pi.observaciones,
              pi.estado_cocina,
              EXISTS (
                SELECT 1 FROM pedido_item_toppings t
                WHERE t.pedido_item_id = pi.id
              ) AS tiene_toppings,
              EXISTS (
                SELECT 1 FROM pedido_item_bebidas b
                WHERE b.pedido_item_id = pi.id
              ) AS tiene_bebidas,
              (
                SELECT string_agg(t.nombre_topping, ', ' ORDER BY t.nombre_topping)
                FROM pedido_item_toppings t WHERE t.pedido_item_id = pi.id
              ) AS toppings_nombres,
              (
                SELECT string_agg(b.nombre_bebida, ', ' ORDER BY b.nombre_bebida)
                FROM pedido_item_bebidas b WHERE b.pedido_item_id = pi.id
              ) AS bebidas_nombres,
              (
                SELECT COALESCE(array_agg(t.topping_id::text ORDER BY t.nombre_topping), ARRAY[]::text[])
                FROM pedido_item_toppings t WHERE t.pedido_item_id = pi.id
              ) AS topping_ids
       FROM pedido_items pi
       LEFT JOIN productos pr ON pr.id = pi.producto_id
       WHERE pi.pedido_id = ANY($1::uuid[])
       ORDER BY pi.created_at`,
      [ids],
    );
    const porPedido = new Map<string, unknown[]>();
    for (const it of items) {
      const lista = porPedido.get(it.pedido_id) ?? [];
      lista.push({
        item_id: it.item_id,
        producto_id: it.producto_id,
        nombre: it.nombre,
        cantidad: Number(it.cantidad),
        observaciones: it.observaciones,
        estado_cocina: it.estado_cocina,
        tiene_toppings: it.tiene_toppings === true,
        tiene_bebidas: it.tiene_bebidas === true,
        toppings_nombres: it.toppings_nombres,
        bebidas_nombres: it.bebidas_nombres,
        topping_ids: it.topping_ids ?? [],
      });
      porPedido.set(it.pedido_id, lista);
    }
    return filas.map((f) => ({
      ...f,
      items_resumen: porPedido.get(f.id) ?? [],
    }));
  }

  /** Pedidos activos de una mesa con ítems y estado de cocina (A-MES-3). */
  async listarActivosPorMesa(sucursalId: string, mesaId: string) {
    return this.cuentaMesa.listarActivosPorMesa(sucursalId, mesaId);
  }

  async cambiarEstado(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    nuevoEstado: string,
    motivo?: string,
    contexto?: { rol: string; permisos: string[] },
  ) {
    return this.estado.cambiarEstado(
      pedidoId,
      sucursalId,
      usuarioId,
      nuevoEstado,
      motivo,
      contexto,
    );
  }

  cancelarPorCliente(pedidoId: string, deviceId: string, motivo: string) {
    return this.estado.cancelarPorCliente(pedidoId, deviceId, motivo);
  }

  llamarMesera(pedidoId: string, deviceId: string, mensaje?: string) {
    return this.estado.llamarMesera(pedidoId, deviceId, mensaje);
  }

  calificarDomicilio(
    pedidoId: string,
    deviceId: string,
    calificacion: number,
    comentario?: string,
  ) {
    return this.estado.calificarDomicilio(
      pedidoId,
      deviceId,
      calificacion,
      comentario,
    );
  }

  async crear(dto: CrearPedidoDto, opciones: OpcionesStaffPedido = {}) {
    return this.crearPedido.crear(dto, opciones);
  }

  /** BN-CTRL-12: merge sucursal + BadRequest en service. */
  async crearStaff(usuario: JwtPayload, dto: CrearPedidoDto) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id ?? usuario.sucursal_id,
    );
    if (!sucursalId) {
      throw new BadRequestException('sucursal_id es obligatorio');
    }
    return this.crear(
      { ...dto, sucursal_id: sucursalId },
      {
        creadoPorStaff: true,
        usuarioId: usuario.sub,
        rol: usuario.rol,
        puedeCobrar: usuario.permisos.includes('cobrar_pedido'),
      },
    );
  }

  async estimar(dto: CrearPedidoDto) {
    return this.crearPedido.crear(dto, { soloEstimar: true });
  }

  async agregarItems(
    pedidoId: string,
    sucursalId: string,
    dto: AgregarItemsPedidoDto,
    opciones: OpcionesStaffPedido = {},
  ) {
    return this.items.agregarItems(pedidoId, sucursalId, dto, opciones);
  }

  async reemplazarItemPedido(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    usuarioId: string,
    dto: ReemplazarItemPedidoDto,
    opciones: OpcionesStaffPedido = {},
  ) {
    return this.items.reemplazarItemPedido(
      pedidoId,
      itemId,
      sucursalId,
      usuarioId,
      dto,
      opciones,
    );
  }

  async actualizarItemPedido(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    usuarioId: string,
    dto: ActualizarItemPedidoDto,
  ) {
    return this.items.actualizarItemPedido(
      pedidoId,
      itemId,
      sucursalId,
      usuarioId,
      dto,
    );
  }

  /** Marca todos los pedidos activos de la mesa como pagados y libera la mesa. */
  async cobrarCuentaMesa(
    sucursalId: string,
    mesaId: string,
    usuarioId: string,
    dto: CobrarMesaDto = {},
    rol?: string | null,
  ) {
    return this.pagos.cobrarCuentaMesa(sucursalId, mesaId, usuarioId, dto, rol);
  }

  async cobrarPedidoCaja(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    dto: CobrarMesaDto = {},
    rol?: string | null,
  ) {
    return this.pagos.cobrarPedidoCaja(
      sucursalId,
      pedidoId,
      usuarioId,
      dto,
      rol,
    );
  }

  async actualizarComensalItem(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    comensalEtiqueta: string | null,
  ) {
    return this.items.actualizarComensalEtiqueta(
      pedidoId,
      itemId,
      sucursalId,
      comensalEtiqueta,
    );
  }

  /**
   * Historial cliente: por device y, si hay sesión Google, también por auth_uid
   * (pedidos de otros dispositivos ya vinculados).
   */
  async listarPorDevice(deviceId: string, authUid?: string | null) {
    const uid = authUid?.trim() || null;
    return this.database.consultar(
      `SELECT p.id, p.numero_pedido, p.estado, p.tipo, p.total,
              p.created_at,
              p.seguimiento_token::text AS seguimiento_token,
              s.nombre AS sucursal_nombre
       FROM pedidos p
       INNER JOIN sucursales s ON s.id = p.sucursal_id
       WHERE p.device_id = $1
          OR ($2::uuid IS NOT NULL AND p.cliente_auth_uid = $2::uuid)
       ORDER BY p.created_at DESC
       LIMIT 50`,
      [deviceId, uid],
    );
  }

  async obtenerEstadoPublico(
    pedidoId: string,
    opts: { deviceId?: string; seguimientoToken?: string } = {},
  ) {
    const pedido = await this.database.consultarUno<{
      id: string;
      numero_pedido: string;
      estado: string;
      total: string;
      tipo: string;
      mesa_id: string | null;
      device_id: string | null;
      seguimiento_token: string;
      lat: string | null;
      lng: string | null;
      direccion_entrega: string | null;
      tiempo_estimado_minutos: number | null;
      created_at: Date;
      items_no_disponibles: Array<{ nombre: string; cantidad: number }>;
    }>(
      `SELECT id, numero_pedido, estado, total, tipo, mesa_id, device_id,
              seguimiento_token::text AS seguimiento_token,
              lat, lng, direccion_entrega,
              tiempo_estimado_minutos, created_at,
              (
                SELECT COALESCE(
                  json_agg(
                    json_build_object(
                      'nombre', COALESCE(pr.nombre, 'Producto'),
                      'cantidad', pi.cantidad
                    ) ORDER BY pi.created_at
                  ),
                  '[]'::json
                )
                FROM pedido_items pi
                LEFT JOIN productos pr ON pr.id = pi.producto_id
                WHERE pi.pedido_id = pedidos.id
                  AND pi.estado_cocina = 'no_disponible'
              ) AS items_no_disponibles
       FROM pedidos WHERE id = $1`,
      [pedidoId],
    );
    if (!pedido) throw new NotFoundException('Pedido no encontrado');

    const deviceOk =
      !!opts.deviceId?.trim() &&
      !!pedido.device_id &&
      pedido.device_id === opts.deviceId.trim();
    const tokenOk =
      !!opts.seguimientoToken?.trim() &&
      pedido.seguimiento_token === opts.seguimientoToken.trim();
    if (!deviceOk && !tokenOk) {
      throw new ForbiddenException({
        error: 'SEGUIMIENTO_NO_AUTORIZADO',
        message: 'Indica device_id o token de seguimiento válido',
      });
    }

    let mesaNombre: string | null = null;
    if (pedido.mesa_id) {
      const mesa = await this.database.consultarUno<{ nombre: string }>(
        `SELECT nombre FROM mesas WHERE id = $1`,
        [pedido.mesa_id],
      );
      mesaNombre = mesa?.nombre ?? null;
    }

    const historial = await this.database.consultar<{
      estado_nuevo: string;
      fecha: Date;
    }>(
      `SELECT estado_nuevo, fecha FROM estados_pedido_historial
       WHERE pedido_id = $1 ORDER BY fecha ASC`,
      [pedidoId],
    );

    let repartidorLat: number | null = null;
    let repartidorLng: number | null = null;
    if (pedido.estado === 'en_camino') {
      const ubicacion = await this.database.consultarUno<{
        lat: string;
        lng: string;
      }>(
        `SELECT h.lat, h.lng
         FROM asignaciones_domicilio ad
         INNER JOIN domiciliarios_ubicaciones_historial h ON h.asignacion_id = ad.id
         WHERE ad.pedido_id = $1 AND ad.estado = 'en_camino'
         ORDER BY h.registrado_at DESC
         LIMIT 1`,
        [pedidoId],
      );
      if (ubicacion) {
        repartidorLat = Number(ubicacion.lat);
        repartidorLng = Number(ubicacion.lng);
      }
    }

    return {
      pedido_id: pedido.id,
      numero_pedido: pedido.numero_pedido,
      estado_actual: pedido.estado,
      seguimiento_token: pedido.seguimiento_token,
      tipo: pedido.tipo,
      mesa_id: pedido.mesa_id,
      mesa_nombre: mesaNombre,
      total: Number(pedido.total),
      lat: pedido.lat != null ? Number(pedido.lat) : null,
      lng: pedido.lng != null ? Number(pedido.lng) : null,
      repartidor_lat: repartidorLat,
      repartidor_lng: repartidorLng,
      direccion_entrega: pedido.direccion_entrega,
      tiempo_estimado_minutos: pedido.tiempo_estimado_minutos,
      created_at: pedido.created_at,
      items_no_disponibles: pedido.items_no_disponibles ?? [],
      historial: historial.map((h) => ({
        estado: h.estado_nuevo,
        fecha: h.fecha,
      })),
    };
  }

  async aprobarMesa(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    opciones?: { meseraId?: string; rolLlamador?: string },
  ) {
    return this.estado.aprobarMesa(pedidoId, sucursalId, usuarioId, opciones);
  }

  async rechazarMesa(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    motivo: string,
  ) {
    return this.estado.rechazarMesa(pedidoId, sucursalId, usuarioId, motivo);
  }

  async aplicarDescuento(
    pedidoId: string,
    sucursalId: string,
    usuarioId: string,
    dto: AplicarDescuentoDto,
    contexto: { rol: string; permisos: string[] },
  ) {
    return this.descuento.aplicarDescuento(
      pedidoId,
      sucursalId,
      usuarioId,
      dto,
      contexto,
    );
  }

  async eliminarItemPedido(
    pedidoId: string,
    itemId: string,
    sucursalId: string,
    usuarioId: string,
    motivo?: string,
  ) {
    return this.items.eliminarItemPedido(
      pedidoId,
      itemId,
      sucursalId,
      usuarioId,
      motivo,
    );
  }
}
