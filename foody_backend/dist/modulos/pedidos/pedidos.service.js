"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PedidosService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
const pedidos_crear_service_1 = require("./pedidos-crear.service");
const pedidos_descuento_service_1 = require("./pedidos-descuento.service");
const pedidos_estado_service_1 = require("./pedidos-estado.service");
const pedidos_items_service_1 = require("./pedidos-items.service");
const pedidos_pagos_service_1 = require("./pedidos-pagos.service");
const pedidos_combo_decisiones_service_1 = require("./pedidos-combo-decisiones.service");
const pedido_estados_1 = require("./pedido-estados");
const paginacion_dto_1 = require("../../compartido/dto/paginacion.dto");
let PedidosService = class PedidosService {
    database;
    sucursalScope;
    cuentaMesa;
    estado;
    crearPedido;
    items;
    descuento;
    pagos;
    decisionesCombo;
    constructor(database, sucursalScope, cuentaMesa, estado, crearPedido, items, descuento, pagos, decisionesCombo) {
        this.database = database;
        this.sucursalScope = sucursalScope;
        this.cuentaMesa = cuentaMesa;
        this.estado = estado;
        this.crearPedido = crearPedido;
        this.items = items;
        this.descuento = descuento;
        this.pagos = pagos;
        this.decisionesCombo = decisionesCombo;
    }
    listarDecisionesComboPendientes(pedidoId, sucursalId) {
        return this.decisionesCombo.listarPendientes(pedidoId, sucursalId);
    }
    cotizarReemplazoCombo(pedidoId, decisionId, sucursalId, reemplazoId, usuarioId) {
        return this.decisionesCombo.cotizarReemplazo(pedidoId, decisionId, sucursalId, reemplazoId, usuarioId);
    }
    responderDecisionCombo(pedidoId, decisionId, sucursalId, usuarioId, dto) {
        return this.decisionesCombo.responder(pedidoId, decisionId, sucursalId, usuarioId, dto);
    }
    async listarPorSucursal(sucursalId, opciones = {}) {
        const params = [sucursalId];
        const filtroActivos = opciones.soloActivos
            ? `AND ${(0, pedido_estados_1.sqlWherePedidoAbiertoOperativo)('p')}`
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
            const filas = await this.database.consultar(`${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limIdx}`, params);
            return this.adjuntarItemsResumen(filas);
        }
        const { page, limit, offset } = (0, paginacion_dto_1.resolverPaginacion)(opciones.page, opciones.limite, 20);
        const countParams = [...params];
        params.push(limit, offset);
        const limitIdx = params.length - 1;
        const offsetIdx = params.length;
        const [filas, totalRow] = await Promise.all([
            this.database.consultar(`${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limitIdx} OFFSET $${offsetIdx}`, params),
            this.database.consultarUno(`SELECT COUNT(*)::int AS count ${fromJoin}`, countParams),
        ]);
        const conItems = await this.adjuntarItemsResumen(filas);
        return (0, paginacion_dto_1.envolverPaginado)(conItems, totalRow?.count ?? 0, page, limit);
    }
    async listarCerradosHoy(sucursalId, opciones = {}) {
        const params = [sucursalId];
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
            const filas = await this.database.consultar(`${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limIdx}`, params);
            return this.adjuntarItemsResumen(filas);
        }
        const { page, limit, offset } = (0, paginacion_dto_1.resolverPaginacion)(opciones.page, opciones.limite, 30);
        const countParams = [...params];
        params.push(limit, offset);
        const limitIdx = params.length - 1;
        const offsetIdx = params.length;
        const [filas, totalRow] = await Promise.all([
            this.database.consultar(`${selectCols} ${fromJoin}
       ORDER BY p.created_at DESC
       LIMIT $${limitIdx} OFFSET $${offsetIdx}`, params),
            this.database.consultarUno(`SELECT COUNT(*)::int AS count ${fromJoin}`, countParams),
        ]);
        const conItems = await this.adjuntarItemsResumen(filas);
        return (0, paginacion_dto_1.envolverPaginado)(conItems, totalRow?.count ?? 0, page, limit);
    }
    async obtenerDetalleAdmin(pedidoId, sucursalId) {
        const fila = await this.database.consultarUno(`SELECT p.id, p.numero_pedido, p.tipo, p.estado, p.cliente_nombre,
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
       WHERE p.id = $1 AND p.sucursal_id = $2`, [pedidoId, sucursalId]);
        if (!fila)
            throw new common_1.NotFoundException('Pedido no encontrado');
        const [conItems] = await this.adjuntarItemsResumen([
            fila,
        ]);
        return conItems;
    }
    async adjuntarItemsResumen(filas) {
        if (filas.length === 0)
            return [];
        const ids = filas.map((f) => f.id);
        const items = await this.database.consultar(`SELECT pi.pedido_id::text AS pedido_id,
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
       ORDER BY pi.created_at`, [ids]);
        const porPedido = new Map();
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
    async listarActivosPorMesa(sucursalId, mesaId) {
        return this.cuentaMesa.listarActivosPorMesa(sucursalId, mesaId);
    }
    async cambiarEstado(pedidoId, sucursalId, usuarioId, nuevoEstado, motivo, contexto) {
        return this.estado.cambiarEstado(pedidoId, sucursalId, usuarioId, nuevoEstado, motivo, contexto);
    }
    cancelarPorCliente(pedidoId, deviceId, motivo) {
        return this.estado.cancelarPorCliente(pedidoId, deviceId, motivo);
    }
    llamarMesera(pedidoId, deviceId, mensaje) {
        return this.estado.llamarMesera(pedidoId, deviceId, mensaje);
    }
    calificarDomicilio(pedidoId, deviceId, calificacion, comentario) {
        return this.estado.calificarDomicilio(pedidoId, deviceId, calificacion, comentario);
    }
    async crear(dto, opciones = {}) {
        return this.crearPedido.crear(dto, opciones);
    }
    async crearStaff(usuario, dto) {
        const sucursalId = await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_id ?? usuario.sucursal_id);
        if (!sucursalId) {
            throw new common_1.BadRequestException('sucursal_id es obligatorio');
        }
        return this.crear({ ...dto, sucursal_id: sucursalId }, {
            creadoPorStaff: true,
            usuarioId: usuario.sub,
            rol: usuario.rol,
            puedeCobrar: usuario.permisos.includes('cobrar_pedido'),
        });
    }
    async estimar(dto) {
        return this.crearPedido.crear(dto, { soloEstimar: true });
    }
    async agregarItems(pedidoId, sucursalId, dto, opciones = {}) {
        return this.items.agregarItems(pedidoId, sucursalId, dto, opciones);
    }
    async reemplazarItemPedido(pedidoId, itemId, sucursalId, usuarioId, dto, opciones = {}) {
        return this.items.reemplazarItemPedido(pedidoId, itemId, sucursalId, usuarioId, dto, opciones);
    }
    async actualizarItemPedido(pedidoId, itemId, sucursalId, usuarioId, dto) {
        return this.items.actualizarItemPedido(pedidoId, itemId, sucursalId, usuarioId, dto);
    }
    async cobrarCuentaMesa(sucursalId, mesaId, usuarioId, dto = {}, rol) {
        return this.pagos.cobrarCuentaMesa(sucursalId, mesaId, usuarioId, dto, rol);
    }
    async cobrarPedidoCaja(pedidoId, sucursalId, usuarioId, dto = {}, rol) {
        return this.pagos.cobrarPedidoCaja(sucursalId, pedidoId, usuarioId, dto, rol);
    }
    async actualizarComensalItem(pedidoId, itemId, sucursalId, comensalEtiqueta) {
        return this.items.actualizarComensalEtiqueta(pedidoId, itemId, sucursalId, comensalEtiqueta);
    }
    async listarPorDevice(deviceId, authUid) {
        const uid = authUid?.trim() || null;
        return this.database.consultar(`SELECT p.id, p.numero_pedido, p.estado, p.tipo, p.total,
              p.created_at,
              p.seguimiento_token::text AS seguimiento_token,
              s.nombre AS sucursal_nombre
       FROM pedidos p
       INNER JOIN sucursales s ON s.id = p.sucursal_id
       WHERE p.device_id = $1
          OR ($2::uuid IS NOT NULL AND p.cliente_auth_uid = $2::uuid)
       ORDER BY p.created_at DESC
       LIMIT 50`, [deviceId, uid]);
    }
    async obtenerEstadoPublico(pedidoId, opts = {}) {
        const pedido = await this.database.consultarUno(`SELECT id, numero_pedido, estado, total, tipo, mesa_id, device_id,
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
       FROM pedidos WHERE id = $1`, [pedidoId]);
        if (!pedido)
            throw new common_1.NotFoundException('Pedido no encontrado');
        const deviceOk = !!opts.deviceId?.trim() &&
            !!pedido.device_id &&
            pedido.device_id === opts.deviceId.trim();
        const tokenOk = !!opts.seguimientoToken?.trim() &&
            pedido.seguimiento_token === opts.seguimientoToken.trim();
        if (!deviceOk && !tokenOk) {
            throw new common_1.ForbiddenException({
                error: 'SEGUIMIENTO_NO_AUTORIZADO',
                message: 'Indica device_id o token de seguimiento válido',
            });
        }
        let mesaNombre = null;
        if (pedido.mesa_id) {
            const mesa = await this.database.consultarUno(`SELECT nombre FROM mesas WHERE id = $1`, [pedido.mesa_id]);
            mesaNombre = mesa?.nombre ?? null;
        }
        const historial = await this.database.consultar(`SELECT estado_nuevo, fecha FROM estados_pedido_historial
       WHERE pedido_id = $1 ORDER BY fecha ASC`, [pedidoId]);
        let repartidorLat = null;
        let repartidorLng = null;
        if (pedido.estado === 'en_camino') {
            const ubicacion = await this.database.consultarUno(`SELECT h.lat, h.lng
         FROM asignaciones_domicilio ad
         INNER JOIN domiciliarios_ubicaciones_historial h ON h.asignacion_id = ad.id
         WHERE ad.pedido_id = $1 AND ad.estado = 'en_camino'
         ORDER BY h.registrado_at DESC
         LIMIT 1`, [pedidoId]);
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
    async aprobarMesa(pedidoId, sucursalId, usuarioId, opciones) {
        return this.estado.aprobarMesa(pedidoId, sucursalId, usuarioId, opciones);
    }
    async rechazarMesa(pedidoId, sucursalId, usuarioId, motivo) {
        return this.estado.rechazarMesa(pedidoId, sucursalId, usuarioId, motivo);
    }
    async aplicarDescuento(pedidoId, sucursalId, usuarioId, dto, contexto) {
        return this.descuento.aplicarDescuento(pedidoId, sucursalId, usuarioId, dto, contexto);
    }
    async eliminarItemPedido(pedidoId, itemId, sucursalId, usuarioId, motivo) {
        const combo = await this.database.consultarUno(`SELECT EXISTS (
         SELECT 1 FROM pedido_combo_selecciones pcs
         JOIN pedido_items pi ON pi.id = pcs.pedido_item_id
         WHERE pcs.pedido_item_id = $1 AND pi.pedido_id = $2
           AND EXISTS (SELECT 1 FROM pedidos p
                       WHERE p.id = $2 AND p.sucursal_id = $3)
       ) AS existe`, [itemId, pedidoId, sucursalId]);
        if (combo?.existe) {
            return this.decisionesCombo.cancelarComboManual(pedidoId, itemId, sucursalId, usuarioId, motivo);
        }
        return this.items.eliminarItemPedido(pedidoId, itemId, sucursalId, usuarioId, motivo);
    }
};
exports.PedidosService = PedidosService;
exports.PedidosService = PedidosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        sucursal_scope_service_1.SucursalScopeService,
        pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
        pedidos_estado_service_1.PedidosEstadoService,
        pedidos_crear_service_1.PedidosCrearService,
        pedidos_items_service_1.PedidosItemsService,
        pedidos_descuento_service_1.PedidosDescuentoService,
        pedidos_pagos_service_1.PedidosPagosService,
        pedidos_combo_decisiones_service_1.PedidosComboDecisionesService])
], PedidosService);
//# sourceMappingURL=pedidos.service.js.map