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
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const supabase_js_1 = require("@supabase/supabase-js");
const ws_1 = __importDefault(require("ws"));
let RealtimeBroadcastService = RealtimeBroadcastService_1 = class RealtimeBroadcastService {
    config;
    logger = new common_1.Logger(RealtimeBroadcastService_1.name);
    cliente = null;
    canales = new Map();
    constructor(config) {
        this.config = config;
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
        if (this.estaConfigurado())
            return;
        this.logger.error('Realtime inactivo al arranque: configure SUPABASE_URL y SUPABASE_SERVICE_KEY en .env');
    }
    estaConfigurado() {
        return this.cliente !== null;
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
        await this.enviarBroadcast(`sucursal_${payload.sucursal_id}`, 'pedido_actualizado', payload);
    }
    async pedidoSeguimiento(pedidoId, payload) {
        await this.enviarBroadcast(`pedido_${pedidoId}`, 'estado_actualizado', payload);
    }
    async mesasActualizadas(sucursalId) {
        await this.enviarBroadcast(`sucursal_${sucursalId}`, 'mesas_actualizadas', {
            sucursal_id: sucursalId,
        });
    }
    async cocinaActualizada(cocinaId, payload) {
        await this.enviarBroadcast(`cocina_${cocinaId}`, 'cocina_actualizada', {
            cocina_id: cocinaId,
            ...payload,
        });
    }
    async domiciliarioPlantaActualizado(usuarioId, payload) {
        await this.enviarBroadcast(`domiciliario_${usuarioId}`, 'pedido_asignado', { usuario_id: usuarioId, ...payload });
    }
    async domiciliarioIndepOferta(domiciliarioId, payload) {
        await this.enviarBroadcast(`domiciliario_indep_${domiciliarioId}`, 'oferta_nueva', { domiciliario_id: domiciliarioId, ...payload });
    }
    async cajaMovimiento(sucursalId, payload = {}) {
        await this.enviarBroadcast(`sucursal_${sucursalId}`, 'caja_movimiento', {
            sucursal_id: sucursalId,
            ...payload,
        });
    }
    async alertaNueva(sucursalId, payload = {}) {
        await this.enviarBroadcast(`sucursal_${sucursalId}`, 'alerta_nueva', {
            sucursal_id: sucursalId,
            ...payload,
        });
    }
    async qrAprobacionUrgente(sucursalId, payload) {
        await this.enviarBroadcast(`sucursal_${sucursalId}`, 'qr_aprobacion_urgente', {
            sucursal_id: sucursalId,
            ...payload,
        });
    }
    async catalogoDisponibilidad(sucursalId, payload) {
        await this.enviarBroadcast(`sucursal_${sucursalId}`, 'catalogo_disponibilidad', {
            sucursal_id: sucursalId,
            ...payload,
        });
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
            await ch.send({ type: 'broadcast', event: evento, payload });
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