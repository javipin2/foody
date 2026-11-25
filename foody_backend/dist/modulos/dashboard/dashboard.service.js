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
exports.DashboardService = void 0;
const cache_manager_1 = require("@nestjs/cache-manager");
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
const pedido_estados_1 = require("../pedidos/pedido-estados");
const ESTADOS_PEDIDO_ACTIVO = [
    'pendiente_aprobacion',
    'pendiente',
    'confirmado',
    'en_cocina',
    'listo',
    'pagando',
    'asignado',
    'en_camino',
];
const TTL_RESUMEN_MS = 30_000;
let DashboardService = class DashboardService {
    database;
    sucursalScope;
    cache;
    constructor(database, sucursalScope, cache) {
        this.database = database;
        this.sucursalScope = sucursalScope;
        this.cache = cache;
    }
    async consolidadoParaUsuario(usuario) {
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Usuario sin restaurante asignado');
        }
        if (!this.sucursalScope.esCorporativo(usuario)) {
            throw new common_1.ForbiddenException('Solo usuarios corporativos pueden ver el dashboard consolidado');
        }
        return this.consolidado(usuario.restaurante_id);
    }
    async resumen(sucursalId) {
        const clave = `dash:resumen:${sucursalId}`;
        const hit = await this.cache.get(clave);
        if (hit)
            return hit;
        const fila = await this.resumenSucursalSql(sucursalId);
        const datos = fila ?? this.resumenVacio();
        await this.cache.set(clave, datos, TTL_RESUMEN_MS);
        return datos;
    }
    async graficos(sucursalId) {
        const ventas7d = await this.database.consultar(`SELECT ${ventas_metricas_sql_1.SQL_DIA_LOCAL}::text AS dia,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_PEDIDO_DESDE_7D}
         AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS}
       GROUP BY ${ventas_metricas_sql_1.SQL_DIA_LOCAL}
       ORDER BY dia ASC`, [sucursalId]);
        const porTipoHoy = await this.database.consultar(`SELECT tipo,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_PEDIDO_ES_HOY}
         AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS}
       GROUP BY tipo
       ORDER BY ventas DESC`, [sucursalId]);
        const topProductos = await this.database.consultar(`SELECT pr.nombre,
              COALESCE(SUM(pi.cantidad), 0)::text AS cantidad,
              COALESCE(
                SUM(
                  pi.cantidad * pi.precio_unitario
                  + COALESCE(pit_ag.sum_topping, 0) * pi.cantidad
                  + COALESCE(pib_ag.sum_bebida, 0)
                ),
                0
              )::text AS ventas
       FROM pedidos p
       JOIN pedido_items pi ON pi.pedido_id = p.id
       JOIN productos pr ON pr.id = pi.producto_id
       LEFT JOIN (
         SELECT
           pedido_item_id,
           SUM(precio_topping) AS sum_topping
         FROM pedido_item_toppings
         GROUP BY pedido_item_id
       ) pit_ag ON pit_ag.pedido_item_id = pi.id
       LEFT JOIN (
         SELECT
           pedido_item_id,
           SUM(precio_bebida * cantidad) AS sum_bebida
         FROM pedido_item_bebidas
         GROUP BY pedido_item_id
       ) pib_ag ON pib_ag.pedido_item_id = pi.id
       WHERE p.sucursal_id = $1
         AND ${ventas_metricas_sql_1.SQL_PEDIDO_DESDE_7D_P}
         AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS_P}
       GROUP BY pr.id, pr.nombre
       ORDER BY cantidad DESC
       LIMIT 5`, [sucursalId]);
        return {
            ventas_7_dias: ventas7d.map((f) => ({
                dia: f.dia,
                pedidos: Number(f.pedidos),
                ventas: Number(f.ventas),
            })),
            pedidos_por_tipo_hoy: porTipoHoy.map((f) => ({
                tipo: f.tipo,
                pedidos: Number(f.pedidos),
                ventas: Number(f.ventas),
            })),
            top_productos_7d: topProductos.map((f) => ({
                nombre: f.nombre,
                cantidad: Number(f.cantidad),
                ventas: Number(f.ventas),
            })),
        };
    }
    async consolidado(restauranteId) {
        const sucursales = await this.database.consultar(`SELECT id, nombre
       FROM sucursales
       WHERE restaurante_id = $1 AND activa = true
       ORDER BY nombre ASC`, [restauranteId]);
        const porSucursal = [];
        for (const s of sucursales) {
            const fila = await this.resumenSucursalSql(s.id);
            porSucursal.push({
                sucursal_id: s.id,
                nombre: s.nombre,
                ...(fila ?? this.resumenVacio()),
            });
        }
        const totales = porSucursal.reduce((acc, s) => ({
            ventas_hoy: acc.ventas_hoy + s.ventas_hoy,
            pedidos_activos: acc.pedidos_activos + s.pedidos_activos,
            pedidos_pendientes_qr: acc.pedidos_pendientes_qr + s.pedidos_pendientes_qr,
            pedidos_completados_hoy: acc.pedidos_completados_hoy + s.pedidos_completados_hoy,
            alertas_pendientes: acc.alertas_pendientes + s.alertas_pendientes,
        }), {
            ventas_hoy: 0,
            pedidos_activos: 0,
            pedidos_pendientes_qr: 0,
            pedidos_completados_hoy: 0,
            alertas_pendientes: 0,
        });
        return {
            restaurante_id: restauranteId,
            sucursales_activas: porSucursal.length,
            totales,
            por_sucursal: porSucursal,
        };
    }
    resumenVacio() {
        return {
            ventas_hoy: 0,
            pedidos_activos: 0,
            pedidos_pendientes_qr: 0,
            pedidos_completados_hoy: 0,
            alertas_pendientes: 0,
            domicilios_tardios: [],
        };
    }
    async resumenSucursalSql(sucursalId) {
        const fila = await this.database.consultarUno(`SELECT
         COALESCE((
           SELECT SUM(total)
           FROM pedidos
           WHERE sucursal_id = $1
             AND ${ventas_metricas_sql_1.SQL_PEDIDO_ES_HOY}
             AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS}
         ), 0)::text AS ventas_hoy,
         COALESCE((
           SELECT COUNT(*)
           FROM pedidos
           WHERE sucursal_id = $1
             AND estado = ANY($2::text[])
         ), 0)::text AS pedidos_activos,
         COALESCE((
           SELECT COUNT(*)
           FROM pedidos
           WHERE sucursal_id = $1 AND estado = 'pendiente_aprobacion'
         ), 0)::text AS pedidos_pendientes_qr,
         COALESCE((
           SELECT COUNT(*)
           FROM pedidos
           WHERE sucursal_id = $1
             AND ${pedido_estados_1.SQL_WHERE_PEDIDO_COMPLETADO}
             AND ${ventas_metricas_sql_1.SQL_PEDIDO_ES_HOY}
         ), 0)::text AS pedidos_completados_hoy,
         COALESCE((
           SELECT COUNT(*)
           FROM alertas_riesgo
           WHERE sucursal_id = $1 AND revisada = false
         ), 0)::text AS alertas_pendientes,
         COALESCE((
           SELECT json_agg(json_build_object(
             'numero', demoras.numero_pedido,
             'detalle', CASE
               WHEN demoras.estado = 'listo' AND demoras.domiciliario_nombre IS NOT NULL
                 THEN 'Listo · ' || demoras.domiciliario_nombre
               WHEN demoras.estado = 'listo' THEN 'Listo · sin asignar'
               WHEN demoras.estado = 'asignado' AND demoras.domiciliario_nombre IS NOT NULL
                 THEN 'Asignado · ' || demoras.domiciliario_nombre
               WHEN demoras.estado = 'en_camino' AND demoras.domiciliario_nombre IS NOT NULL
                 THEN 'En camino · ' || demoras.domiciliario_nombre
               WHEN demoras.estado = 'asignado' THEN 'Asignado'
               ELSE 'En camino'
             END,
             'minutos', demoras.minutos,
             'severidad', demoras.severidad
           ) ORDER BY demoras.severidad, demoras.minutos DESC)
           FROM (
             SELECT base.numero_pedido,
                    base.estado,
                    base.domiciliario_nombre,
                    GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (now() - base.estado_desde)) / 60)::int) AS minutos,
                    CASE
                      WHEN base.estado = 'listo' THEN 0
                      WHEN EXTRACT(EPOCH FROM (now() - base.estado_desde)) / 60 >= 40 THEN 0
                      ELSE 1
                    END AS severidad
             FROM (
               SELECT p.numero_pedido, p.estado,
                      COALESCE(h.fecha, p.created_at) AS estado_desde,
                      dom.domiciliario_nombre
               FROM pedidos p
               LEFT JOIN LATERAL (
                 SELECT fecha FROM estados_pedido_historial
                 WHERE pedido_id = p.id AND estado_nuevo = p.estado
                 ORDER BY fecha DESC LIMIT 1
               ) h ON true
               LEFT JOIN LATERAL (
                 SELECT u.nombre AS domiciliario_nombre
                 FROM asignaciones_domicilio ad
                 JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
                 JOIN usuarios u ON u.id = dp.usuario_id
                 WHERE ad.pedido_id = p.id
                   AND ad.estado IN ('asignado', 'en_camino', 'entregado')
                 ORDER BY ad.asignado_at DESC LIMIT 1
               ) dom ON true
               WHERE p.sucursal_id = $1
                 AND p.tipo = 'domicilio'
                 AND p.estado IN ('listo', 'asignado', 'en_camino')
             ) base
             WHERE (base.estado = 'listo'
                    AND base.estado_desde < now() - interval '8 minutes')
                OR (base.estado IN ('asignado', 'en_camino')
                    AND base.estado_desde < now() - interval '25 minutes')
             ORDER BY base.estado_desde ASC
             LIMIT 8
           ) demoras
         ), '[]'::json) AS domicilios_tardios`, [sucursalId, ESTADOS_PEDIDO_ACTIVO]);
        if (!fila)
            return null;
        return {
            ventas_hoy: Number(fila.ventas_hoy ?? 0),
            pedidos_activos: Number(fila.pedidos_activos ?? 0),
            pedidos_pendientes_qr: Number(fila.pedidos_pendientes_qr ?? 0),
            pedidos_completados_hoy: Number(fila.pedidos_completados_hoy ?? 0),
            alertas_pendientes: Number(fila.alertas_pendientes ?? 0),
            domicilios_tardios: fila.domicilios_tardios ?? [],
        };
    }
};
exports.DashboardService = DashboardService;
exports.DashboardService = DashboardService = __decorate([
    (0, common_1.Injectable)(),
    __param(2, (0, common_1.Inject)(cache_manager_1.CACHE_MANAGER)),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        sucursal_scope_service_1.SucursalScopeService, Object])
], DashboardService);
//# sourceMappingURL=dashboard.service.js.map