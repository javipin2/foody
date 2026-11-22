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
const database_service_1 = require("../../core/database/database.service");
const notificaciones_service_1 = require("./notificaciones.service");
let NotificacionesCronService = NotificacionesCronService_1 = class NotificacionesCronService {
    notificaciones;
    database;
    logger = new common_1.Logger(NotificacionesCronService_1.name);
    LOCK_NOTIFICACIONES_CRON = 9200007;
    LOCK_PURGA_CRECIMIENTO = 9200008;
    _ticks = 0;
    constructor(notificaciones, database) {
        this.notificaciones = notificaciones;
        this.database = database;
    }
    onModuleInit() {
        setInterval(() => void this.database.intentarAdvisoryLock(this.LOCK_NOTIFICACIONES_CRON, () => this.ejecutar()), 60_000);
    }
    async ejecutar() {
        const diag = await this.notificaciones.diagnostico();
        if (diag.pendientes > 0) {
            const res = await this.notificaciones.procesarPendientes(30);
            if (res.procesadas > 0) {
                this.logger.debug(`Cola FCM: ${res.procesadas} procesadas, ${res.enviados} enviados (${res.modo})`);
            }
        }
        this._ticks += 1;
        if (this._ticks % 60 !== 0)
            return;
        await this.database.intentarAdvisoryLock(this.LOCK_PURGA_CRECIMIENTO, async () => {
            const r = await this.notificaciones.purgarHistorialCrecimiento();
            if (r.cola > 0 || r.auditoria > 0) {
                this.logger.log(`Purga crecimiento: cola=${r.cola} auditoria=${r.auditoria}`);
            }
        });
    }
};
exports.NotificacionesCronService = NotificacionesCronService;
exports.NotificacionesCronService = NotificacionesCronService = NotificacionesCronService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [notificaciones_service_1.NotificacionesService,
        database_service_1.DatabaseService])
], NotificacionesCronService);
//# sourceMappingURL=notificaciones-cron.service.js.map