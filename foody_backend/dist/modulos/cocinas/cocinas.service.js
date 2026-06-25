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
exports.CocinasService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
let CocinasService = class CocinasService {
    database;
    realtime;
    alertasRiesgo;
    constructor(database, realtime, alertasRiesgo) {
        this.database = database;
        this.realtime = realtime;
        this.alertasRiesgo = alertasRiesgo;
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
    crearCocina(dto) {
        return this.database.consultarUno(`INSERT INTO cocinas (sucursal_id, nombre, activa)
       VALUES ($1, $2, true)
       RETURNING id, nombre, activa`, [dto.sucursal_id, dto.nombre.trim()]);
    }
    async actualizarCocina(id, sucursalId, dto) {
        await this.exigirCocina(id, sucursalId);
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
        const enUso = await this.database.consultarUno(`SELECT COUNT(*) AS total FROM productos
       WHERE cocina_id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (Number(enUso?.total ?? 0) > 0) {
            throw new common_1.BadRequestException('No puedes desactivar una cocina con productos asignados. Reasigna esos productos primero.');
        }
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
        await this.evaluarDemorasEnCocina(cocinaId, sucursalId);
        return this.database.consultar(`SELECT p.id AS pedido_id, p.numero_pedido, p.tipo, p.estado,
              p.mesa_id, m.nombre AS mesa_nombre, p.cliente_nombre,
              p.observaciones, p.created_at,
              COALESCE(
                json_agg(
                  json_build_object(
                    'item_id', pi.id,
                    'producto', pr.nombre,
                    'cantidad', pi.cantidad,
                    'observaciones', pi.observaciones,
                    'estado_cocina', pi.estado_cocina,
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
         AND p.estado IN ('confirmado', 'en_cocina', 'listo')
       GROUP BY p.id, m.nombre
       ORDER BY p.created_at ASC`, [cocinaId, sucursalId]);
    }
    async cambiarEstadoItem(itemId, sucursalId, estado, usuarioId, motivo) {
        return this.database.enTransaccion(async (client) => {
            const item = await client.query(`SELECT pi.pedido_id, p.estado, pi.cocina_id, p.numero_pedido
         FROM pedido_items pi
         JOIN pedidos p ON p.id = pi.pedido_id
         WHERE pi.id = $1 AND p.sucursal_id = $2
         FOR UPDATE OF p`, [itemId, sucursalId]);
            if (!item.rows[0]) {
                throw new common_1.NotFoundException('Ítem de pedido no encontrado');
            }
            const pedidoId = item.rows[0].pedido_id;
            const estadoPedidoActual = item.rows[0].estado;
            await client.query(`UPDATE pedido_items SET estado_cocina = $1 WHERE id = $2`, [estado, itemId]);
            if (estado === 'no_disponible') {
                await this.alertasRiesgo.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'item_no_disponible_cocina',
                    nivel: 'alto',
                    descripcion: motivo?.trim() ||
                        `Cocina marcó ítem no disponible (pedido ${item.rows[0].numero_pedido})`,
                    referenciaId: pedidoId,
                    referenciaTipo: 'pedido',
                    deduplicar: false,
                });
                await client.query(`INSERT INTO impresion_cocina_jobs (sucursal_id, cocina_id, pedido_id, payload)
           VALUES ($1, $2, $3, $4::jsonb)`, [
                    sucursalId,
                    item.rows[0].cocina_id,
                    pedidoId,
                    JSON.stringify({ accion: 'item_no_disponible', item_id: itemId }),
                ]);
            }
            const conteo = await client.query(`SELECT COUNT(*) AS total,
                COUNT(*) FILTER (WHERE estado_cocina = 'listo') AS listos,
                COUNT(*) FILTER (WHERE estado_cocina IN ('preparando', 'listo')) AS en_proceso
         FROM pedido_items WHERE pedido_id = $1`, [pedidoId]);
            const { total, listos, en_proceso } = conteo.rows[0];
            let nuevoEstadoPedido = estadoPedidoActual;
            if (Number(total) > 0 && Number(listos) === Number(total)) {
                nuevoEstadoPedido = 'listo';
            }
            else if (Number(en_proceso) > 0) {
                nuevoEstadoPedido = 'en_cocina';
            }
            else {
                nuevoEstadoPedido = 'en_cocina';
            }
            if (nuevoEstadoPedido !== estadoPedidoActual) {
                await client.query(`UPDATE pedidos SET estado = $1 WHERE id = $2`, [
                    nuevoEstadoPedido,
                    pedidoId,
                ]);
                await client.query(`INSERT INTO estados_pedido_historial
             (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
           VALUES ($1, $2, $3, $4, $5)`, [
                    pedidoId,
                    estadoPedidoActual,
                    nuevoEstadoPedido,
                    usuarioId,
                    'Cambio automático desde cocina',
                ]);
            }
            return {
                item_id: itemId,
                estado_cocina: estado,
                pedido_id: pedidoId,
                estado_pedido: nuevoEstadoPedido,
                estado_pedido_anterior: estadoPedidoActual,
                cocina_id: item.rows[0].cocina_id,
                numero_pedido: item.rows[0].numero_pedido,
                sucursal_id: sucursalId,
            };
        }).then((result) => {
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
                void this.realtime.pedidoSeguimiento(result.pedido_id, {
                    pedido_id: result.pedido_id,
                    estado: result.estado_pedido,
                });
            }
            const { estado_pedido_anterior: _, ...respuesta } = result;
            return respuesta;
        });
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
    async evaluarDemorasEnCocina(cocinaId, sucursalId) {
        const demorados = await this.database.consultar(`SELECT DISTINCT p.id AS pedido_id, p.numero_pedido
       FROM pedido_items pi
       INNER JOIN pedidos p ON p.id = pi.pedido_id
       WHERE pi.cocina_id = $1 AND p.sucursal_id = $2
         AND pi.estado_cocina IN ('pendiente', 'preparando')
         AND pi.created_at < now() - interval '20 minutes'
         AND p.estado IN ('confirmado', 'en_cocina')`, [cocinaId, sucursalId]);
        for (const d of demorados) {
            await this.alertasRiesgo.registrar({
                sucursalId,
                tipo: 'demora_cocina',
                nivel: 'medio',
                descripcion: `Pedido ${d.numero_pedido} con ítems >20 min en cocina`,
                referenciaId: d.pedido_id,
                referenciaTipo: 'pedido',
                deduplicar: true,
            });
        }
    }
    async exigirCocina(id, sucursalId) {
        const c = await this.database.consultarUno(`SELECT id FROM cocinas WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!c)
            throw new common_1.NotFoundException('Cocina no encontrada');
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
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        alertas_riesgo_service_1.AlertasRiesgoService])
], CocinasService);
//# sourceMappingURL=cocinas.service.js.map