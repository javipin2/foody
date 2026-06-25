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
exports.DashboardService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
let DashboardService = class DashboardService {
    database;
    constructor(database) {
        this.database = database;
    }
    async resumen(sucursalId) {
        const ventasHoy = await this.database.consultarUno(`SELECT COALESCE(SUM(total), 0)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at::date = (NOW() AT TIME ZONE 'America/Bogota')::date
         AND estado NOT IN ('cancelado', 'rechazado')`, [sucursalId]);
        const pedidosActivos = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND estado IN (
           'pendiente_aprobacion', 'pendiente', 'confirmado',
           'en_cocina', 'listo', 'en_camino'
         )`, [sucursalId]);
        const pendientesQr = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1 AND estado = 'pendiente_aprobacion'`, [sucursalId]);
        const alertas = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM alertas_riesgo
       WHERE sucursal_id = $1 AND revisada = false`, [sucursalId]);
        const completadosHoy = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND estado = 'entregado'
         AND created_at::date = (NOW() AT TIME ZONE 'America/Bogota')::date`, [sucursalId]);
        return {
            ventas_hoy: Number(ventasHoy?.total ?? 0),
            pedidos_activos: Number(pedidosActivos?.total ?? 0),
            pedidos_pendientes_qr: Number(pendientesQr?.total ?? 0),
            pedidos_completados_hoy: Number(completadosHoy?.total ?? 0),
            alertas_pendientes: Number(alertas?.total ?? 0),
        };
    }
};
exports.DashboardService = DashboardService;
exports.DashboardService = DashboardService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], DashboardService);
//# sourceMappingURL=dashboard.service.js.map