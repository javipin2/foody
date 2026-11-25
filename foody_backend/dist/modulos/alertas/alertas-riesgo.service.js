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
var AlertasRiesgoService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AlertasRiesgoService = exports.UMBRALES_ALERTA = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const transaction_hooks_service_1 = require("../../core/database/transaction-hooks.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
exports.UMBRALES_ALERTA = {
    descuentoPorcentajeAlto: 30,
    cancelacionesPorDia: 3,
    meseroCancelacionVsPromedioFactor: 1.5,
    productoSinVentaDias: 14,
    transferenciasMesa: 2,
    cuadreCajaCOP: 5000,
    subidaCostoIngredientePct: 15,
    margenBajoPct: 20,
    margenDias: 7,
    caidaVentasPct: 40,
    prepCocinaSubidaPct: 30,
    prepCocinaMuestrasMin: 3,
    intentosDomiciliario: 3,
    demoraEntregaMultiplo: 2,
    qrPendienteAprobacionMinutos: 30,
    qrRecordatorioAprobacionMinutos: 3,
    qrUrgenteAprobacionMinutos: 5,
    cajaTurnoHoras: 12,
};
const TITULOS_PUSH = {
    intento_pedido_sin_stock: 'Sin stock — pedido rechazado',
    descuento_manual_excesivo: 'Descuento alto detectado',
    pedido_sin_domiciliario: 'Sin domiciliario disponible',
    cuadre_caja_diferencia: 'Diferencia en cierre de caja',
    item_eliminado_post_cocina: 'Ítem eliminado en cocina',
    item_no_disponible_cocina: 'Ítem no disponible en cocina',
    salio_sin_pagar: 'Mesa salió sin pagar',
    cocina_prep_subida: 'Cocina más lenta',
    caida_ventas_categoria: 'Caída por categoría',
};
let AlertasRiesgoService = AlertasRiesgoService_1 = class AlertasRiesgoService {
    database;
    realtime;
    notificaciones;
    transactionHooks;
    log = new common_1.Logger(AlertasRiesgoService_1.name);
    constructor(database, realtime, notificaciones, transactionHooks) {
        this.database = database;
        this.realtime = realtime;
        this.notificaciones = notificaciones;
        this.transactionHooks = transactionHooks;
    }
    async registrarEnTransaccion(client, params) {
        if (params.deduplicar && params.referenciaId) {
            const existe = await client.query(`SELECT id FROM alertas_riesgo
         WHERE sucursal_id = $1 AND tipo = $2 AND referencia_id = $3
           AND revisada = false
         LIMIT 1`, [params.sucursalId, params.tipo, params.referenciaId]);
            if (existe.rows[0])
                return false;
        }
        await client.query(`INSERT INTO alertas_riesgo (
         sucursal_id, tipo, nivel, descripcion, referencia_id, referencia_tipo
       ) VALUES ($1,$2,$3,$4,$5,$6)`, [
            params.sucursalId,
            params.tipo,
            params.nivel,
            params.descripcion,
            params.referenciaId ?? null,
            params.referenciaTipo ?? null,
        ]);
        this.transactionHooks.programarDespuesCommit(client, () => {
            this.despuesDeInsertar(params);
        });
        return true;
    }
    async registrar(params) {
        await this.database.enTransaccion(async (client) => {
            await this.registrarEnTransaccion(client, params);
        });
    }
    async registrarVariasEnTransaccion(alertas) {
        if (!alertas.length)
            return 0;
        return this.database.enTransaccion(async (client) => {
            let generadas = 0;
            for (const alerta of alertas) {
                if (await this.registrarEnTransaccion(client, alerta))
                    generadas++;
            }
            return generadas;
        });
    }
    despuesDeInsertar(params) {
        void this.realtime.alertaNueva(params.sucursalId, {
            tipo: params.tipo,
            nivel: params.nivel,
        });
        void this.enviarPushSiCritica(params);
    }
    async enviarPushSiCritica(params) {
        if (params.nivel !== 'alto' && params.nivel !== 'critico')
            return;
        const titulo = TITULOS_PUSH[params.tipo] ??
            (params.nivel === 'critico' ? 'Alerta crítica' : 'Alerta de riesgo');
        try {
            await this.notificaciones.enviar({
                sucursal_id: params.sucursalId,
                tipo: `alerta_riesgo_${params.tipo}`,
                titulo,
                cuerpo: params.descripcion.slice(0, 200),
                roles: ['admin', 'gerente_cadena', 'gerente'],
                datos: {
                    ruta: '/admin/panel?seccion=alertas',
                    alerta_tipo: params.tipo,
                    alerta_nivel: params.nivel,
                    referencia_id: params.referenciaId ?? '',
                    referencia_tipo: params.referenciaTipo ?? '',
                },
            });
        }
        catch (e) {
            this.log.warn(`FCM alerta ${params.tipo}: ${e instanceof Error ? e.message : e}`);
        }
    }
    async evaluarCancelacionesFrecuentes(client, sucursalId, usuarioId, pedidoId) {
        const fila = await client.query(`SELECT COUNT(*)::text AS total
       FROM estados_pedido_historial h
       INNER JOIN pedidos p ON p.id = h.pedido_id
       WHERE h.usuario_id = $1
         AND h.estado_nuevo = 'cancelado'
         AND p.sucursal_id = $2
         AND h.fecha >= date_trunc('day', now() AT TIME ZONE 'America/Bogota')`, [usuarioId, sucursalId]);
        const total = Number(fila.rows[0]?.total ?? 0);
        if (total >= exports.UMBRALES_ALERTA.cancelacionesPorDia) {
            await this.registrarEnTransaccion(client, {
                sucursalId,
                tipo: 'cancelaciones_frecuentes',
                nivel: 'medio',
                descripcion: `Usuario con ${total} cancelaciones hoy en la sucursal`,
                referenciaId: usuarioId,
                referenciaTipo: 'usuario',
                deduplicar: true,
            });
        }
    }
    async evaluarDemoraEntrega(client, pedidoId, sucursalId) {
        const pedido = await client.query(`SELECT created_at, tiempo_estimado_minutos, numero_pedido
       FROM pedidos WHERE id = $1 AND sucursal_id = $2`, [pedidoId, sucursalId]);
        const fila = pedido.rows[0];
        if (!fila)
            return;
        const estimado = fila.tiempo_estimado_minutos ?? 25;
        const minutosReal = (Date.now() - new Date(fila.created_at).getTime()) / 60000;
        if (minutosReal > estimado * exports.UMBRALES_ALERTA.demoraEntregaMultiplo) {
            await this.registrarEnTransaccion(client, {
                sucursalId,
                tipo: 'demora_excesiva_entrega',
                nivel: 'medio',
                descripcion: `${fila.numero_pedido}: entrega en ${Math.round(minutosReal)} min (estimado ${estimado} min)`,
                referenciaId: pedidoId,
                referenciaTipo: 'pedido',
                deduplicar: true,
            });
        }
    }
    async evaluarSubidaCostoIngrediente(client, sucursalId, ingredienteId, nombreIngrediente, costoAnterior, costoNuevo) {
        if (costoAnterior <= 0 || costoNuevo <= costoAnterior)
            return;
        const pct = ((costoNuevo - costoAnterior) / costoAnterior) * 100;
        if (pct > exports.UMBRALES_ALERTA.subidaCostoIngredientePct) {
            await this.registrarEnTransaccion(client, {
                sucursalId,
                tipo: 'costo_ingrediente_sube',
                nivel: 'bajo',
                descripcion: `${nombreIngrediente}: costo subió ${Math.round(pct)}% (${costoAnterior.toFixed(2)} → ${costoNuevo.toFixed(2)})`,
                referenciaId: ingredienteId,
                referenciaTipo: 'ingrediente',
                deduplicar: true,
            });
        }
    }
    async evaluarAlertasProgramadas(sucursalId) {
        let generadas = 0;
        await this.database.enTransaccion(async (client) => {
            const margenes = await client.query(`SELECT p.id AS producto_id,
                p.nombre,
                AVG(m.margen_porcentaje)::float AS margen_prom,
                COUNT(*)::text AS ventas
         FROM margenes_venta m
         INNER JOIN pedido_items pi ON pi.id = m.pedido_item_id
         INNER JOIN productos p ON p.id = pi.producto_id
         INNER JOIN pedidos ped ON ped.id = m.pedido_id
         WHERE m.sucursal_id = $1
           AND ped.created_at >= now() - interval '${exports.UMBRALES_ALERTA.margenDias} days'
           AND ped.estado NOT IN ('cancelado', 'rechazado')
         GROUP BY p.id, p.nombre
         HAVING AVG(m.margen_porcentaje) < $2 AND COUNT(*) >= 3`, [sucursalId, exports.UMBRALES_ALERTA.margenBajoPct]);
            for (const row of margenes.rows) {
                const insertada = await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'margen_bajo_prolongado',
                    nivel: 'bajo',
                    descripcion: `${row.nombre}: margen promedio ${Number(row.margen_prom).toFixed(1)}% en ${exports.UMBRALES_ALERTA.margenDias} días (${row.ventas} ventas)`,
                    referenciaId: row.producto_id,
                    referenciaTipo: 'producto',
                    deduplicar: true,
                });
                if (insertada)
                    generadas++;
            }
            const caidas = await client.query(`WITH ventas AS (
           SELECT pi.producto_id,
                  p.nombre,
                  SUM(CASE WHEN ped.created_at >= date_trunc('week', now())
                    THEN pi.cantidad ELSE 0 END)::int AS semana_actual,
                  SUM(CASE WHEN ped.created_at >= date_trunc('week', now()) - interval '7 days'
                    AND ped.created_at < date_trunc('week', now())
                    THEN pi.cantidad ELSE 0 END)::int AS semana_anterior
           FROM pedido_items pi
           INNER JOIN pedidos ped ON ped.id = pi.pedido_id
           INNER JOIN productos p ON p.id = pi.producto_id
           WHERE ped.sucursal_id = $1
             AND ped.estado NOT IN ('cancelado', 'rechazado')
             AND ped.created_at >= date_trunc('week', now()) - interval '7 days'
           GROUP BY pi.producto_id, p.nombre
         )
         SELECT producto_id, nombre,
                semana_actual::text,
                semana_anterior::text
         FROM ventas
         WHERE semana_anterior >= 5
           AND semana_actual < semana_anterior * (100 - $2) / 100.0`, [sucursalId, exports.UMBRALES_ALERTA.caidaVentasPct]);
            for (const row of caidas.rows) {
                const insertada = await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'caida_ventas_producto',
                    nivel: 'bajo',
                    descripcion: `${row.nombre}: ventas ${row.semana_actual} vs ${row.semana_anterior} unidades (semana anterior)`,
                    referenciaId: row.producto_id,
                    referenciaTipo: 'producto',
                    deduplicar: true,
                });
                if (insertada)
                    generadas++;
            }
            const sinVenta = await client.query(`SELECT pr.id AS producto_id, pr.nombre
         FROM productos pr
         WHERE pr.sucursal_id = $1
           AND pr.disponible = true
           AND NOT EXISTS (
             SELECT 1
             FROM pedido_items pi
             JOIN pedidos p ON p.id = pi.pedido_id
             WHERE pi.producto_id = pr.id
               AND p.sucursal_id = $1
               AND p.estado NOT IN ('cancelado', 'rechazado')
               AND p.created_at >= now() - ($2::text || ' days')::interval
           )
         ORDER BY pr.nombre
         LIMIT 15`, [sucursalId, String(exports.UMBRALES_ALERTA.productoSinVentaDias)]);
            for (const row of sinVenta.rows) {
                const insertada = await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'producto_sin_venta',
                    nivel: 'bajo',
                    descripcion: `${row.nombre}: sin ventas en ${exports.UMBRALES_ALERTA.productoSinVentaDias} días`,
                    referenciaId: row.producto_id,
                    referenciaTipo: 'producto',
                    deduplicar: true,
                });
                if (insertada)
                    generadas++;
            }
            const meseros = await client.query(`WITH base AS (
           SELECT p.mesera_id,
                  COUNT(*)::int AS total,
                  COUNT(*) FILTER (
                    WHERE p.estado IN ('cancelado', 'rechazado')
                  )::int AS cancelados
           FROM pedidos p
           WHERE p.sucursal_id = $1
             AND p.mesera_id IS NOT NULL
             AND p.created_at >= now() - interval '7 days'
           GROUP BY p.mesera_id
           HAVING COUNT(*) >= 5
         ),
         prom AS (
           SELECT AVG(cancelados::float / NULLIF(total, 0) * 100) AS pct_promedio
           FROM base
         )
         SELECT b.mesera_id::text,
                COALESCE(u.nombre, 'Mesero') AS nombre,
                b.total::text,
                b.cancelados::text,
                ROUND((b.cancelados::float / NULLIF(b.total, 0) * 100)::numeric, 1)::text AS pct,
                ROUND(COALESCE(prom.pct_promedio, 0)::numeric, 1)::text AS pct_promedio
         FROM base b
         CROSS JOIN prom
         LEFT JOIN usuarios u ON u.id = b.mesera_id
         WHERE (b.cancelados::float / NULLIF(b.total, 0) * 100)
               > COALESCE(prom.pct_promedio, 0) * $2`, [sucursalId, exports.UMBRALES_ALERTA.meseroCancelacionVsPromedioFactor]);
            for (const row of meseros.rows) {
                const insertada = await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'mesero_cancelacion_alta',
                    nivel: 'medio',
                    descripcion: `${row.nombre}: ${row.pct}% cancelación (7d) vs promedio sede ${row.pct_promedio}%`,
                    referenciaId: row.mesera_id,
                    referenciaTipo: 'usuario',
                    deduplicar: true,
                });
                if (insertada)
                    generadas++;
            }
            const prepCocinas = await client.query(`WITH prep AS (
           SELECT COALESCE(pi.cocina_id, pr.cocina_id) AS cocina_id,
                  AVG(h.duracion_estado_anterior_seg / 60.0) FILTER (
                    WHERE h.fecha >= now() - interval '7 days'
                  ) AS min_actual,
                  AVG(h.duracion_estado_anterior_seg / 60.0) FILTER (
                    WHERE h.fecha >= now() - interval '14 days'
                      AND h.fecha < now() - interval '7 days'
                  ) AS min_anterior,
                  COUNT(*) FILTER (
                    WHERE h.fecha >= now() - interval '7 days'
                  )::int AS n_actual,
                  COUNT(*) FILTER (
                    WHERE h.fecha >= now() - interval '14 days'
                      AND h.fecha < now() - interval '7 days'
                  )::int AS n_anterior
           FROM estados_pedido_historial h
           JOIN pedidos p ON p.id = h.pedido_id
           JOIN pedido_items pi ON pi.pedido_id = p.id
           JOIN productos pr ON pr.id = pi.producto_id
           WHERE p.sucursal_id = $1
             AND h.estado_anterior = 'en_cocina'
             AND h.estado_nuevo = 'listo'
             AND h.duracion_estado_anterior_seg IS NOT NULL
             AND h.fecha >= now() - interval '14 days'
           GROUP BY COALESCE(pi.cocina_id, pr.cocina_id)
         )
         SELECT prep.cocina_id::text,
                COALESCE(c.nombre, 'Cocina') AS nombre,
                ROUND(prep.min_actual::numeric, 1)::text AS min_actual,
                ROUND(prep.min_anterior::numeric, 1)::text AS min_anterior,
                prep.n_actual::text,
                prep.n_anterior::text,
                ROUND(
                  ((prep.min_actual - prep.min_anterior)
                    / NULLIF(prep.min_anterior, 0) * 100)::numeric,
                  1
                )::text AS delta_pct
         FROM prep
         LEFT JOIN cocinas c ON c.id = prep.cocina_id
         WHERE prep.min_anterior IS NOT NULL
           AND prep.min_anterior > 0
           AND prep.n_actual >= $2
           AND prep.n_anterior >= $2
           AND prep.min_actual > prep.min_anterior * (100 + $3) / 100.0`, [
                sucursalId,
                exports.UMBRALES_ALERTA.prepCocinaMuestrasMin,
                exports.UMBRALES_ALERTA.prepCocinaSubidaPct,
            ]);
            for (const row of prepCocinas.rows) {
                const insertada = await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'cocina_prep_subida',
                    nivel: 'medio',
                    descripcion: `${row.nombre}: prep ${row.min_actual} min (7d) vs ${row.min_anterior} min (semana ant., +${row.delta_pct}%)`,
                    referenciaId: row.cocina_id,
                    referenciaTipo: 'cocina',
                    deduplicar: true,
                });
                if (insertada)
                    generadas++;
            }
            const caidaCat = await client.query(`WITH ventas AS (
           SELECT pr.categoria_id,
                  cat.nombre,
                  SUM(CASE WHEN ped.created_at >= date_trunc('week', now())
                    THEN pi.cantidad ELSE 0 END)::int AS semana_actual,
                  SUM(CASE WHEN ped.created_at >= date_trunc('week', now()) - interval '7 days'
                    AND ped.created_at < date_trunc('week', now())
                    THEN pi.cantidad ELSE 0 END)::int AS semana_anterior
           FROM pedido_items pi
           INNER JOIN pedidos ped ON ped.id = pi.pedido_id
           INNER JOIN productos pr ON pr.id = pi.producto_id
           INNER JOIN categorias cat ON cat.id = pr.categoria_id
           WHERE ped.sucursal_id = $1
             AND ped.estado NOT IN ('cancelado', 'rechazado')
             AND ped.created_at >= date_trunc('week', now()) - interval '7 days'
             AND pr.categoria_id IS NOT NULL
           GROUP BY pr.categoria_id, cat.nombre
         )
         SELECT categoria_id::text, nombre,
                semana_actual::text,
                semana_anterior::text
         FROM ventas
         WHERE semana_anterior >= 5
           AND semana_actual < semana_anterior * (100 - $2) / 100.0`, [sucursalId, exports.UMBRALES_ALERTA.caidaVentasPct]);
            for (const row of caidaCat.rows) {
                const insertada = await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'caida_ventas_categoria',
                    nivel: 'bajo',
                    descripcion: `Categoría ${row.nombre}: ${row.semana_actual} vs ${row.semana_anterior} u (semana anterior)`,
                    referenciaId: row.categoria_id,
                    referenciaTipo: 'categoria',
                    deduplicar: true,
                });
                if (insertada)
                    generadas++;
            }
        });
        return { generadas };
    }
};
exports.AlertasRiesgoService = AlertasRiesgoService;
exports.AlertasRiesgoService = AlertasRiesgoService = AlertasRiesgoService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        notificaciones_service_1.NotificacionesService,
        transaction_hooks_service_1.TransactionHooksService])
], AlertasRiesgoService);
//# sourceMappingURL=alertas-riesgo.service.js.map