import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { ForbiddenException, Inject, Injectable } from '@nestjs/common';
import type { Cache } from 'cache-manager';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import {
  SQL_DIA_LOCAL,
  SQL_HOY_LOCAL,
  SQL_PEDIDOS_VALIDOS,
  SQL_PEDIDOS_VALIDOS_P,
  SQL_PEDIDO_DESDE_7D,
  SQL_PEDIDO_DESDE_7D_P,
  SQL_PEDIDO_ES_HOY,
} from '../../compartido/sql/ventas-metricas.sql';
import {
  SQL_WHERE_PEDIDO_COMPLETADO,
  sqlWherePedidoAbiertoOperativo,
} from '../pedidos/pedido-estados';

/** PERF-CACHE-03: resumen dashboard TTL corto (sigue “casi vivo”). */
const TTL_RESUMEN_MS = 30_000;

export type ResumenSucursalDashboard = {
  sucursal_id: string;
  nombre: string;
  ventas_hoy: number;
  pedidos_activos: number;
  pedidos_pendientes_qr: number;
  pedidos_completados_hoy: number;
  alertas_pendientes: number;
  domicilios_tardios: Array<{
    numero: string;
    detalle: string;
    minutos: number;
    severidad: number;
  }>;
};

@Injectable()
export class DashboardService {
  constructor(
    private readonly database: DatabaseService,
    private readonly sucursalScope: SucursalScopeService,
    @Inject(CACHE_MANAGER) private readonly cache: Cache,
  ) {}

