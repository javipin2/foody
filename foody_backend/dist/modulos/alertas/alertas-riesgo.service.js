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
exports.AlertasRiesgoService = exports.UMBRALES_ALERTA = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
exports.UMBRALES_ALERTA = {
    descuentoPorcentajeAlto: 30,
    cancelacionesPorDia: 3,
    transferenciasMesa: 2,
    cuadreCajaCOP: 5000,
    subidaCostoIngredientePct: 15,
    margenBajoPct: 20,
    margenDias: 7,
    caidaVentasPct: 40,
    intentosDomiciliario: 3,
    demoraEntregaMultiplo: 2,
};
let AlertasRiesgoService = class AlertasRiesgoService {
    database;
    realtime;
    constructor(database, realtime) {
        this.database = database;
        this.realtime = realtime;
    }
    async registrarEnTransaccion(client, params) {
        if (params.deduplicar && params.referenciaId) {
            const existe = await client.query(`SELECT id FROM alertas_riesgo
         WHERE sucursal_id = $1 AND tipo = $2 AND referencia_id = $3
           AND revisada = false
         LIMIT 1`, [params.sucursalId, params.tipo, params.referenciaId]);
            if (existe.rows[0])
                return;
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
    }
    async registrar(params) {
        await this.database.enTransaccion(async (client) => {
            await this.registrarEnTransaccion(client, params);
        });
        void this.realtime.alertaNueva(params.sucursalId, {
            tipo: params.tipo,
            nivel: params.nivel,
        });
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
                await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'margen_bajo_prolongado',
                    nivel: 'bajo',
                    descripcion: `${row.nombre}: margen promedio ${Number(row.margen_prom).toFixed(1)}% en ${exports.UMBRALES_ALERTA.margenDias} días (${row.ventas} ventas)`,
                    referenciaId: row.producto_id,
                    referenciaTipo: 'producto',
                    deduplicar: true,
                });
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
                await this.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'caida_ventas_producto',
                    nivel: 'bajo',
                    descripcion: `${row.nombre}: ventas ${row.semana_actual} vs ${row.semana_anterior} unidades (semana anterior)`,
                    referenciaId: row.producto_id,
                    referenciaTipo: 'producto',
                    deduplicar: true,
                });
                generadas++;
            }
        });
        return { generadas };
    }
};
exports.AlertasRiesgoService = AlertasRiesgoService;
exports.AlertasRiesgoService = AlertasRiesgoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService])
], AlertasRiesgoService);
//# sourceMappingURL=alertas-riesgo.service.js.map