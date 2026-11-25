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
var PedidosQrCronService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PedidosQrCronService = void 0;
const common_1 = require("@nestjs/common");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const auditoria_service_1 = require("../auditoria/auditoria.service");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
const qa_safety_1 = require("../../core/config/qa-safety");
let PedidosQrCronService = PedidosQrCronService_1 = class PedidosQrCronService {
    database;
    notificaciones;
    realtime;
    auditoria;
    logger = new common_1.Logger(PedidosQrCronService_1.name);
    ejecutando = false;
    LOCK_PEDIDOS_QR_CRON = 9200005;
    constructor(database, notificaciones, realtime, auditoria) {
        this.database = database;
        this.notificaciones = notificaciones;
        this.realtime = realtime;
        this.auditoria = auditoria;
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.logger.warn('Cron QR pausado por FOODY_QA_SIN_EFECTOS');
            return;
        }
        setInterval(() => void this.database.intentarAdvisoryLock(this.LOCK_PEDIDOS_QR_CRON, () => this.ejecutar()), 60_000);
        setTimeout(() => void this.database.intentarAdvisoryLock(this.LOCK_PEDIDOS_QR_CRON, () => this.ejecutar()), 15_000);
    }
    async ejecutar() {
        if (this.ejecutando)
            return 0;
        this.ejecutando = true;
        try {
            const minutos = alertas_riesgo_service_1.UMBRALES_ALERTA.qrRecordatorioAprobacionMinutos;
            const pendientes = await this.database.consultar(`SELECT p.id, p.sucursal_id, p.mesa_id, p.numero_pedido, p.created_at,
                m.nombre AS mesa_nombre
         FROM pedidos p
         LEFT JOIN mesas m ON m.id = p.mesa_id
         WHERE p.estado = 'pendiente_aprobacion'
           AND p.created_at < now() - ($1::text || ' minutes')::interval
           AND NOT EXISTS (
             SELECT 1 FROM auditoria_logs a
             WHERE a.registro_id = p.id
               AND a.accion = 'QR_RECORDATORIO_APROBACION'
               AND a.created_at > now() - ($1::text || ' minutes')::interval
           )`, [String(minutos)]);
            for (const p of pendientes) {
                const num = p.numero_pedido ? `#${p.numero_pedido}` : 'QR';
                const mesa = p.mesa_nombre ? ` · ${p.mesa_nombre}` : '';
                const minEspera = Math.max(minutos, Math.floor((Date.now() - new Date(p.created_at).getTime()) / 60_000));
                const nivelUrgente = alertas_riesgo_service_1.UMBRALES_ALERTA.qrUrgenteAprobacionMinutos;
                const nivel = minEspera >= nivelUrgente ? 'urgente_5min' : 'advertencia_3min';
                await this.auditoria.registrar({
                    sucursalId: p.sucursal_id,
                    accion: 'QR_RECORDATORIO_APROBACION',
                    tablaAfectada: 'pedidos',
                    registroId: p.id,
                    datosDespues: {
                        minutos_espera: minEspera,
                        mesa_id: p.mesa_id,
                    },
                });
                void this.notificaciones.enviar({
                    sucursal_id: p.sucursal_id,
                    tipo: 'qr_recordatorio_aprobacion',
                    titulo: 'QR sin aprobar',
                    cuerpo: `Pedido ${num}${mesa} lleva ${minEspera} min esperando`,
                    roles: ['mesero', 'admin', 'gerente', 'cajero'],
                    datos: {
                        pedido_id: p.id,
                        sucursal_id: p.sucursal_id,
                        mesa_id: p.mesa_id ?? '',
                        ruta: '/admin/mesero',
                    },
                });
                void this.realtime.qrAprobacionUrgente(p.sucursal_id, {
                    pedido_id: p.id,
                    mesa_id: p.mesa_id,
                    numero_pedido: p.numero_pedido,
                    creado_at: new Date(p.created_at).toISOString(),
                    nivel,
                });
            }
            if (pendientes.length > 0) {
                this.logger.debug(`QR recordatorio: ${pendientes.length} pedido(s) (> ${minutos} min)`);
            }
            return pendientes.length;
        }
        finally {
            this.ejecutando = false;
        }
    }
};
exports.PedidosQrCronService = PedidosQrCronService;
exports.PedidosQrCronService = PedidosQrCronService = PedidosQrCronService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        notificaciones_service_1.NotificacionesService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        auditoria_service_1.AuditoriaService])
], PedidosQrCronService);
//# sourceMappingURL=pedidos-qr-cron.service.js.map