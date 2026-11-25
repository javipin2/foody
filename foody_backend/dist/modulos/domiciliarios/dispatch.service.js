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
var DispatchService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.DispatchService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const pedidos_estado_command_service_1 = require("../pedidos/pedidos-estado-command.service");
const pedidos_dispatch_hooks_service_1 = require("../pedidos/pedidos-dispatch-hooks.service");
const configuracion_global_module_1 = require("../../core/config/configuracion-global.module");
const qa_safety_1 = require("../../core/config/qa-safety");
const MAX_NOTIFICADOS = 5;
let DispatchService = DispatchService_1 = class DispatchService {
    database;
    alertasRiesgo;
    realtime;
    notificaciones;
    pedidosEstadoCommand;
    pedidosDispatchHooks;
    configGlobal;
    logger = new common_1.Logger(DispatchService_1.name);
    expirandoOfertas = false;
    LOCK_TICK_EXPIRAR_OFERTAS = 9200001;
    constructor(database, alertasRiesgo, realtime, notificaciones, pedidosEstadoCommand, pedidosDispatchHooks, configGlobal) {
        this.database = database;
        this.alertasRiesgo = alertasRiesgo;
        this.realtime = realtime;
        this.notificaciones = notificaciones;
        this.pedidosEstadoCommand = pedidosEstadoCommand;
        this.pedidosDispatchHooks = pedidosDispatchHooks;
        this.configGlobal = configGlobal;
    }
    get radioInicialKm() {
        return this.configGlobal.radioInicialKm();
    }
    get radioIncrementoKm() {
        return this.configGlobal.ampliacionRadioKm();
    }
    get maxIntentos() {
        return this.configGlobal.intentosMaxBusqueda();
    }
    get ofertaExpiraSeg() {
        return this.configGlobal.ofertaExpiraSeg();
    }
    async validarPedidoParaDespacho(pedidoId, sucursalId, client) {
        const sql = `SELECT p.id, p.tipo, p.estado,
           EXISTS (
             SELECT 1 FROM pedido_items pi WHERE pi.pedido_id = p.id
           ) AS tiene_items,
           EXISTS (
             SELECT 1 FROM pedido_items pi
             WHERE pi.pedido_id = p.id AND pi.estado_cocina = 'no_disponible'
           ) AS tiene_items_no_disponibles,
           EXISTS (
             SELECT 1 FROM pedido_items pi
             WHERE pi.pedido_id = p.id
               AND (pi.estado_cocina IS NULL
                 OR pi.estado_cocina NOT IN ('listo', 'no_disponible'))
           ) AS tiene_items_cocina_pendientes
         FROM pedidos p
         WHERE p.id = $1 AND p.sucursal_id = $2${client ? ' FOR UPDATE' : ''}`;
        const pedido = client
            ? (await client.query(sql, [pedidoId, sucursalId])).rows[0]
            : await this.database.consultarUno(sql, [pedidoId, sucursalId]);
        if (!pedido) {
            return {
                valido: false,
                motivo: 'PEDIDO_NO_ENCONTRADO',
                mensaje: 'Pedido no encontrado en esta sede.',
            };
        }
        if (pedido.tipo !== 'domicilio') {
            return {
                valido: false,
                motivo: 'PEDIDO_NO_ES_DOMICILIO',
                mensaje: 'Solo los pedidos de domicilio pueden asignarse a un repartidor.',
            };
        }
        if (pedido.estado !== 'listo') {
            return {
                valido: false,
                motivo: 'PEDIDO_NO_LISTO',
                mensaje: 'El pedido debe estar listo para asignar un repartidor.',
            };
        }
        if (pedido.tiene_items !== true) {
            return {
                valido: false,
                motivo: 'PEDIDO_SIN_ITEMS',
                mensaje: 'El pedido no tiene productos para entregar. Revísalo antes de despachar.',
            };
        }
        if (pedido.tiene_items_no_disponibles === true) {
            return {
                valido: false,
                motivo: 'PEDIDO_ITEMS_NO_DISPONIBLES',
                mensaje: 'Este domicilio contiene productos marcados como no disponibles. Revisa el pedido, ajusta las líneas y confirma el total antes de asignar un repartidor.',
            };
        }
        if (pedido.tiene_items_cocina_pendientes === true) {
            return {
                valido: false,
                motivo: 'PEDIDO_COCINA_INCOMPLETA',
                mensaje: 'Este pedido aún tiene productos pendientes de preparación. Confirma cada línea en Cocina antes de asignar el domiciliario.',
            };
        }
        return { valido: true, pedido };
    }
    resultadoBloqueado(validacion) {
        return {
            iniciado: false,
            motivo: validacion.motivo,
            mensaje: validacion.mensaje,
        };
    }
    get comisionFoodyPct() {
        return this.configGlobal.comisionFoodyPct();
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Despacho automático pausado por FOODY_QA_SIN_EFECTOS');
            return;
        }
        this.pedidosDispatchHooks.registrar((pedidoId, sucursalId) => this.intentarDispatchAutomatico(pedidoId, sucursalId));
        setInterval(() => void this.database.intentarAdvisoryLock(this.LOCK_TICK_EXPIRAR_OFERTAS, () => this.tickExpirarOfertas()), 30_000);
    }
    async tickExpirarOfertas() {
        if (this.expirandoOfertas)
            return;
        this.expirandoOfertas = true;
        try {
            const reintentar = await this.expirarOfertasVencidas();
            for (const r of reintentar) {
                void this.iniciarBusquedaIndependientes(r.pedido_id, r.sucursal_id);
            }
        }
        finally {
            this.expirandoOfertas = false;
        }
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
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            return {
                iniciado: false,
                motivo: 'qa_sin_efectos',
                mensaje: 'Despacho automático desactivado durante E2E.',
            };
        }
        const validacion = await this.validarPedidoParaDespacho(pedidoId, sucursalId);
        if (!validacion.valido)
            return this.resultadoBloqueado(validacion);
        const asignado = await this.database.consultarUno(`SELECT id FROM asignaciones_domicilio
       WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`, [pedidoId]);
        if (asignado) {
            return { iniciado: true, motivo: 'ya_asignado' };
        }
        const plantaLibres = await this.contarPlantaLibres(sucursalId);
        if (plantaLibres > 0) {
            const auto = await this.asignarPrimeraPlantaLibre(pedidoId, sucursalId);
            if (auto && 'bloqueado' in auto && auto.bloqueado) {
                return this.resultadoBloqueado(auto.bloqueado);
            }
            if (auto) {
                return { iniciado: true, motivo: 'planta_asignada_auto', ...auto };
            }
        }
        return this.iniciarBusquedaIndependientes(pedidoId, sucursalId);
    }
    async asignarPrimeraPlantaLibre(pedidoId, sucursalId) {
        const result = await this.database.enTransaccion(async (client) => {
            const validacion = await this.validarPedidoParaDespacho(pedidoId, sucursalId, client);
            if (!validacion.valido) {
                return { bloqueado: validacion };
            }
            const fila = validacion.pedido;
            if (fila.tipo !== 'domicilio' || fila.estado !== 'listo') {
                return null;
            }
            const previa = await client.query(`SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')
         LIMIT 1`, [pedidoId]);
            if (previa.rows[0])
                return null;
            const planta = await client.query(`SELECT dp.id, dp.usuario_id
         FROM domiciliarios_planta dp
         JOIN usuarios u ON u.id = dp.usuario_id
         WHERE dp.sucursal_id = $1 AND dp.activo = true AND u.activo = true
           AND NOT EXISTS (
             SELECT 1 FROM asignaciones_domicilio ad
             INNER JOIN pedidos p ON p.id = ad.pedido_id
             WHERE ad.domiciliario_planta_id = dp.id
               AND ad.estado IN ('asignado', 'en_camino')
               AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
           )
         ORDER BY u.nombre
         LIMIT 1 FOR UPDATE OF dp SKIP LOCKED`, [sucursalId]);
            const dom = planta.rows[0];
            if (!dom)
                return null;
            await client.query(`INSERT INTO asignaciones_domicilio
           (pedido_id, sucursal_id, domiciliario_planta_id, tipo_domiciliario, estado, distancia_km)
         SELECT $1, $2, $3::uuid, 'planta', 'asignado',
           CASE
             WHEN s.lat IS NOT NULL AND s.lng IS NOT NULL
              AND p.lat IS NOT NULL AND p.lng IS NOT NULL
             THEN ROUND((
               6371 * acos(LEAST(1::float8, GREATEST(-1::float8,
                 cos(radians(s.lat::float8)) * cos(radians(p.lat::float8))
                 * cos(radians(p.lng::float8) - radians(s.lng::float8))
                 + sin(radians(s.lat::float8)) * sin(radians(p.lat::float8))
               )))
             )::numeric, 3)
             ELSE NULL
           END
         FROM pedidos p
         JOIN sucursales s ON s.id = p.sucursal_id
         WHERE p.id = $1 AND p.sucursal_id = $2`, [pedidoId, sucursalId, dom.id]);
            await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId,
                nuevoEstado: 'asignado',
                origen: 'dispatch',
                estadoAnterior: 'listo',
                tipo: 'domicilio',
            });
            return {
                pedido_id: pedidoId,
                domiciliario_planta_id: dom.id,
                domiciliario_usuario_id: dom.usuario_id,
                estado: 'asignado',
            };
        });
        if (!result)
            return null;
        if ('bloqueado' in result)
            return result;
        void this.realtime.domiciliarioPlantaActualizado(result.domiciliario_usuario_id, {
            pedido_id: result.pedido_id,
            sucursal_id: sucursalId,
            accion: 'asignado',
        });
        void this.realtime.pedidoActualizado({
            pedido_id: result.pedido_id,
            sucursal_id: sucursalId,
            estado: result.estado,
        });
        void this.notificaciones.enviar({
            sucursal_id: sucursalId,
            tipo: 'domicilio_asignado_planta',
            titulo: 'Nuevo domicilio asignado',
            cuerpo: 'Tienes un pedido listo para recoger y entregar',
            destinatario_usuario_id: result.domiciliario_usuario_id,
            datos: {
                pedido_id: result.pedido_id,
                ruta: '/domiciliario/planta',
            },
        });
        return result;
    }
    async iniciarBusquedaIndependientes(pedidoId, sucursalId) {
        const validacion = await this.validarPedidoParaDespacho(pedidoId, sucursalId);
        if (!validacion.valido)
            return this.resultadoBloqueado(validacion);
        await this.expirarOfertasVencidas(pedidoId);
        const ofertaActiva = await this.database.consultarUno(`SELECT id FROM ofertas_pedido
       WHERE pedido_id = $1 AND estado = 'activa' AND expira_at > now()`, [pedidoId]);
        if (ofertaActiva) {
            return {
                iniciado: false,
                motivo: 'oferta_activa',
                oferta_id: ofertaActiva.id,
            };
        }
        const ultimoIntento = await this.database.consultarUno(`SELECT COALESCE(MAX(intento_numero), 0) AS intento
       FROM ofertas_pedido WHERE pedido_id = $1`, [pedidoId]);
        const intentoNumero = (ultimoIntento?.intento ?? 0) + 1;
        if (intentoNumero > this.maxIntentos) {
            await this.crearAlertaSinDomiciliario(pedidoId, sucursalId);
            return {
                iniciado: false,
                motivo: 'max_intentos',
                intento: intentoNumero,
            };
        }
        const sucursal = await this.database.consultarUno(`SELECT s.lat, s.lng, s.ciudad_id, c.slug AS ciudad_slug
       FROM sucursales s
       LEFT JOIN ciudades c ON c.id = s.ciudad_id
       WHERE s.id = $1`, [sucursalId]);
        if (!sucursal) {
            throw new common_1.NotFoundException('Sucursal no encontrada');
        }
        let latSucursal = sucursal.lat != null ? Number(sucursal.lat) : null;
        let lngSucursal = sucursal.lng != null ? Number(sucursal.lng) : null;
        if (latSucursal == null || lngSucursal == null) {
            const centro = this.centroCiudadPorSlug(sucursal.ciudad_slug);
            if (!centro) {
                throw new common_1.BadRequestException({
                    error: 'SUCURSAL_SIN_COORDENADAS',
                    message: 'La sucursal no tiene ubicación GPS. Configura lat/lng en la sede o usa una ciudad con centro conocido.',
                });
            }
            latSucursal = centro.lat;
            lngSucursal = centro.lng;
        }
        const radioKm = this.radioInicialKm + this.radioIncrementoKm * (intentoNumero - 1);
        const candidatos = await this.buscarIndependientesCercanos(sucursal.ciudad_id, latSucursal, lngSucursal, radioKm);
        if (!candidatos.length) {
            const registro = await this.database.enTransaccion(async (client) => {
                const actual = await this.validarPedidoParaDespacho(pedidoId, sucursalId, client);
                if (!actual.valido)
                    return { bloqueado: actual };
                await client.query(`INSERT INTO ofertas_pedido (
             pedido_id, sucursal_id, radio_busqueda_km, intento_numero, estado, expira_at
           ) VALUES ($1,$2,$3,$4,'expirada', now())`, [pedidoId, sucursalId, radioKm, intentoNumero]);
                return { bloqueado: null };
            });
            if (registro.bloqueado)
                return this.resultadoBloqueado(registro.bloqueado);
            if (intentoNumero >= this.maxIntentos) {
                await this.crearAlertaSinDomiciliario(pedidoId, sucursalId);
            }
            return {
                iniciado: false,
                motivo: 'DOMICILIARIO_NO_DISPONIBLE',
                mensaje: `No hay repartidores independientes conectados y disponibles en un radio de ${radioKm} km. ` +
                    'Un repartidor debe abrir la app (Soy repartidor independiente), iniciar turno y activar disponibilidad en la misma ciudad.',
                intento: intentoNumero,
                radio_km: radioKm,
                expira_en_seg: this.ofertaExpiraSeg,
            };
        }
        const notificados = candidatos.slice(0, MAX_NOTIFICADOS);
        const expiraAt = new Date(Date.now() + this.ofertaExpiraSeg * 1000);
        const oferta = await this.database.enTransaccion(async (client) => {
            const actual = await this.validarPedidoParaDespacho(pedidoId, sucursalId, client);
            if (!actual.valido)
                return { bloqueado: actual };
            const insert = await client.query(`INSERT INTO ofertas_pedido (
           pedido_id, sucursal_id, radio_busqueda_km, intento_numero, expira_at
         ) VALUES ($1,$2,$3,$4,$5) RETURNING id`, [pedidoId, sucursalId, radioKm, intentoNumero, expiraAt.toISOString()]);
            const ofertaId = insert.rows[0].id;
            for (const c of notificados) {
                await client.query(`INSERT INTO respuestas_oferta (oferta_id, domiciliario_id, respuesta)
           VALUES ($1,$2,'no_vio')`, [ofertaId, c.domiciliario_id]);
            }
            return { id: ofertaId, notificados: notificados.length, bloqueado: null };
        });
        if (oferta.bloqueado)
            return this.resultadoBloqueado(oferta.bloqueado);
        void this.notificaciones.enviar({
            sucursal_id: sucursalId,
            tipo: 'domicilio_busqueda_independientes',
            titulo: 'Buscando repartidor',
            cuerpo: `${oferta.notificados} independiente(s) notificado(s)`,
            roles: ['admin', 'gerente'],
            datos: { pedido_id: pedidoId, oferta_id: oferta.id },
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
                cuerpo: `Tienes ${this.ofertaExpiraSeg} s para aceptar un domicilio`,
                destinatario_domiciliario_id: c.domiciliario_id,
                datos: {
                    oferta_id: oferta.id,
                    pedido_id: pedidoId,
                    sucursal_id: sucursalId,
                    expira_en_seg: String(this.ofertaExpiraSeg),
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
            expira_en_seg: this.ofertaExpiraSeg,
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
        const vencidas = await this.database.consultar(`UPDATE ofertas_pedido SET estado = 'expirada'
       WHERE estado = 'activa' AND expira_at <= now() ${filtro}
       RETURNING id, pedido_id, sucursal_id`, params);
        const reintentar = [];
        for (const oferta of vencidas) {
            const domiciliarios = await this.database.consultar(`SELECT domiciliario_id FROM respuestas_oferta
         WHERE oferta_id = $1 AND respuesta = 'no_vio'`, [oferta.id]);
            for (const d of domiciliarios) {
                void this.realtime.ofertaExpirada(d.domiciliario_id, {
                    oferta_id: oferta.id,
                    pedido_id: oferta.pedido_id,
                    sucursal_id: oferta.sucursal_id,
                });
            }
            const sigueListo = await this.database.consultarUno(`SELECT p.id FROM pedidos p
         WHERE p.id = $1
           AND p.estado = 'listo'
           AND p.tipo = 'domicilio'
           AND NOT EXISTS (
             SELECT 1 FROM asignaciones_domicilio ad
             WHERE ad.pedido_id = p.id
               AND ad.estado IN ('asignado', 'en_camino')
           )`, [oferta.pedido_id]);
            if (sigueListo) {
                reintentar.push({
                    pedido_id: oferta.pedido_id,
                    sucursal_id: oferta.sucursal_id,
                });
            }
        }
        return reintentar;
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
        const comision = Math.round(costoDomicilio * this.comisionFoodyPct);
        const ganancia = costoDomicilio - comision;
        return { comision, ganancia };
    }
    centroCiudadPorSlug(slug) {
        if (!slug)
            return null;
        const centros = {
            valledupar: { lat: 10.463714, lng: -73.253222 },
        };
        return centros[slug.toLowerCase()] ?? null;
    }
};
exports.DispatchService = DispatchService;
exports.DispatchService = DispatchService = DispatchService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        notificaciones_service_1.NotificacionesService,
        pedidos_estado_command_service_1.PedidosEstadoCommandService,
        pedidos_dispatch_hooks_service_1.PedidosDispatchHooksService,
        configuracion_global_module_1.ConfiguracionGlobalService])
], DispatchService);
//# sourceMappingURL=dispatch.service.js.map