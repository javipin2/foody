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
exports.DispositivosService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
let DispositivosService = class DispositivosService {
    database;
    constructor(database) {
        this.database = database;
    }
    async registrar(datos) {
        await this.database.consultar(`INSERT INTO dispositivos_cliente (device_id, fcm_token, ciudad_id, plataforma, ultimo_acceso)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (device_id) DO UPDATE SET
         fcm_token = COALESCE(EXCLUDED.fcm_token, dispositivos_cliente.fcm_token),
         ciudad_id = COALESCE(EXCLUDED.ciudad_id, dispositivos_cliente.ciudad_id),
         plataforma = COALESCE(EXCLUDED.plataforma, dispositivos_cliente.plataforma),
         ultimo_acceso = now()
       WHERE dispositivos_cliente.anonimizado = false`, [
            datos.device_id,
            datos.fcm_token ?? null,
            datos.ciudad_id ?? null,
            datos.plataforma ?? 'android',
        ]);
        return { device_id: datos.device_id, registrado: true };
    }
    async anonimizar(deviceId) {
        const fila = await this.database.consultarUno(`UPDATE dispositivos_cliente
       SET fcm_token = NULL,
           ciudad_id = NULL,
           plataforma = 'anonimo',
           anonimizado = true,
           anonimizado_at = now()
       WHERE device_id = $1 AND anonimizado = false
       RETURNING device_id`, [deviceId]);
        if (!fila) {
            return { device_id: deviceId, anonimizado: false, motivo: 'no_encontrado' };
        }
        return { device_id: deviceId, anonimizado: true };
    }
};
exports.DispositivosService = DispositivosService;
exports.DispositivosService = DispositivosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], DispositivosService);
//# sourceMappingURL=dispositivos.service.js.map