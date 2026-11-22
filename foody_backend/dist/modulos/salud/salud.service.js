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
exports.SaludService = void 0;
const common_1 = require("@nestjs/common");
const validar_config_produccion_1 = require("../../core/config/validar-config-produccion");
const database_service_1 = require("../../core/database/database.service");
const impresion_service_1 = require("../../core/impresion/impresion.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
let SaludService = class SaludService {
    database;
    realtime;
    impresion;
    constructor(database, realtime, impresion) {
        this.database = database;
        this.realtime = realtime;
        this.impresion = impresion;
    }
    async verificar() {
        const fila = await this.database.consultarUno('SELECT 1 AS ok');
        const base = {
            api: 'foody',
            version: '2026-07-01',
            base_datos: fila?.ok === 1,
            entorno: process.env.ENTORNO ?? 'desarrollo',
            timestamp: new Date().toISOString(),
        };
        if ((0, validar_config_produccion_1.esProduccion)()) {
            return base;
        }
        return {
            ...base,
            modulos: {
                mesas: ['GET listar', 'POST crear', 'GET qr', 'POST transferir', 'PATCH', 'DELETE'],
                menu_mesa_qr: 'GET /menu/mesa/:qr_token',
                cocinas: ['GET /cocinas/:sucursal', 'POST', 'PATCH', 'DELETE'],
                impresoras: ['GET /impresoras/:sucursal', 'POST', 'PATCH', 'DELETE'],
                kds: ['GET /cocina/cocinas', 'GET /cocina/tickets/:cocina_id', 'PATCH /cocina/items/:id/estado', 'POST /cocina/items/:id/fallo-preparacion'],
                zonas: [
                    'GET /zonas/cotizar-domicilio',
                    'GET /zonas/sucursal/:id/configuracion-mapa',
                    'PATCH /zonas/sucursal/:id/ubicacion',
                    'GET /zonas/:sucursal',
                    'POST',
                    'PATCH',
                    'DELETE',
                ],
                geografia: ['GET /geografia/buscar (Photon OSM)'],
                pedidos_dinero: ['POST /pedidos/:id/descuento', 'IVA en crear pedido', 'cancelación con reglas'],
                super_admin: [
                    'POST /super/restaurantes',
                    'GET/POST/PATCH /super/usuarios',
                    'PATCH /super/configuracion/:clave',
                    'GET /super/estadisticas',
                    'documentos domiciliario',
                ],
                sucursales_staff: ['GET /sucursales/mi-restaurante', 'POST /sucursales'],
            },
        };
    }
    async verificarCompleto() {
        const fila = await this.database.consultarUno('SELECT 1 AS ok');
        const baseDatos = fila?.ok === 1;
        const [realtime, agente, cola] = await Promise.all([
            this.realtime.verificarConexion(),
            this.impresion.verificarAgente(),
            this.impresion.estadisticasCola(),
        ]);
        const alertas = [];
        if (!baseDatos)
            alertas.push('base_datos_no_responde');
        if (!realtime.conectado) {
            alertas.push(realtime.configurado
                ? 'realtime_desconectado'
                : 'realtime_no_configurado');
        }
        if (!agente.conectado)
            alertas.push('agente_impresion_offline');
        if (cola.error > 0)
            alertas.push(`cola_impresion_errores:${cola.error}`);
        if (cola.pendientes > 20) {
            alertas.push(`cola_impresion_pendientes:${cola.pendientes}`);
        }
        const estado = !baseDatos
            ? 'critico'
            : alertas.length > 0
                ? 'degradado'
                : 'ok';
        return {
            estado,
            api: 'foody',
            version: '2026-07-01',
            entorno: process.env.ENTORNO ?? 'desarrollo',
            timestamp: new Date().toISOString(),
            base_datos: baseDatos,
            realtime,
            impresion: { agente, cola },
            alertas,
        };
    }
};
exports.SaludService = SaludService;
exports.SaludService = SaludService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        impresion_service_1.ImpresionService])
], SaludService);
//# sourceMappingURL=salud.service.js.map