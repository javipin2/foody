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
var CocinasDemorasCronService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.CocinasDemorasCronService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const qa_safety_1 = require("../../core/config/qa-safety");
const MAX_ALERTAS_POR_CICLO = 200;
const LOCK_COCINA_DEMORAS_CRON = 9200009;
const INTERVALO_EVALUACION_MS = 5 * 60_000;
let CocinasDemorasCronService = CocinasDemorasCronService_1 = class CocinasDemorasCronService {
    database;
    alertas;
    logger = new common_1.Logger(CocinasDemorasCronService_1.name);
    ejecutando = false;
    intervalo;
    inicio;
    constructor(database, alertas) {
        this.database = database;
        this.alertas = alertas;
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Cron de demoras de cocina pausado por FOODY_QA_SIN_EFECTOS');
            return;
        }
        this.intervalo = setInterval(() => this.iniciarCiclo(), INTERVALO_EVALUACION_MS);
        this.inicio = setTimeout(() => this.iniciarCiclo(), 15_000);
        this.intervalo.unref?.();
        this.inicio.unref?.();
    }
    onModuleDestroy() {
        if (this.intervalo)
            clearInterval(this.intervalo);
        if (this.inicio)
            clearTimeout(this.inicio);
    }
    iniciarCiclo() {
        void this.database
            .intentarAdvisoryLock(LOCK_COCINA_DEMORAS_CRON, () => this.ejecutar())
            .catch((error) => {
            const detalle = error instanceof Error ? error.message : String(error);
            this.logger.warn(`No se evaluaron demoras de cocina: ${detalle}`);
        });
    }
    async ejecutar() {
        if (this.ejecutando)
            return 0;
        this.ejecutando = true;
        try {
            const filas = await this.database.consultar(`SELECT p.id AS pedido_id, p.sucursal_id, p.numero_pedido
         FROM pedidos p
         WHERE p.estado IN ('confirmado', 'en_cocina', 'pagando', 'pagado')
           AND EXISTS (
             SELECT 1
             FROM pedido_items pi
             WHERE pi.pedido_id = p.id
               AND pi.estado_cocina IN ('pendiente', 'preparando')
               AND pi.created_at < now() - interval '20 minutes'
           )
           AND NOT EXISTS (
             SELECT 1
             FROM alertas_riesgo ar
             WHERE ar.sucursal_id = p.sucursal_id
               AND ar.tipo = 'demora_cocina'
               AND ar.referencia_id = p.id
               AND ar.revisada = false
           )
         ORDER BY p.created_at ASC
         LIMIT $1`, [MAX_ALERTAS_POR_CICLO]);
            if (!filas.length)
                return 0;
            return this.alertas.registrarVariasEnTransaccion(filas.map((fila) => ({
                sucursalId: fila.sucursal_id,
                tipo: 'demora_cocina',
                nivel: 'medio',
                descripcion: `Pedido ${fila.numero_pedido} con ítems >20 min en cocina`,
                referenciaId: fila.pedido_id,
                referenciaTipo: 'pedido',
                deduplicar: true,
            })));
        }
        finally {
            this.ejecutando = false;
        }
    }
};
exports.CocinasDemorasCronService = CocinasDemorasCronService;
exports.CocinasDemorasCronService = CocinasDemorasCronService = CocinasDemorasCronService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        alertas_riesgo_service_1.AlertasRiesgoService])
], CocinasDemorasCronService);
//# sourceMappingURL=cocinas-demoras-cron.service.js.map