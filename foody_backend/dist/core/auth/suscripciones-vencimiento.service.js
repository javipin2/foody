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
var SuscripcionesVencimientoService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SuscripcionesVencimientoService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
let SuscripcionesVencimientoService = SuscripcionesVencimientoService_1 = class SuscripcionesVencimientoService {
    database;
    logger = new common_1.Logger(SuscripcionesVencimientoService_1.name);
    constructor(database) {
        this.database = database;
    }
    async asegurarEstadoVigente(restauranteId) {
        const fila = await this.database.consultarUno(`SELECT estado, plan, fecha_vencimiento FROM suscripciones_restaurante
       WHERE restaurante_id = $1
       LIMIT 1`, [restauranteId]);
        if (!fila)
            return 'inactiva';
        if (fila.plan === 'gratis')
            return fila.estado;
        const vencidaPorFecha = fila.fecha_vencimiento != null &&
            new Date(fila.fecha_vencimiento).getTime() < Date.now();
        if (vencidaPorFecha &&
            ['activa', 'prueba'].includes(fila.estado)) {
            await this.database.consultar(`UPDATE suscripciones_restaurante
         SET estado = 'vencida', updated_at = now()
         WHERE restaurante_id = $1`, [restauranteId]);
            this.logger.log(`Suscripción ${restauranteId} pasó a vencida por fecha_vencimiento`);
            return 'vencida';
        }
        return fila.estado;
    }
};
exports.SuscripcionesVencimientoService = SuscripcionesVencimientoService;
exports.SuscripcionesVencimientoService = SuscripcionesVencimientoService = SuscripcionesVencimientoService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], SuscripcionesVencimientoService);
//# sourceMappingURL=suscripciones-vencimiento.service.js.map