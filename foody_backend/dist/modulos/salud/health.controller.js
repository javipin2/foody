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
exports.HealthController = void 0;
const common_1 = require("@nestjs/common");
const impresion_service_1 = require("../../core/impresion/impresion.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const salud_service_1 = require("./salud.service");
let HealthController = class HealthController {
    saludService;
    realtimeService;
    impresion;
    constructor(saludService, realtimeService, impresion) {
        this.saludService = saludService;
        this.realtimeService = realtimeService;
        this.impresion = impresion;
    }
    verificarCompleto() {
        return this.saludService.verificarCompleto();
    }
    async verificarRealtime() {
        return this.realtimeService.verificarConexion();
    }
    async verificarImpresion() {
        const agente = await this.impresion.verificarAgente();
        const cola = await this.impresion.estadisticasCola();
        return {
            ...agente,
            cola,
            modo_sin_hardware: 'Sin IP en impresora -> tickets en foody_python_printer/tickets/',
        };
    }
};
exports.HealthController = HealthController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], HealthController.prototype, "verificarCompleto", null);
__decorate([
    (0, common_1.Get)('realtime'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], HealthController.prototype, "verificarRealtime", null);
__decorate([
    (0, common_1.Get)('impresion'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], HealthController.prototype, "verificarImpresion", null);
exports.HealthController = HealthController = __decorate([
    (0, common_1.Controller)('health'),
    __metadata("design:paramtypes", [salud_service_1.SaludService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        impresion_service_1.ImpresionService])
], HealthController);
//# sourceMappingURL=health.controller.js.map