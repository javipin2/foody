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
exports.DispatchService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const RADIO_INICIAL_KM = 3;
const RADIO_INCREMENTO_KM = 2;
const MAX_INTENTOS = 3;
const OFERTA_EXPIRA_SEG = 60;
const MAX_NOTIFICADOS = 5;
const COMISION_FOODY_PCT = 0.15;
let DispatchService = class DispatchService {
    database;
    alertasRiesgo;
    realtime;
    notificaciones;
    constructor(database, alertasRiesgo, realtime, notificaciones) {
        this.database = database;
        this.alertasRiesgo = alertasRiesgo;
        this.realtime = realtime;
        this.notificaciones = notificaciones;
    }
    async contarPlantaLibres(sucursalId) {
        const filas = await this.database.consultar(`SELECT dp.id
       FROM domiciliarios_planta dp
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE dp.sucursal_id = $1 AND dp.activo = true AND u.activo = true
         AND NOT EXISTS (
           SELECT 1 FROM asignaciones_domicilio ad
           WHERE ad.domiciliario_planta_id = dp.id
             AND ad.estado IN ('asignado', 'en_camino')
         )`, [sucursalId]);
        return filas.length;
    }
    async intentarDispatchAutomatico(pedidoId, sucursalId) {
        const pedido = await this.database.consultarUno(`SELECT id, tipo, estado, costo_domicilio FROM pedidos
       WHERE id = $1 AND sucursal_id = $2`, [pedidoId, sucursalId]);
        if (!pedido || pedido.tipo !== 'domicilio' || pedido.estado !== 'listo') {
            return { iniciado: false, motivo: 'pedido_no_aplica' };
        }
        const asignado = await this.database.consultarUno(`SELECT id FROM asignaciones_domicilio
       WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`, [pedidoId]);
        if (asignado) {
            return { iniciado: false, motivo: 'ya_asignado' };
        }
        const plantaLibres = await this.contarPlantaLibres(sucursalId);
        if (plantaLibres > 0) {
            return { iniciado: false, motivo: 'planta_disponible' };
        }
        return this.iniciarBusquedaIndependientes(pedidoId, sucursalId);
    }
    async iniciarBusquedaIndependientes(pedidoId, sucursalId) {
        await this.expirarOfertasVencidas(pedidoId);
        const ofertaActiva = await this.database.consultarUno(`SELECT id FROM ofertas_pedido
       WHERE pedido_id = $1 AND estado = 'activa' AND expira_at > now()`, [pedidoId]);
        if (ofertaActiva) {
            return { iniciado: false, motivo: 'oferta_activa', oferta_id: ofertaActiva.id };
        }
        const ultimoIntento = await this.database.consultarUno(`SELECT COALESCE(MAX(intento_numero), 0) AS intento
       FROM ofertas_pedido WHERE pedido_id = $1`, [pedidoId]);
        const intentoNumero = (ultimoIntento?.intento ?? 0) + 1;
        if (intentoNumero > MAX_INTENTOS) {
            await this.crearAlertaSinDomiciliario(pedidoId, sucursalId);
            return { iniciado: false, motivo: 'max_intentos', intento: intentoNumero };
        }
        const sucursal = await this.database.consultarUno(`SELECT lat, lng, ciudad_id FROM sucursales WHERE id = $1`, [sucursalId]);
        if (!sucursal?.lat || !sucursal?.lng) {
            throw new common_1.BadRequestException({
                error: 'SUCURSAL_SIN_COORDENADAS',
                message: 'La sucursal no tiene ubicación GPS configurada',
            });
        }
        const radioKm = RADIO_INICIAL_KM + RADIO_INCREMENTO_KM * (intentoNumero - 1);
        const candidatos = await this.buscarIndependientesCercanos(sucursal.ciudad_id, Number(sucursal.lat), Number(sucursal.lng), radioKm);
        if (!candidatos.length) {
            if (intentoNumero >= MAX_INTENTOS) {
                await this.crearAlertaSinDomiciliario(pedidoId, sucursalId);
            }
            return {
                iniciado: false,
                motivo: 'DOMICILIARIO_NO_DISPONIBLE',
                intento: intentoNumero,
                radio_km: radioKm,
            };
        }
        const notificados = candidatos.slice(0, MAX_NOTIFICADOS);
        const expiraAt = new Date(Date.now() + OFERTA_EXPIRA_SEG * 1000);
        const oferta = await this.database.enTransaccion(async (client) => {
            const insert = await client.query(`INSERT INTO ofertas_pedido (
           pedido_id, sucursal_id, radio_busqueda_km, intento_numero, expira_at
         ) VALUES ($1,$2,$3,$4,$5) RETURNING id`, [pedidoId, sucursalId, radioKm, intentoNumero, expiraAt.toISOString()]);
            const ofertaId = insert.rows[0].id;
            for (const c of notificados) {
                await client.query(`INSERT INTO respuestas_oferta (oferta_id, domiciliario_id, respuesta)
           VALUES ($1,$2,'no_vio')`, [ofertaId, c.domiciliario_id]);
            }
            return { id: ofertaId, notificados: notificados.length };
        });
        for (const c of notificados) {
            void this.realtime.domiciliarioIndepOferta(c.domiciliario_id, {
                oferta_id: oferta.id,
                pedido_id: pedidoId,
                sucursal_id: sucursalId,
                expira_at: expiraAt.toISOString(),
            });
            void this.notificaciones.enviar({
                tipo: 'oferta_domicilio',
                titulo: 'Nuevo pedido disponible',
                cuerpo: 'Tienes 60 s para aceptar un domicilio',
                destinatario_domiciliario_id: c.domiciliario_id,
                datos: {
                    oferta_id: oferta.id,
                    pedido_id: pedidoId,
                    sucursal_id: sucursalId,
                    ruta: '/domiciliario/independiente',
                },
            });
        }
        return {
            iniciado: true,
            oferta_id: oferta.id,
            intento: intentoNumero,
            radio_km: radioKm,
            domiciliarios_notificados: oferta.notificados,
            expira_en_seg: OFERTA_EXPIRA_SEG,
        };
    }
    async buscarIndependientesCercanos(ciudadId, latSucursal, lngSucursal, radioKm) {
        const sesiones = await this.database.consultar(`SELECT ds.id AS sesion_id,
              ds.domiciliario_id,
              ds.lat_actual,
              ds.lng_actual,
              di.nombre
       FROM domiciliarios_sesiones ds
       JOIN domiciliarios_independientes di ON di.id = ds.domiciliario_id
       WHERE ds.activa = true
         AND ds.disponible = true
         AND di.estado_cuenta = 'activo'
         AND di.ciudad_id = $1
         AND ds.lat_actual IS NOT NULL
         AND ds.lng_actual IS NOT NULL
         AND NOT EXISTS (
           SELECT 1 FROM asignaciones_domicilio ad
           WHERE ad.domiciliario_independiente_id = di.id
             AND ad.estado IN ('asignado', 'en_camino')
         )`, [ciudadId]);
        return sesiones
            .map((s) => ({
            ...s,
            distancia_km: this.distanciaKm(latSucursal, lngSucursal, Number(s.lat_actual), Number(s.lng_actual)),
        }))
            .filter((s) => s.distancia_km <= radioKm)
            .sort((a, b) => a.distancia_km - b.distancia_km);
    }
    async expirarOfertasVencidas(pedidoId) {
        const filtro = pedidoId ? 'AND pedido_id = $1' : '';
        const params = pedidoId ? [pedidoId] : [];
        await this.database.consultar(`UPDATE ofertas_pedido SET estado = 'expirada'
       WHERE estado = 'activa' AND expira_at <= now() ${filtro}`, params);
    }
    async crearAlertaSinDomiciliario(pedidoId, sucursalId) {
        await this.alertasRiesgo.registrar({
            sucursalId,
            tipo: 'pedido_sin_domiciliario',
            nivel: 'alto',
            descripcion: 'Pedido de domicilio listo sin domiciliario tras 3 intentos de búsqueda',
            referenciaId: pedidoId,
            referenciaTipo: 'pedido',
            deduplicar: true,
        });
    }
    distanciaKm(lat1, lng1, lat2, lng2) {
        const R = 6371;
        const dLat = ((lat2 - lat1) * Math.PI) / 180;
        const dLng = ((lng2 - lng1) * Math.PI) / 180;
        const a = Math.sin(dLat / 2) ** 2 +
            Math.cos((lat1 * Math.PI) / 180) *
                Math.cos((lat2 * Math.PI) / 180) *
                Math.sin(dLng / 2) ** 2;
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
    async consultarUnoCliente(client, sql, params) {
        const r = await client.query(sql, params);
        return r.rows[0] ?? null;
    }
    calcularGanancias(costoDomicilio) {
        const comision = Math.round(costoDomicilio * COMISION_FOODY_PCT);
        const ganancia = costoDomicilio - comision;
        return { comision, ganancia };
    }
};
exports.DispatchService = DispatchService;
exports.DispatchService = DispatchService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        notificaciones_service_1.NotificacionesService])
], DispatchService);
//# sourceMappingURL=dispatch.service.js.map