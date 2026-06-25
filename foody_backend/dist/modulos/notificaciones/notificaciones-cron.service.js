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
var NotificacionesCronService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificacionesCronService = void 0;
const common_1 = require("@nestjs/common");
const notificaciones_service_1 = require("./notificaciones.service");
let NotificacionesCronService = NotificacionesCronService_1 = class NotificacionesCronService {
    notificaciones;
    logger = new common_1.Logger(NotificacionesCronService_1.name);
    constructor(notificaciones) {
        this.notificaciones = notificaciones;
    }
    onModuleInit() {
        setInterval(() => void this.ejecutar(), 60_000);
    }
    async ejecutar() {
        const diag = await this.notificaciones.diagnostico();
        if (diag.pendientes === 0)
            return;
        const res = await this.notificaciones.procesarPendientes(30);
        if (res.procesadas > 0) {
            this.logger.debug(`Cola FCM: ${res.procesadas} procesadas, ${res.enviados} enviados (${res.modo})`);
        }
    }
};
exports.NotificacionesCronService = NotificacionesCronService;
exports.NotificacionesCronService = NotificacionesCronService = NotificacionesCronService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [notificaciones_service_1.NotificacionesService])
], NotificacionesCronService);
//# sourceMappingURL=notificaciones-cron.service.js.map