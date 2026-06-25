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
exports.AlertasService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
let AlertasService = class AlertasService {
    database;
    constructor(database) {
        this.database = database;
    }
    async listar(sucursalId, soloPendientes = true) {
        const filtro = soloPendientes ? 'AND revisada = false' : '';
        return this.database.consultar(`SELECT id, tipo, nivel, descripcion, referencia_id, referencia_tipo,
              revisada, revisada_at, created_at
       FROM alertas_riesgo
       WHERE sucursal_id = $1 ${filtro}
       ORDER BY
         CASE nivel
           WHEN 'critico' THEN 1
           WHEN 'alto' THEN 2
           WHEN 'medio' THEN 3
           ELSE 4
         END,
         created_at DESC
       LIMIT 100`, [sucursalId]);
    }
    async revisar(alertaId, sucursalId, usuarioId) {
        const fila = await this.database.consultarUno(`UPDATE alertas_riesgo
       SET revisada = true,
           revisada_por = $3,
           revisada_at = now()
       WHERE id = $1 AND sucursal_id = $2 AND revisada = false
       RETURNING id`, [alertaId, sucursalId, usuarioId]);
        if (!fila) {
            throw new common_1.NotFoundException('Alerta no encontrada o ya revisada');
        }
        return { id: alertaId, revisada: true };
    }
};
exports.AlertasService = AlertasService;
exports.AlertasService = AlertasService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], AlertasService);
//# sourceMappingURL=alertas.service.js.map