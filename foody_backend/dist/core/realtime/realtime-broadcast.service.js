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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var RealtimeBroadcastService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RealtimeBroadcastService = void 0;
const crypto_1 = require("crypto");
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const supabase_js_1 = require("@supabase/supabase-js");
const ws_1 = __importDefault(require("ws"));
const qa_safety_1 = require("../config/qa-safety");
const realtime_topics_1 = require("./realtime-topics");
let RealtimeBroadcastService = RealtimeBroadcastService_1 = class RealtimeBroadcastService {
    config;
    logger = new common_1.Logger(RealtimeBroadcastService_1.name);
    cliente = null;
    canales = new Map();
    constructor(config) {
        this.config = config;
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Realtime desactivado por FOODY_QA_SIN_EFECTOS');
            return;
        }
        const url = this.config.get('SUPABASE_URL');
        const key = this.config.get('SUPABASE_SERVICE_KEY');
        if (url && key) {
            this.cliente = (0, supabase_js_1.createClient)(url, key, {
                auth: { persistSession: false, autoRefreshToken: false },
                realtime: {
                    transport: ws_1.default,
                },
            });
        }
        else {
            this.logger.error('SUPABASE_URL o SUPABASE_SERVICE_KEY no configurados — broadcast Realtime desactivado');
        }
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)())
            return;
        if (!this.estaConfigurado()) {
            this.logger.error('Realtime inactivo al arranque: configure SUPABASE_URL y SUPABASE_SERVICE_KEY en .env');
            return;
        }
        void this.verificarConexion().then((salud) => {
            if (salud.conectado) {
                this.logger.log('Realtime broadcast operativo');
            }
            else {
                this.logger.error(`Realtime broadcast no conectado: ${salud.detalle ?? 'sin detalle'}`);
            }
        });
    }
    estaConfigurado() {
        return this.cliente !== null;
    }
    pepper() {
        return (0, realtime_topics_1.pepperRealtime)(this.config);
    }
    topicSucursal(sucursalId) {
        return (0, realtime_topics_1.topicStaff)(this.pepper(), 'sucursal', sucursalId);
    }
    topicCocina(cocinaId) {
        return (0, realtime_topics_1.topicStaff)(this.pepper(), 'cocina', cocinaId);
    }
    topicRestaurante(restauranteId) {
        return (0, realtime_topics_1.topicStaff)(this.pepper(), 'restaurante', restauranteId);
    }
    topicDomiciliarioPlanta(usuarioId) {
        return (0, realtime_topics_1.topicStaff)(this.pepper(), 'domiciliario', usuarioId);
    }
    topicDomiciliarioIndep(domiciliarioId) {
        return (0, realtime_topics_1.topicStaff)(this.pepper(), 'domiciliario_indep', domiciliarioId);
    }
    async verificarConexion() {
        if (!this.cliente) {
            return {
                configurado: false,
                conectado: false,
                detalle: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_KEY',
            };
        }
        try {
            const ch = await this.obtenerCanal('foody_health_check');
            if (!ch) {
                return {
                    configurado: true,
                    conectado: false,
                    detalle: 'No se pudo abrir canal Realtime',
                };
            }
            await ch.send({
                type: 'broadcast',
                event: 'ping',
                payload: { origen: 'health', t: Date.now() },
            });
            return { configurado: true, conectado: true };
        }
        catch (e) {
            const detalle = e instanceof Error ? e.message : String(e);
            this.logger.error(`Health Realtime falló: ${detalle}`);
            return { configurado: true, conectado: false, detalle };
        }
    }
    onModuleDestroy() {
        if (!this.cliente)
            return;
        for (const [, ch] of this.canales) {
            void this.cliente.removeChannel(ch);
        }
        this.canales.clear();
    }
    async pedidoActualizado(payload) {
        await this.enviarBroadcast(this.topicSucursal(payload.sucursal_id), 'pedido_actualizado', payload);
    }
    static canalPedidoSeguimiento(pedidoId, seguimientoToken) {
        return `pedido_${pedidoId}_${seguimientoToken}`;
    }
    async pedidoSeguimiento(pedidoId, seguimientoToken, payload) {
        await this.enviarBroadcast(RealtimeBroadcastService_1.canalPedidoSeguimiento(pedidoId, seguimientoToken), 'estado_actualizado', payload);
    }
    async mesasActualizadas(sucursalId) {
        await this.enviarBroadcast(this.topicSucursal(sucursalId), 'mesas_actualizadas', { sucursal_id: sucursalId });
    }
    async cocinaActualizada(cocinaId, payload) {
        await this.enviarBroadcast(this.topicCocina(cocinaId), 'cocina_actualizada', {
            cocina_id: cocinaId,
            ...payload,
        });
    }
    async domiciliarioPlantaActualizado(usuarioId, payload) {
        await this.enviarBroadcast(this.topicDomiciliarioPlanta(usuarioId), 'pedido_asignado', { usuario_id: usuarioId, ...payload });
    }
    async domiciliarioIndepOferta(domiciliarioId, payload) {
        await this.enviarBroadcast(this.topicDomiciliarioIndep(domiciliarioId), 'oferta_nueva', { domiciliario_id: domiciliarioId, ...payload });
    }
    async cajaMovimiento(sucursalId, payload = {}) {
        await this.enviarBroadcast(this.topicSucursal(sucursalId), 'caja_movimiento', {
            sucursal_id: sucursalId,
            ...payload,
        });
    }
    async alertaNueva(sucursalId, payload = {}) {
        await this.enviarBroadcast(this.topicSucursal(sucursalId), 'alerta_nueva', {
            sucursal_id: sucursalId,
            ...payload,
        });
    }
    async qrAprobacionUrgente(sucursalId, payload) {
        await this.enviarBroadcast(this.topicSucursal(sucursalId), 'qr_aprobacion_urgente', {
            sucursal_id: sucursalId,
            ...payload,
        });
    }
    async catalogoDisponibilidad(sucursalId, payload) {
        const cuerpo = { sucursal_id: sucursalId, ...payload };
        await this.enviarBroadcast(this.topicSucursal(sucursalId), 'catalogo_disponibilidad', cuerpo);
        await this.enviarBroadcast((0, realtime_topics_1.topicCatalogoPublico)(sucursalId), 'catalogo_disponibilidad', cuerpo);
    }
    async suscripcionActualizada(restauranteId, payload) {
        await this.enviarBroadcast(this.topicRestaurante(restauranteId), 'suscripcion_actualizada', {
            restaurante_id: restauranteId,
            ...payload,
        });
    }
    async llamarMesera(sucursalId, payload) {
        await this.enviarBroadcast(this.topicSucursal(sucursalId), 'llamar_mesera', {
            sucursal_id: sucursalId,
            ...payload,
        });
    }
    async ubicacionRepartidor(pedidoId, seguimientoToken, payload) {
        await this.enviarBroadcast(RealtimeBroadcastService_1.canalPedidoSeguimiento(pedidoId, seguimientoToken), 'ubicacion_repartidor', {
            pedido_id: pedidoId,
            ...payload,
        });
    }
    async ofertaExpirada(domiciliarioId, payload) {
        await this.enviarBroadcast(this.topicDomiciliarioIndep(domiciliarioId), 'oferta_expirada', { domiciliario_id: domiciliarioId, ...payload });
    }
    async pedidoDesasignado(usuarioId, payload) {
        await this.enviarBroadcast(this.topicDomiciliarioPlanta(usuarioId), 'pedido_desasignado', {
            usuario_id: usuarioId,
            ...payload,
        });
    }
    async pedidoDesasignadoIndep(domiciliarioId, payload) {
        await this.enviarBroadcast(this.topicDomiciliarioIndep(domiciliarioId), 'pedido_desasignado', { domiciliario_id: domiciliarioId, ...payload });
    }
    async obtenerCanal(nombre) {
        if (!this.cliente)
            return null;
        const existente = this.canales.get(nombre);
        if (existente)
            return existente;
        const ch = this.cliente.channel(nombre, {
            config: { broadcast: { ack: false, self: false } },
        });
        await new Promise((resolve, reject) => {
            const timeout = setTimeout(() => reject(new Error('Timeout suscripción Realtime')), 8000);
            ch.subscribe((status, err) => {
                if (status === 'SUBSCRIBED') {
                    clearTimeout(timeout);
                    resolve();
                }
                if (status === 'CHANNEL_ERROR') {
                    clearTimeout(timeout);
                    reject(err ?? new Error('CHANNEL_ERROR'));
                }
            });
        });
        this.canales.set(nombre, ch);
        return ch;
    }
    async enviarBroadcast(canal, evento, payload) {
        try {
            const ch = await this.obtenerCanal(canal);
            if (!ch)
                return;
            await ch.send({
                type: 'broadcast',
                event: evento,
                payload: {
                    event_id: (0, crypto_1.randomUUID)(),
                    emitido_at: new Date().toISOString(),
                    ...payload,
                },
            });
        }
        catch (e) {
            this.logger.warn(`Broadcast ${canal}/${evento}: ${e}`);
        }
    }
};
exports.RealtimeBroadcastService = RealtimeBroadcastService;
exports.RealtimeBroadcastService = RealtimeBroadcastService = RealtimeBroadcastService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], RealtimeBroadcastService);
//# sourceMappingURL=realtime-broadcast.service.js.map