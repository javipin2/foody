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
var MesasReservaCronService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.MesasReservaCronService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const qa_safety_1 = require("../../core/config/qa-safety");
let MesasReservaCronService = MesasReservaCronService_1 = class MesasReservaCronService {
    database;
    realtime;
    logger = new common_1.Logger(MesasReservaCronService_1.name);
    ejecutando = false;
    LOCK_MESAS_RESERVA_CRON = 9200006;
    constructor(database, realtime) {
        this.database = database;
        this.realtime = realtime;
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Cron de reservas pausado por FOODY_QA_SIN_EFECTOS');
            return;
        }
        setInterval(() => void this.database.intentarAdvisoryLock(this.LOCK_MESAS_RESERVA_CRON, () => this.expirarReservas()), 5 * 60_000);
        setTimeout(() => void this.database.intentarAdvisoryLock(this.LOCK_MESAS_RESERVA_CRON, () => this.expirarReservas()), 20_000);
    }
    async expirarReservas() {
        if (this.ejecutando)
            return 0;
        this.ejecutando = true;
        try {
            const filas = await this.database.consultar(`UPDATE mesas
         SET estado_operativo = 'libre',
             reserva_cliente_nombre = NULL,
             reserva_cliente_telefono = NULL,
             reserva_hasta = NULL
         WHERE estado_operativo = 'reservada'
           AND reserva_hasta IS NOT NULL
           AND reserva_hasta < now()
           AND NOT EXISTS (
             SELECT 1 FROM pedidos p
             WHERE p.mesa_id = mesas.id
               AND p.estado NOT IN ('pagado', 'cancelado', 'rechazado')
           )
         RETURNING id, sucursal_id`);
            const sucursales = new Set(filas.map((f) => f.sucursal_id));
            for (const sid of sucursales) {
                void this.realtime.mesasActualizadas(sid);
            }
            if (filas.length > 0) {
                this.logger.debug(`Reservas expiradas: ${filas.length} mesa(s)`);
            }
            return filas.length;
        }
        finally {
            this.ejecutando = false;
        }
    }
};
exports.MesasReservaCronService = MesasReservaCronService;
exports.MesasReservaCronService = MesasReservaCronService = MesasReservaCronService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService])
], MesasReservaCronService);
//# sourceMappingURL=mesas-reserva-cron.service.js.map