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
var PromocionesCronService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PromocionesCronService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const promociones_service_1 = require("./promociones.service");
const qa_safety_1 = require("../../core/config/qa-safety");
let PromocionesCronService = PromocionesCronService_1 = class PromocionesCronService {
    promociones;
    database;
    logger = new common_1.Logger(PromocionesCronService_1.name);
    LOCK_PROMOCIONES_CRON = 9200004;
    constructor(promociones, database) {
        this.promociones = promociones;
        this.database = database;
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Cron de promociones pausado por FOODY_QA_SIN_EFECTOS');
            return;
        }
        setTimeout(() => void this.database.intentarAdvisoryLock(this.LOCK_PROMOCIONES_CRON, () => this.ejecutar()), 120_000);
        setInterval(() => void this.database.intentarAdvisoryLock(this.LOCK_PROMOCIONES_CRON, () => this.ejecutar()), 6 * 60 * 60 * 1000);
    }
    async ejecutar() {
        try {
            const res = await this.promociones.limpiarExpiradas(7);
            if (res.filas > 0) {
                this.logger.log(`Cron estados: ${res.filas} filas, ${res.objetos_storage} objetos`);
            }
        }
        catch (e) {
            this.logger.warn(`Cron estados falló: ${e instanceof Error ? e.message : String(e)}`);
        }
    }
};
exports.PromocionesCronService = PromocionesCronService;
exports.PromocionesCronService = PromocionesCronService = PromocionesCronService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [promociones_service_1.PromocionesService,
        database_service_1.DatabaseService])
], PromocionesCronService);
//# sourceMappingURL=promociones-cron.service.js.map