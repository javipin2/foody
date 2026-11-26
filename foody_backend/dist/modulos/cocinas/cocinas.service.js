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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CocinasService = void 0;
const common_1 = require("@nestjs/common");
const menu_cache_service_1 = require("../../core/cache/menu-cache.service");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const roles_food_1 = require("../../core/auth/roles-food");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const dispatch_service_1 = require("../domiciliarios/dispatch.service");
const pedidos_estado_command_service_1 = require("../pedidos/pedidos-estado-command.service");
const pedidos_inventario_service_1 = require("../pedidos/pedidos-inventario.service");
const pedidos_soporte_service_1 = require("../pedidos/pedidos-soporte.service");
const pedido_estados_1 = require("../pedidos/pedido-estados");
let CocinasService = class CocinasService {
    database;
    realtime;
    menuCache;
    alertasRiesgo;
    dispatch;
    pedidosEstadoCommand;
    pedidosSoporte;
    pedidosInventario;
    constructor(database, realtime, menuCache, alertasRiesgo, dispatch, pedidosEstadoCommand, pedidosSoporte, pedidosInventario) {
        this.database = database;
        this.realtime = realtime;
        this.menuCache = menuCache;
        this.alertasRiesgo = alertasRiesgo;
        this.dispatch = dispatch;
        this.pedidosEstadoCommand = pedidosEstadoCommand;
        this.pedidosSoporte = pedidosSoporte;
        this.pedidosInventario = pedidosInventario;
    }
    listarCocinas(sucursalId) {
        return this.database.consultar(`SELECT c.id, c.nombre, c.activa, c.created_at,
              COUNT(DISTINCT i.id) FILTER (WHERE i.activa) AS impresoras,
              COUNT(DISTINCT p.id) AS productos
       FROM cocinas c
       LEFT JOIN impresoras i ON i.cocina_id = c.id
       LEFT JOIN productos p ON p.cocina_id = c.id
       WHERE c.sucursal_id = $1
       GROUP BY c.id
       ORDER BY c.nombre ASC`, [sucursalId]);
    }
    async listarCocinasParaKds(usuario) {
        const sucursalId = usuario.sucursal_id;
        if (!sucursalId) {
            throw new common_1.BadRequestException('Sin sucursal en sesión');
        }
        const todas = await this.listarCocinas(sucursalId);
        if (!(0, roles_food_1.esRolCocina)(usuario.rol)) {
            return todas;
        }
        const cocinaId = await this.cocinaAsignadaUsuario(usuario);
        if (!cocinaId) {
            throw new common_1.ForbiddenException('Tu usuario de cocina no tiene estación asignada. Pide al admin que te asigne una.');
        }
        return todas.filter((c) => c.id === cocinaId);
    }
    async exigirAccesoCocinaKds(usuario, cocinaId) {
        const sucursalId = usuario.sucursal_id;
        if (!sucursalId) {
            throw new common_1.BadRequestException('Sin sucursal en sesión');
        }
        await this.exigirCocina(cocinaId, sucursalId);
        if (!(0, roles_food_1.esRolCocina)(usuario.rol))
            return;
        const asignada = await this.cocinaAsignadaUsuario(usuario);
        if (asignada !== cocinaId) {
            throw new common_1.ForbiddenException('No puedes operar otra cocina distinta a la tuya');
        }
    }
    async exigirAccesoItemKds(usuario, itemId) {
        if (!(0, roles_food_1.esRolCocina)(usuario.rol))
            return;
        const sucursalId = usuario.sucursal_id;
        if (!sucursalId) {
            throw new common_1.BadRequestException('Sin sucursal en sesión');
        }
        const item = await this.database.consultarUno(`SELECT pi.cocina_id
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       WHERE pi.id = $1 AND p.sucursal_id = $2`, [itemId, sucursalId]);
        if (!item) {
            throw new common_1.NotFoundException('Ítem de pedido no encontrado');
        }
        if (!item.cocina_id) {
            throw new common_1.ForbiddenException('Ítem sin cocina asignada');
        }
        await this.exigirAccesoCocinaKds(usuario, item.cocina_id);
    }
    async cocinaAsignadaUsuario(usuario) {
        if (usuario.cocina_id)
            return usuario.cocina_id;
        const fila = await this.database.consultarUno(`SELECT cocina_id FROM usuarios WHERE id = $1`, [usuario.sub]);
        return fila?.cocina_id ?? null;
    }
    crearCocina(dto) {
        return this.database.consultarUno(`INSERT INTO cocinas (sucursal_id, nombre, activa)
       VALUES ($1, $2, true)
       RETURNING id, nombre, activa`, [dto.sucursal_id, dto.nombre.trim()]);
    }
    async actualizarCocina(id, sucursalId, dto) {
        await this.exigirCocina(id, sucursalId);
        if (dto.activa === false) {
            await this.exigirCocinaSinOperacionPendiente(id, sucursalId);
        }
        const campos = [];
        const valores = [];
        let i = 1;
        if (dto.nombre !== undefined) {
            campos.push(`nombre = $${i++}`);
            valores.push(dto.nombre.trim());
        }
        if (dto.activa !== undefined) {
            campos.push(`activa = $${i++}`);
            valores.push(dto.activa);
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        await this.database.consultar(`UPDATE cocinas SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
        return { id };
    }
    async eliminarCocina(id, sucursalId) {
        await this.exigirCocina(id, sucursalId);
        await this.exigirCocinaSinOperacionPendiente(id, sucursalId);
        await this.database.consultar(`UPDATE cocinas SET activa = false WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        return { id, activa: false };
    }
    listarImpresoras(sucursalId, cocinaId) {
        const params = [sucursalId];
        let filtro = '';
        if (cocinaId) {
            params.push(cocinaId);
            filtro = `AND i.cocina_id = $2`;
        }
        return this.database.consultar(`SELECT i.id, i.nombre, i.ip_local, i.tipo, i.activa, i.cocina_id,
              c.nombre AS cocina_nombre, i.created_at
       FROM impresoras i
       LEFT JOIN cocinas c ON c.id = i.cocina_id
       WHERE i.sucursal_id = $1 ${filtro}
       ORDER BY i.nombre ASC`, params);
    }
    async crearImpresora(dto) {
        await this.exigirCocina(dto.cocina_id, dto.sucursal_id);
        return this.database.consultarUno(`INSERT INTO impresoras (sucursal_id, cocina_id, nombre, ip_local, tipo, activa)
       VALUES ($1, $2, $3, $4, $5, true)
       RETURNING id, nombre, ip_local, tipo, activa, cocina_id`, [
            dto.sucursal_id,
            dto.cocina_id,
            dto.nombre.trim(),
            dto.ip_local ?? null,
            dto.tipo ?? 'termica_red',
        ]);
    }
    async actualizarImpresora(id, sucursalId, dto) {
        await this.exigirImpresora(id, sucursalId);
        if (dto.cocina_id !== undefined) {
            await this.exigirCocina(dto.cocina_id, sucursalId);
        }
        const campos = [];
        const valores = [];
        let i = 1;
        const mapa = [
            ['nombre', 'nombre'],
            ['cocina_id', 'cocina_id'],
            ['ip_local', 'ip_local'],
            ['tipo', 'tipo'],
            ['activa', 'activa'],
        ];
        for (const [key, col] of mapa) {
            const v = dto[key];
            if (v !== undefined) {
                campos.push(`${col} = $${i++}`);
                valores.push(typeof v === 'string' ? v.trim() : v);
            }
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        await this.database.consultar(`UPDATE impresoras SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
        return { id };
    }
    async eliminarImpresora(id, sucursalId) {
        await this.exigirImpresora(id, sucursalId);
        await this.database.consultar(`UPDATE impresoras SET activa = false WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        return { id, activa: false };
    }
    async listarTickets(cocinaId, sucursalId) {
        await this.exigirCocina(cocinaId, sucursalId);
        return this.database.consultar(`SELECT p.id AS pedido_id, p.numero_pedido, p.tipo, p.estado,
              p.mesa_id, m.nombre AS mesa_nombre, p.cliente_nombre,
              p.observaciones, p.created_at,
              MIN(pi.created_at) AS cocina_desde,
              COALESCE(
                json_agg(
                  json_build_object(
                    'item_id', pi.id,
                    'producto', pr.nombre,
                    'cantidad', pi.cantidad,
                    'observaciones', pi.observaciones,
                    'estado_cocina', pi.estado_cocina,
                    'created_at', pi.created_at,
                    'incluidos', COALESCE(
                      (
                        SELECT json_agg(
                          json_build_object(
                            'nombre', pr2.nombre,
                            'cantidad', pii.cantidad * pi.cantidad
                          ) ORDER BY pr2.nombre
                        )
                        FROM producto_items_incluidos pii
                        INNER JOIN productos pr2 ON pr2.id = pii.producto_incluido_id
                        WHERE pii.producto_id = pi.producto_id
                          AND pii.sucursal_id = p.sucursal_id
                      ),
                      '[]'::json
                    ),
                    'combo_componentes', COALESCE(
                      (
                        SELECT json_agg(
                          json_build_object(
                            'nombre', componente.value->>'nombre',
                            'cantidad',
                              (componente.value->>'cantidad')::numeric * pi.cantidad
                          ) ORDER BY componente.value->>'nombre'
                        )
                        FROM pedido_combo_selecciones pcs
                        CROSS JOIN LATERAL jsonb_array_elements(
                          pcs.componentes_snapshot
                        ) AS componente(value)
                        WHERE pcs.pedido_item_id = pi.id
                          AND componente.value->>'item_id' <> pi.producto_id::text
                      ),
                      '[]'::json
                    )
                  ) ORDER BY pi.created_at
                ) FILTER (WHERE pi.id IS NOT NULL),
                '[]'
              ) AS items
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       JOIN pedido_items pi ON pi.pedido_id = p.id AND pi.cocina_id = $1
       LEFT JOIN productos pr ON pr.id = pi.producto_id
       WHERE p.sucursal_id = $2
         AND (
           p.estado IN ('confirmado', 'en_cocina', 'listo', 'pagando')
           OR (
             p.estado = 'pagado'
             AND EXISTS (
               SELECT 1 FROM pedido_items pi_pend
               WHERE pi_pend.pedido_id = p.id
                 AND pi_pend.cocina_id = $1
                 AND (
                   pi_pend.estado_cocina IS NULL
                   OR pi_pend.estado_cocina NOT IN ('listo', 'no_disponible')
                 )
             )
           )
         )
       GROUP BY p.id, m.nombre
       ORDER BY p.created_at ASC`, [cocinaId, sucursalId]);
    }
    async cambiarEstadoItem(itemId, sucursalId, estado, usuarioId, motivo, opciones) {
        if (estado === 'no_disponible' && !motivo?.trim()) {
            throw new common_1.BadRequestException({
                error: 'FALLO_PREPARACION_MOTIVO',
                message: 'Indica el motivo del fallo de preparación (obligatorio).',
            });
        }
        const result = await this.database.enTransaccion(async (client) => {
            let catalogoOffProductoId = null;
            const item = await client.query(`SELECT pi.pedido_id, p.estado, p.tipo, pi.cocina_id, p.numero_pedido,
                p.total::text AS total,
                COALESCE(p.monto_pagado, 0)::text AS monto_pagado,
                pi.producto_id, pi.cantidad,
                COALESCE(p.stock_descontado, false) AS stock_descontado,
                pr.nombre AS nombre_producto,
                pi.estado_cocina
         FROM pedido_items pi
         JOIN pedidos p ON p.id = pi.pedido_id
         JOIN productos pr ON pr.id = pi.producto_id
         WHERE pi.id = $1 AND p.sucursal_id = $2
         FOR UPDATE OF p`, [itemId, sucursalId]);
            if (!item.rows[0]) {
                throw new common_1.NotFoundException('Ítem de pedido no encontrado');
            }
            const fila = item.rows[0];
            const pedidoId = fila.pedido_id;
            const estadoPedidoActual = fila.estado;
            const estadoCocinaAnterior = fila.estado_cocina;
            const puedeCompletarPedidoPagado = (0, pedido_estados_1.puedeAvanzarCocinaPedidoPagado)({
                estadoPedido: estadoPedidoActual,
                total: fila.total,
                montoPagado: fila.monto_pagado,
                estadoItem: estadoCocinaAnterior,
                nuevoEstadoItem: estado,
            });
            if (pedido_estados_1.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(estadoPedidoActual) &&
                !puedeCompletarPedidoPagado) {
                throw new common_1.ConflictException({
                    error: 'PEDIDO_COCINA_CERRADO',
                    message: 'No puedes cambiar ítems de Cocina cuando el pedido está en cobro, despacho o un estado terminal.',
                });
            }
            await client.query(`UPDATE pedido_items SET estado_cocina = $1 WHERE id = $2`, [estado, itemId]);
            if (estado === 'no_disponible' &&
                estadoCocinaAnterior !== 'no_disponible') {
                const descMotivo = motivo.trim();
                await this.alertasRiesgo.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: opciones?.falloPreparacion
                        ? 'fallo_preparacion'
                        : 'item_no_disponible_cocina',
                    nivel: 'alto',
                    descripcion: opciones?.falloPreparacion
                        ? `${fila.numero_pedido}: fallo de preparación «${fila.nombre_producto}». Motivo: ${descMotivo}`
                        : descMotivo ||
                            `Cocina marcó ítem no disponible (pedido ${fila.numero_pedido})`,
                    referenciaId: pedidoId,
                    referenciaTipo: 'pedido',
                    deduplicar: false,
                });
                if (fila.stock_descontado) {
                    await this.pedidosInventario.registrarMermaLineaProducto(client, sucursalId, pedidoId, fila.producto_id, fila.cantidad, descMotivo || `Fallo preparación (${fila.nombre_producto})`);
                }
                await client.query(`INSERT INTO impresion_cocina_jobs (sucursal_id, cocina_id, pedido_id, payload)
           VALUES ($1, $2, $3, $4::jsonb)`, [
                    sucursalId,
                    fila.cocina_id,
                    pedidoId,
                    JSON.stringify({
                        accion: opciones?.falloPreparacion
                            ? 'fallo_preparacion'
                            : 'item_no_disponible',
                        item_id: itemId,
                        motivo: descMotivo,
                    }),
                ]);
                const off = await client.query(`UPDATE productos
           SET disponible = false
           WHERE id = $1 AND sucursal_id = $2
             AND disponible IS DISTINCT FROM false
           RETURNING id`, [fila.producto_id, sucursalId]);
                if (off.rows[0]) {
                    catalogoOffProductoId = fila.producto_id;
                }
            }
            const conteo = await client.query(`SELECT
           COUNT(*) FILTER (
             WHERE estado_cocina IS NULL
                OR estado_cocina NOT IN ('listo', 'no_disponible')
           ) AS pendientes,
           COUNT(*) FILTER (
             WHERE estado_cocina IN ('preparando', 'listo')
           ) AS en_proceso
         FROM pedido_items WHERE pedido_id = $1`, [pedidoId]);
            const { pendientes, en_proceso } = conteo.rows[0];
            let nuevoEstadoPedido = estadoPedidoActual;
            if (puedeCompletarPedidoPagado) {
                nuevoEstadoPedido = 'pagado';
            }
            else if (Number(pendientes) === 0) {
                nuevoEstadoPedido = 'listo';
            }
            else if (Number(en_proceso) > 0) {
                nuevoEstadoPedido = 'en_cocina';
            }
            else {
                nuevoEstadoPedido = 'en_cocina';
            }
            if (pedido_estados_1.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(estadoPedidoActual)) {
                nuevoEstadoPedido = estadoPedidoActual;
            }
            if (nuevoEstadoPedido !== estadoPedidoActual) {
                await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                    pedidoId,
                    sucursalId,
                    nuevoEstado: nuevoEstadoPedido,
                    origen: 'cocina',
                    usuarioId,
                    estadoAnterior: estadoPedidoActual,
                    tipo: item.rows[0].tipo,
                });
            }
            if (nuevoEstadoPedido === 'listo' &&
                !pedido_estados_1.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(estadoPedidoActual) &&
                (0, pedido_estados_1.pedidoCobradoCompletamente)(Number(item.rows[0].total), item.rows[0].monto_pagado)) {
                await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                    pedidoId,
                    sucursalId,
                    nuevoEstado: 'pagado',
                    origen: 'sistema',
                    usuarioId,
                    motivo: 'Cocina lista — pedido ya cobrado (prepago)',
                    estadoAnterior: 'listo',
                    tipo: item.rows[0].tipo,
                });
                nuevoEstadoPedido = 'pagado';
            }
            return {
                item_id: itemId,
                estado_cocina: estado,
                pedido_id: pedidoId,
                estado_pedido: nuevoEstadoPedido,
                estado_pedido_anterior: estadoPedidoActual,
                tipo_pedido: item.rows[0].tipo,
                cocina_id: item.rows[0].cocina_id,
                numero_pedido: item.rows[0].numero_pedido,
                sucursal_id: sucursalId,
                catalogo_off_producto_id: catalogoOffProductoId,
            };
        });
        if (result.catalogo_off_producto_id) {
            void this.menuCache.invalidar(result.sucursal_id);
            this.pedidosSoporte.notificarCatalogoDisponibilidad(result.sucursal_id, [
                {
                    producto_id: result.catalogo_off_producto_id,
                    disponible: false,
                },
            ]);
        }
        if (result.cocina_id) {
            void this.realtime.cocinaActualizada(result.cocina_id, {
                pedido_id: result.pedido_id,
                item_id: result.item_id,
                sucursal_id: result.sucursal_id,
                accion: 'item_estado',
            });
        }
        if (result.estado_pedido !== result.estado_pedido_anterior) {
            void this.realtime.pedidoActualizado({
                pedido_id: result.pedido_id,
                sucursal_id: result.sucursal_id,
                estado: result.estado_pedido,
                numero_pedido: result.numero_pedido,
            });
            this.pedidosSoporte.emitirSeguimientoPedido(result.pedido_id, {
                pedido_id: result.pedido_id,
                estado: result.estado_pedido,
            });
        }
        await this.intentarDispatchDomicilioSiListo(result.pedido_id, result.sucursal_id, result.tipo_pedido, result.estado_pedido, result.estado_pedido_anterior);
        const { estado_pedido_anterior: _, tipo_pedido: __, ...respuesta } = result;
        return respuesta;
    }
    async falloPreparacion(itemId, sucursalId, usuarioId, motivo) {
        return this.cambiarEstadoItem(itemId, sucursalId, 'no_disponible', usuarioId, motivo, { falloPreparacion: true });
    }
    async intentarDispatchDomicilioSiListo(pedidoId, sucursalId, tipo, estadoNuevo, estadoAnterior) {
        if (tipo !== 'domicilio' ||
            estadoNuevo !== 'listo' ||
            estadoAnterior === 'listo') {
            return;
        }
        try {
            const dispatchResult = await this.dispatch.intentarDispatchAutomatico(pedidoId, sucursalId);
            const asignado = dispatchResult.iniciado &&
                (dispatchResult.motivo === 'planta_asignada_auto' ||
                    dispatchResult.motivo === 'ya_asignado');
            if (!asignado) {
                const detalle = dispatchResult.mensaje ??
                    'No hubo asignación automática. Revisa el panel de domiciliarios.';
                void this.alertasRiesgo.registrar({
                    sucursalId,
                    tipo: 'domicilio_listo_sin_asignar',
                    nivel: 'medio',
                    descripcion: `Pedido ${pedidoId}: ${detalle}`,
                    referenciaId: pedidoId,
                    referenciaTipo: 'pedido',
                    deduplicar: true,
                });
            }
        }
        catch {
        }
    }
    async actualizarObservacionesItem(itemId, sucursalId, observaciones) {
        const res = await this.database.consultarUno(`UPDATE pedido_items pi
       SET observaciones = $3
       FROM pedidos p
       WHERE pi.id = $1 AND pi.pedido_id = p.id AND p.sucursal_id = $2
       RETURNING pi.id, pi.cocina_id, pi.pedido_id`, [itemId, sucursalId, observaciones.trim()]);
        if (!res)
            throw new common_1.NotFoundException('Ítem no encontrado');
        if (res.cocina_id) {
            void this.realtime.cocinaActualizada(res.cocina_id, {
                pedido_id: res.pedido_id,
                item_id: itemId,
                accion: 'observaciones',
            });
        }
        return { item_id: itemId, observaciones: observaciones.trim() };
    }
    async marcarPrioridadItem(itemId, sucursalId, urgente) {
        const obs = urgente ? '[URGENTE] ' : '';
        const item = await this.database.consultarUno(`SELECT pi.observaciones FROM pedido_items pi
       INNER JOIN pedidos p ON p.id = pi.pedido_id
       WHERE pi.id = $1 AND p.sucursal_id = $2`, [itemId, sucursalId]);
        if (!item)
            throw new common_1.NotFoundException('Ítem no encontrado');
        const base = (item.observaciones ?? '').replace(/^\[URGENTE\]\s*/, '');
        return this.actualizarObservacionesItem(itemId, sucursalId, urgente ? `${obs}${base}`.trim() : base.trim());
    }
    async exigirCocina(id, sucursalId) {
        const c = await this.database.consultarUno(`SELECT id FROM cocinas WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!c)
            throw new common_1.NotFoundException('Cocina no encontrada');
    }
    async exigirCocinaSinOperacionPendiente(id, sucursalId) {
        const uso = await this.database.consultarUno(`SELECT
         (SELECT COUNT(*) FROM productos
          WHERE cocina_id = $1 AND sucursal_id = $2 AND disponible = true)
           AS productos_disponibles,
         (SELECT COUNT(*)
          FROM pedido_items pi
          JOIN pedidos p ON p.id = pi.pedido_id
          WHERE pi.cocina_id = $1
            AND p.sucursal_id = $2
            AND (
              p.estado IN ('confirmado', 'en_cocina', 'listo', 'pagando')
              OR (p.estado = 'pagado' AND (
                pi.estado_cocina IS NULL
                OR pi.estado_cocina NOT IN ('listo', 'no_disponible')
              ))
            )
            AND (pi.estado_cocina IS NULL
              OR pi.estado_cocina NOT IN ('listo', 'no_disponible')))
           AS items_pendientes`, [id, sucursalId]);
        if (Number(uso?.productos_disponibles ?? 0) > 0 ||
            Number(uso?.items_pendientes ?? 0) > 0) {
            throw new common_1.BadRequestException('No puedes desactivar una cocina con productos disponibles o pedidos pendientes. Reasigna los productos y termina los pedidos primero.');
        }
    }
    async exigirImpresora(id, sucursalId) {
        const i = await this.database.consultarUno(`SELECT id FROM impresoras WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!i)
            throw new common_1.NotFoundException('Impresora no encontrada');
    }
};
exports.CocinasService = CocinasService;
exports.CocinasService = CocinasService = __decorate([
    (0, common_1.Injectable)(),
    __param(6, (0, common_1.Inject)((0, common_1.forwardRef)(() => pedidos_soporte_service_1.PedidosSoporteService))),
    __param(7, (0, common_1.Inject)((0, common_1.forwardRef)(() => pedidos_inventario_service_1.PedidosInventarioService))),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        menu_cache_service_1.MenuCacheService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        dispatch_service_1.DispatchService,
        pedidos_estado_command_service_1.PedidosEstadoCommandService,
        pedidos_soporte_service_1.PedidosSoporteService,
        pedidos_inventario_service_1.PedidosInventarioService])
], CocinasService);
//# sourceMappingURL=cocinas.service.js.map