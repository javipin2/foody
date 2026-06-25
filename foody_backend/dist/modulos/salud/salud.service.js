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
const database_service_1 = require("../../core/database/database.service");
let SaludService = class SaludService {
    database;
    constructor(database) {
        this.database = database;
    }
    async verificar() {
        const fila = await this.database.consultarUno('SELECT 1 AS ok');
        return {
            api: 'foody',
            version: '2026-06-04f',
            base_datos: fila?.ok === 1,
            entorno: process.env.ENTORNO ?? 'desarrollo',
            modulos: {
                mesas: ['GET listar', 'POST crear', 'GET qr', 'POST transferir', 'PATCH', 'DELETE'],
                menu_mesa_qr: 'GET /menu/mesa/:qr_token',
                cocinas: ['GET /cocinas/:sucursal', 'POST', 'PATCH', 'DELETE'],
                impresoras: ['GET /impresoras/:sucursal', 'POST', 'PATCH', 'DELETE'],
                kds: ['GET /cocina/cocinas', 'GET /cocina/tickets/:cocina_id', 'PATCH /cocina/items/:id/estado'],
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
};
exports.SaludService = SaludService;
exports.SaludService = SaludService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], SaludService);
//# sourceMappingURL=salud.service.js.map