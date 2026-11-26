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
    async exigirAccesoTareaComboKds(usuario, tareaId) {
        const sucursalId = usuario.sucursal_id;
        if (!sucursalId)
            throw new common_1.BadRequestException('Sin sucursal en sesión');
        const tarea = await this.database.consultarUno(`SELECT cocina_id
       FROM pedido_combo_tareas_cocina
       WHERE id = $1 AND sucursal_id = $2`, [tareaId, sucursalId]);
        if (!tarea)
            throw new common_1.NotFoundException('Tarea de combo no encontrada');
        await this.exigirAccesoCocinaKds(usuario, tarea.cocina_id);
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
        return this.database.consultar(`WITH items_kds AS (
         SELECT pi.pedido_id, pi.id AS pedido_item_id, pi.id AS item_id,
                NULL::uuid AS tarea_combo_id, pi.created_at,
                pr.nombre AS producto, pi.cantidad, pi.observaciones,
                COALESCE(pi.estado_cocina, 'pendiente') AS estado_cocina,
                NULL::text AS producto_padre,
                COALESCE(
                  (SELECT json_agg(json_build_object(
                     'nombre', pr2.nombre,
                     'cantidad', pii.cantidad * pi.cantidad
                   ) ORDER BY pr2.nombre)
                   FROM producto_items_incluidos pii
                   INNER JOIN productos pr2 ON pr2.id = pii.producto_incluido_id
                   WHERE pii.producto_id = pi.producto_id
                     AND pii.sucursal_id = $2),
                  '[]'::json
                ) AS incluidos,
                COALESCE(
                  (SELECT json_agg(json_build_object(
                     'nombre', componente.value->>'nombre',
                     'cantidad', (componente.value->>'cantidad')::numeric * pi.cantidad
                   ) ORDER BY componente.value->>'nombre')
                   FROM pedido_combo_selecciones pcs
                   CROSS JOIN LATERAL jsonb_array_elements(pcs.componentes_snapshot) AS componente(value)
                   WHERE pcs.pedido_item_id = pi.id
                     AND componente.value->>'item_id' <> pi.producto_id::text),
                  '[]'::json
                ) AS combo_componentes
         FROM pedido_items pi
         INNER JOIN pedidos p ON p.id = pi.pedido_id
         LEFT JOIN productos pr ON pr.id = pi.producto_id
         WHERE p.sucursal_id = $2 AND pi.cocina_id = $1
           AND NOT EXISTS (
             SELECT 1 FROM pedido_combo_tareas_cocina t
             WHERE t.pedido_item_id = pi.id
           )

         UNION ALL

         SELECT pi.pedido_id, pi.id AS pedido_item_id, t.id AS item_id,
                t.id AS tarea_combo_id, t.created_at,
                t.nombre_snapshot AS producto, t.cantidad,
                CASE
                  WHEN t.producto_padre_nombre_snapshot IS NOT NULL
                    THEN 'Para: ' || t.producto_padre_nombre_snapshot
                  ELSE t.motivo_no_disponible
                END AS observaciones,
                t.estado AS estado_cocina,
                t.producto_padre_nombre_snapshot AS producto_padre,
                '[]'::json AS incluidos,
                '[]'::json AS combo_componentes
         FROM pedido_combo_tareas_cocina t
         INNER JOIN pedido_items pi ON pi.id = t.pedido_item_id
         INNER JOIN pedidos p ON p.id = pi.pedido_id
         WHERE t.sucursal_id = $2 AND t.cocina_id = $1
           AND t.estado <> 'cancelada'
       )
       SELECT p.id AS pedido_id, $1::uuid AS cocina_id,
              p.numero_pedido, p.tipo, p.estado,
              p.mesa_id, m.nombre AS mesa_nombre, p.cliente_nombre,
              p.observaciones, p.created_at,
              MIN(i.created_at) AS cocina_desde,
              COALESCE(
                json_agg(
                  json_build_object(
                    'item_id', i.item_id,
                    'pedido_item_id', i.pedido_item_id,
                    'tarea_combo_id', i.tarea_combo_id,
                    'producto', i.producto,
                    'cantidad', i.cantidad,
                    'observaciones', i.observaciones,
                    'estado_cocina', i.estado_cocina,
                    'producto_padre', i.producto_padre,
                    'created_at', i.created_at,
                    'incluidos', i.incluidos,
                    'combo_componentes', i.combo_componentes
                  ) ORDER BY i.created_at
                ) FILTER (WHERE i.item_id IS NOT NULL),
                '[]'
              ) AS items
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       JOIN items_kds i ON i.pedido_id = p.id
       WHERE p.sucursal_id = $2
         AND (
           p.estado IN ('confirmado', 'en_cocina', 'listo', 'pagando')
           OR (
             p.estado = 'pagado'
             AND (
               EXISTS (
                 SELECT 1 FROM items_kds i_pend
                 WHERE i_pend.pedido_id = p.id
                   AND i_pend.estado_cocina NOT IN ('listo', 'no_disponible', 'cancelada')
               )
               OR EXISTS (
                 SELECT 1 FROM pedido_combo_decisiones_cliente d
                 JOIN pedido_items pi_d ON pi_d.id = d.pedido_item_id
                 WHERE pi_d.pedido_id = p.id AND d.estado = 'pendiente_cliente'
               )
             )
           )
         )
       GROUP BY p.id, m.nombre
       ORDER BY p.created_at ASC`, [cocinaId, sucursalId]);
    }
    async cambiarEstadoTareaCombo(tareaId, sucursalId, estado, usuarioId) {
        if (estado === 'no_disponible') {
            throw new common_1.ConflictException({
                error: 'COMBO_REQUIERE_DECISION_CLIENTE',
                message: 'La falta de un componente requiere pausar el combo y registrar la decisión del cliente.',
            });
        }
        const result = await this.database.enTransaccion(async (client) => {
            const locked = await client.query(`SELECT t.id AS tarea_id, t.pedido_item_id, p.id AS pedido_id,
                t.cocina_id, p.numero_pedido, p.tipo,
                p.estado AS estado_pedido, t.estado AS estado_tarea,
                pi.estado_cocina AS estado_linea, p.total::text AS total,
                COALESCE(p.monto_pagado, 0)::text AS monto_pagado
         FROM pedido_combo_tareas_cocina t
         JOIN pedido_items pi ON pi.id = t.pedido_item_id
         JOIN pedidos p ON p.id = pi.pedido_id
         WHERE t.id = $1 AND t.sucursal_id = $2 AND p.sucursal_id = $2
         FOR UPDATE OF p, pi, t`, [tareaId, sucursalId]);
            const fila = locked.rows[0];
            if (!fila)
                throw new common_1.NotFoundException('Tarea de combo no encontrada');
            if (fila.estado_tarea === 'pausada_decision_cliente') {
                throw new common_1.ConflictException({
                    error: 'COMBO_PAUSADO_POR_DECISION',
                    message: 'Esta tarea está pausada hasta recibir respuesta del cliente.',
                });
            }
            if (fila.estado_tarea === 'cancelada') {
                throw new common_1.ConflictException('La tarea del combo fue cancelada');
            }
            const puedeCompletarPagado = (0, pedido_estados_1.puedeAvanzarCocinaPedidoPagado)({
                estadoPedido: fila.estado_pedido,
                total: fila.total,
                montoPagado: fila.monto_pagado,
                estadoItem: fila.estado_linea,
                nuevoEstadoItem: estado,
            });
            if (pedido_estados_1.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(fila.estado_pedido) &&
                !puedeCompletarPagado) {
                throw new common_1.ConflictException({
                    error: 'PEDIDO_COCINA_CERRADO',
                    message: 'No puedes cambiar tareas de cocina cuando el pedido está en cobro, despacho o un estado terminal.',
                });
            }
            if (fila.estado_tarea !== estado) {
                await client.query(`UPDATE pedido_combo_tareas_cocina
           SET estado = $1, updated_at = now()
           WHERE id = $2 AND sucursal_id = $3`, [estado, tareaId, sucursalId]);
            }
            const agregado = await client.query(`SELECT CASE
           WHEN COUNT(*) FILTER (WHERE estado NOT IN ('listo', 'cancelada')) = 0 THEN 'listo'
           WHEN COUNT(*) FILTER (WHERE estado IN ('preparando', 'listo')) > 0 THEN 'preparando'
           ELSE 'pendiente'
         END AS estado
         FROM pedido_combo_tareas_cocina
         WHERE pedido_item_id = $1 AND sucursal_id = $2`, [fila.pedido_item_id, sucursalId]);
            const estadoLineaNuevo = agregado.rows[0].estado;
            await client.query(`UPDATE pedido_items SET estado_cocina = $1 WHERE id = $2`, [estadoLineaNuevo, fila.pedido_item_id]);
            const conteo = await client.query(`SELECT COUNT(*) FILTER (
                  WHERE estado_cocina IS NULL
                     OR estado_cocina NOT IN ('listo', 'no_disponible')
                ) AS pendientes,
                COUNT(*) FILTER (
                  WHERE estado_cocina IN ('preparando', 'listo')
                ) AS en_proceso
         FROM pedido_items WHERE pedido_id = $1`, [fila.pedido_id]);
            let estadoPedidoNuevo = fila.estado_pedido;
            if (puedeCompletarPagado) {
                estadoPedidoNuevo = 'pagado';
            }
            else if (pedido_estados_1.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(fila.estado_pedido)) {
                throw new common_1.ConflictException('El pedido ya no admite cambios de cocina');
            }
            else if (Number(conteo.rows[0].pendientes) === 0) {
                estadoPedidoNuevo = 'listo';
            }
            else {
                estadoPedidoNuevo = 'en_cocina';
            }
            if (estadoPedidoNuevo !== fila.estado_pedido) {
                await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                    pedidoId: fila.pedido_id,
                    sucursalId,
                    nuevoEstado: estadoPedidoNuevo,
                    origen: 'cocina',
                    usuarioId,
                    estadoAnterior: fila.estado_pedido,
                    tipo: fila.tipo,
                });
            }
            if (estadoPedidoNuevo === 'listo' &&
                (0, pedido_estados_1.pedidoCobradoCompletamente)(Number(fila.total), fila.monto_pagado)) {
                await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                    pedidoId: fila.pedido_id,
                    sucursalId,
                    nuevoEstado: 'pagado',
                    origen: 'sistema',
                    usuarioId,
                    motivo: 'Cocina lista — pedido ya cobrado (prepago)',
                    estadoAnterior: 'listo',
                    tipo: fila.tipo,
                });
                estadoPedidoNuevo = 'pagado';
            }
            return {
                tarea_id: tareaId,
                pedido_item_id: fila.pedido_item_id,
                estado_cocina: estado,
                estado_linea: estadoLineaNuevo,
                pedido_id: fila.pedido_id,
                estado_pedido: estadoPedidoNuevo,
                estado_pedido_anterior: fila.estado_pedido,
                tipo_pedido: fila.tipo,
                cocina_id: fila.cocina_id,
                numero_pedido: fila.numero_pedido,
                sucursal_id: sucursalId,
            };
        });
        void this.realtime.cocinaActualizada(result.cocina_id, {
            pedido_id: result.pedido_id,
            item_id: result.pedido_item_id,
            tarea_combo_id: result.tarea_id,
            sucursal_id: sucursalId,
            accion: 'combo_tarea_estado',
        });
        if (result.estado_pedido !== result.estado_pedido_anterior) {
            void this.realtime.pedidoActualizado({
                pedido_id: result.pedido_id,
                sucursal_id: sucursalId,
                estado: result.estado_pedido,
                numero_pedido: result.numero_pedido,
            });
            this.pedidosSoporte.emitirSeguimientoPedido(result.pedido_id, {
                pedido_id: result.pedido_id,
                estado: result.estado_pedido,
            });
        }
        await this.intentarDispatchDomicilioSiListo(result.pedido_id, sucursalId, result.tipo_pedido, result.estado_pedido, result.estado_pedido_anterior);
        const { estado_pedido_anterior: _, tipo_pedido: __, ...respuesta } = result;
        return respuesta;
    }
    async marcarTareaComboNoDisponible(tareaId, sucursalId, usuarioId, motivo) {
        const descMotivo = motivo.trim();
        if (!descMotivo) {
            throw new common_1.BadRequestException({
                error: 'COMBO_NODISP_MOTIVO',
                message: 'Indica por qué no está disponible el componente.',
            });
        }
        const result = await this.database.enTransaccion(async (client) => {
            const locked = await client.query(`SELECT t.id AS tarea_id, t.pedido_item_id, p.id AS pedido_id,
                p.numero_pedido, p.estado AS estado_pedido,
                t.cocina_id, t.estado AS estado_tarea,
                pi.estado_cocina AS estado_linea, t.tipo_item,
                t.componente_id, t.nombre_snapshot, t.cantidad::text,
                t.precio_unitario_snapshot::text,
                t.costo_unitario_snapshot::text, t.producto_padre_id,
                t.producto_padre_nombre_snapshot, t.componente_indice,
                p.total::text AS total,
                COALESCE(p.monto_pagado, 0)::text AS monto_pagado
         FROM pedido_combo_tareas_cocina t
         JOIN pedido_items pi ON pi.id = t.pedido_item_id
         JOIN pedidos p ON p.id = pi.pedido_id
         WHERE t.id = $1 AND t.sucursal_id = $2 AND p.sucursal_id = $2
         FOR UPDATE OF p, pi, t`, [tareaId, sucursalId]);
            const fila = locked.rows[0];
            if (!fila)
                throw new common_1.NotFoundException('Tarea de combo no encontrada');
            const decisionExistente = await client.query(`SELECT id, tarea_no_disponible_id
         FROM pedido_combo_decisiones_cliente
         WHERE pedido_item_id = $1 AND sucursal_id = $2
           AND estado = 'pendiente_cliente'
         FOR UPDATE`, [fila.pedido_item_id, sucursalId]);
            const pendiente = decisionExistente.rows[0];
            if (pendiente) {
                if (pendiente.tarea_no_disponible_id === tareaId &&
                    fila.estado_tarea === 'no_disponible') {
                    return {
                        pedido_id: fila.pedido_id,
                        numero_pedido: fila.numero_pedido,
                        estado_pedido: fila.estado_pedido,
                        pedido_item_id: fila.pedido_item_id,
                        tarea_id: tareaId,
                        decision_id: pendiente.id,
                        cocina_ids: [fila.cocina_id],
                        idempotente: true,
                    };
                }
                throw new common_1.ConflictException({
                    error: 'COMBO_DECISION_PENDIENTE',
                    message: 'Este combo ya espera una respuesta del cliente.',
                });
            }
            if (['listo', 'no_disponible', 'cancelada'].includes(fila.estado_tarea)) {
                throw new common_1.ConflictException({
                    error: 'COMBO_TAREA_TERMINAL',
                    message: 'La tarea ya fue finalizada o resuelta.',
                });
            }
            const puedeCompletarPagado = (0, pedido_estados_1.puedeAvanzarCocinaPedidoPagado)({
                estadoPedido: fila.estado_pedido,
                total: fila.total,
                montoPagado: fila.monto_pagado,
                estadoItem: fila.estado_linea,
                nuevoEstadoItem: 'no_disponible',
            });
            if (pedido_estados_1.ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA.has(fila.estado_pedido) &&
                !puedeCompletarPagado) {
                throw new common_1.ConflictException({
                    error: 'PEDIDO_COCINA_CERRADO',
                    message: 'No puedes reportar una novedad de cocina cuando el pedido está en despacho o en estado terminal.',
                });
            }
            await client.query(`UPDATE pedido_combo_tareas_cocina
         SET estado = CASE WHEN id = $1 THEN 'no_disponible'
                            ELSE 'pausada_decision_cliente' END,
             estado_antes_pausa = CASE WHEN id = $1 THEN estado_antes_pausa
                                       ELSE estado END,
             motivo_no_disponible = CASE WHEN id = $1 THEN $3
                                         ELSE motivo_no_disponible END,
             updated_at = now()
         WHERE pedido_item_id = $2 AND sucursal_id = $4
           AND estado IN ('pendiente', 'preparando')`, [tareaId, fila.pedido_item_id, descMotivo, sucursalId]);
            const decision = await client.query(`INSERT INTO pedido_combo_decisiones_cliente (
           pedido_id, pedido_item_id, pedido_item_id_original,
           tarea_no_disponible_id, tarea_id_original, sucursal_id,
           componente_anterior_snapshot, usuario_id
         )
         VALUES (
           $1, $2, $2, $3, $3, $4,
           jsonb_build_object(
             'tarea_id', $3::uuid::text,
             'tipo_item', $5::text,
             'componente_id', $6::uuid::text,
             'nombre', $7::text,
             'cantidad', $8::numeric,
             'precio_unitario', $9::numeric,
             'costo_unitario', $10::numeric,
             'producto_padre_id', $11::uuid::text,
             'producto_padre', $12::text,
             'cocina_id', $13::uuid::text,
             'componente_indice', $14::integer,
             'motivo_no_disponible', $15::text
           ), $16
         )
         RETURNING id`, [
                fila.pedido_id,
                fila.pedido_item_id,
                tareaId,
                sucursalId,
                fila.tipo_item,
                fila.componente_id,
                fila.nombre_snapshot,
                fila.cantidad,
                fila.precio_unitario_snapshot,
                fila.costo_unitario_snapshot,
                fila.producto_padre_id,
                fila.producto_padre_nombre_snapshot,
                fila.cocina_id,
                fila.componente_indice,
                descMotivo,
                usuarioId,
            ]);
            const agregado = await client.query(`SELECT CASE
           WHEN COUNT(*) FILTER (WHERE estado IN ('preparando', 'listo')) > 0 THEN 'preparando'
           ELSE 'pendiente'
         END AS estado
         FROM pedido_combo_tareas_cocina
         WHERE pedido_item_id = $1 AND sucursal_id = $2`, [fila.pedido_item_id, sucursalId]);
            await client.query(`UPDATE pedido_items SET estado_cocina = $1 WHERE id = $2`, [agregado.rows[0].estado, fila.pedido_item_id]);
            const cocinas = await client.query(`SELECT DISTINCT cocina_id
         FROM pedido_combo_tareas_cocina
         WHERE pedido_item_id = $1 AND sucursal_id = $2`, [fila.pedido_item_id, sucursalId]);
            return {
                pedido_id: fila.pedido_id,
                numero_pedido: fila.numero_pedido,
                estado_pedido: fila.estado_pedido,
                pedido_item_id: fila.pedido_item_id,
                tarea_id: tareaId,
                decision_id: decision.rows[0].id,
                cocina_ids: cocinas.rows.map((r) => r.cocina_id),
                estado_linea: agregado.rows[0].estado,
                idempotente: false,
            };
        });
        for (const cocinaId of result.cocina_ids) {
            void this.realtime.cocinaActualizada(cocinaId, {
                pedido_id: result.pedido_id,
                item_id: result.pedido_item_id,
                tarea_combo_id: result.tarea_id,
                decision_cliente_id: result.decision_id,
                sucursal_id: sucursalId,
                accion: 'combo_pausado_decision_cliente',
            });
        }
        try {
            await this.realtime.pedidoActualizado({
                pedido_id: result.pedido_id,
                sucursal_id: sucursalId,
                estado: result.estado_pedido,
                numero_pedido: result.numero_pedido,
            });
        }
        catch {
        }
        return {
            pedido_id: result.pedido_id,
            pedido_item_id: result.pedido_item_id,
            tarea_id: result.tarea_id,
            decision_id: result.decision_id,
            estado_linea: result.estado_linea ?? 'pendiente',
            idempotente: result.idempotente,
        };
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