  /** BN-CTRL-04: gate corporativo en service. */
  async consolidadoParaUsuario(usuario: JwtPayload) {
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Usuario sin restaurante asignado');
    }
    if (!this.sucursalScope.esCorporativo(usuario)) {
      throw new ForbiddenException(
        'Solo usuarios corporativos pueden ver el dashboard consolidado',
      );
    }
    return this.consolidado(usuario.restaurante_id);
  }

  async resumen(sucursalId: string) {
    const clave = `dash:resumen:${sucursalId}`;
    const hit = await this.cache.get<Record<string, unknown>>(clave);
    if (hit) return hit;
    const fila = await this.resumenSucursalSql(sucursalId);
    const datos = fila ?? this.resumenVacio();
    await this.cache.set(clave, datos, TTL_RESUMEN_MS);
    return datos;
  }

  /** Series compactas para gráficos del panel admin (últimos 7 días). */
  async graficos(sucursalId: string) {
    const ventas7d = await this.database.consultar<{
      dia: string;
      pedidos: string;
      ventas: string;
    }>(
      `WITH dias AS (
         SELECT generate_series(
           (${SQL_HOY_LOCAL} - 6)::timestamp,
           ${SQL_HOY_LOCAL}::timestamp,
           interval '1 day'
         )::date AS dia
       ), ventas AS (
         SELECT ${SQL_DIA_LOCAL} AS dia,
                COUNT(*) AS pedidos,
                COALESCE(SUM(total), 0) AS ventas
         FROM pedidos
         WHERE sucursal_id = $1
           AND ${SQL_PEDIDO_DESDE_7D}
           AND ${SQL_PEDIDOS_VALIDOS}
         GROUP BY ${SQL_DIA_LOCAL}
       )
       SELECT dias.dia::text AS dia,
              COALESCE(ventas.pedidos, 0)::text AS pedidos,
              COALESCE(ventas.ventas, 0)::text AS ventas
       FROM dias
       LEFT JOIN ventas USING (dia)
       ORDER BY dias.dia ASC`,
      [sucursalId],
    );

    const porTipoHoy = await this.database.consultar<{
      tipo: string;
      pedidos: string;
      ventas: string;
    }>(
      `SELECT tipo,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(total), 0)::text AS ventas
       FROM pedidos
       WHERE sucursal_id = $1
         AND ${SQL_PEDIDO_ES_HOY}
         AND ${SQL_PEDIDOS_VALIDOS}
       GROUP BY tipo
       ORDER BY ventas DESC`,
      [sucursalId],
    );

    const topProductos = await this.database.consultar<{
      nombre: string;
      cantidad: string;
      ventas: string;
    }>(
      `SELECT pr.nombre,
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
         AND ${SQL_PEDIDO_DESDE_7D_P}
         AND ${SQL_PEDIDOS_VALIDOS_P}
       GROUP BY pr.id, pr.nombre
       ORDER BY cantidad DESC
       LIMIT 5`,
      [sucursalId],
    );

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

  /** KPIs agregados de todas las sucursales activas del restaurante (rol corporativo). */
  async consolidado(restauranteId: string) {
    const sucursales = await this.database.consultar<{
      id: string;
      nombre: string;
    }>(
      `SELECT id, nombre
       FROM sucursales
       WHERE restaurante_id = $1 AND activa = true
       ORDER BY nombre ASC`,
      [restauranteId],
    );

    const porSucursal: ResumenSucursalDashboard[] = [];
    for (const s of sucursales) {
      const fila = await this.resumenSucursalSql(s.id);
      porSucursal.push({
        sucursal_id: s.id,
        nombre: s.nombre,
        ...(fila ?? this.resumenVacio()),
      });
    }

    const totales = porSucursal.reduce(
      (acc, s) => ({
        ventas_hoy: acc.ventas_hoy + s.ventas_hoy,
        pedidos_activos: acc.pedidos_activos + s.pedidos_activos,
        pedidos_pendientes_qr:
          acc.pedidos_pendientes_qr + s.pedidos_pendientes_qr,
        pedidos_completados_hoy:
          acc.pedidos_completados_hoy + s.pedidos_completados_hoy,
        alertas_pendientes: acc.alertas_pendientes + s.alertas_pendientes,
      }),
      {
        ventas_hoy: 0,
        pedidos_activos: 0,
        pedidos_pendientes_qr: 0,
        pedidos_completados_hoy: 0,
        alertas_pendientes: 0,
      },
    );

    return {
      restaurante_id: restauranteId,
      sucursales_activas: porSucursal.length,
      totales,
      por_sucursal: porSucursal,
    };
  }

  private resumenVacio() {
    return {
      ventas_hoy: 0,
      pedidos_activos: 0,
      pedidos_pendientes_qr: 0,
      pedidos_completados_hoy: 0,
      alertas_pendientes: 0,
      domicilios_tardios: [],
    };
  }

  private async resumenSucursalSql(sucursalId: string) {
    const fila = await this.database.consultarUno<{
      ventas_hoy: string;
      pedidos_activos: string;
      pedidos_pendientes_qr: string;
      pedidos_completados_hoy: string;
      alertas_pendientes: string;
      domicilios_tardios: Array<{
        numero: string;
        detalle: string;
        minutos: number;
        severidad: number;
      }>;
    }>(
      `SELECT
         COALESCE((
           SELECT SUM(total)
           FROM pedidos
           WHERE sucursal_id = $1
             AND ${SQL_PEDIDO_ES_HOY}
             AND ${SQL_PEDIDOS_VALIDOS}
         ), 0)::text AS ventas_hoy,
         COALESCE((
           SELECT COUNT(*)
           FROM pedidos
           WHERE sucursal_id = $1
             AND ${sqlWherePedidoAbiertoOperativo()}
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
             AND ${SQL_WHERE_PEDIDO_COMPLETADO}
             AND ${SQL_PEDIDO_ES_HOY}
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
         ), '[]'::json) AS domicilios_tardios`,
      [sucursalId],
    );

    if (!fila) return null;

    return {
      ventas_hoy: Number(fila.ventas_hoy ?? 0),
      pedidos_activos: Number(fila.pedidos_activos ?? 0),
      pedidos_pendientes_qr: Number(fila.pedidos_pendientes_qr ?? 0),
      pedidos_completados_hoy: Number(fila.pedidos_completados_hoy ?? 0),
      alertas_pendientes: Number(fila.alertas_pendientes ?? 0),
      domicilios_tardios: fila.domicilios_tardios ?? [],
    };
  }
}
