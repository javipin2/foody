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
var SuscripcionesCronService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.SuscripcionesCronService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
const notificaciones_service_1 = require("../../modulos/notificaciones/notificaciones.service");
let SuscripcionesCronService = SuscripcionesCronService_1 = class SuscripcionesCronService {
    database;
    notificaciones;
    logger = new common_1.Logger(SuscripcionesCronService_1.name);
    constructor(database, notificaciones) {
        this.database = database;
        this.notificaciones = notificaciones;
    }
    onModuleInit() {
        void this.ejecutar();
        setInterval(() => void this.ejecutar(), 60 * 60 * 1000);
    }
    async ejecutar() {
        const avisos = await this.enviarAvisosVencimiento();
        const vencidas = await this.marcarVencidas();
        const bloqueadas = await this.bloquearTrasGracia();
        return { vencidas, bloqueadas, ...avisos };
    }
    async marcarVencidas() {
        const filas = await this.database.consultar(`UPDATE suscripciones_restaurante
       SET estado = 'vencida'
       WHERE estado IN ('activa', 'prueba')
         AND plan <> 'gratis'
         AND fecha_vencimiento IS NOT NULL
         AND fecha_vencimiento < now()
       RETURNING id`);
        const n = filas.length;
        if (n > 0) {
            this.logger.log(`Suscripciones marcadas vencidas: ${n}`);
        }
        return n;
    }
    async bloquearTrasGracia() {
        const dias = await this.diasGraciaBloqueo();
        const filas = await this.database.consultar(`UPDATE suscripciones_restaurante
       SET estado = 'bloqueada',
           motivo_bloqueo = COALESCE(motivo_bloqueo, 'Período de gracia finalizado tras vencimiento')
       WHERE estado = 'vencida'
         AND plan <> 'gratis'
         AND fecha_vencimiento < now() - ($1::int * interval '1 day')
       RETURNING id`, [dias]);
        const n = filas.length;
        if (n > 0) {
            this.logger.log(`Suscripciones bloqueadas tras ${dias} días: ${n}`);
        }
        return n;
    }
    async enviarAvisosVencimiento() {
        const avisos3d = await this.enviarAviso3Dias();
        const avisosHoy = await this.enviarAvisoVenceHoy();
        return { avisos3d, avisosHoy };
    }
    async enviarAviso3Dias() {
        const filas = await this.listarParaAviso3Dias();
        let enviados = 0;
        for (const s of filas) {
            const ok = await this.pushAviso(s, {
                titulo: 'Tu plan Foody vence pronto',
                cuerpo: `«${s.restaurante_nombre}»: tu plan ${s.plan} vence en 3 días. Renueva para no perder acceso.`,
                tipo: 'suscripcion_aviso_3d',
            });
            if (ok) {
                await this.database.consultar(`UPDATE suscripciones_restaurante
           SET aviso_3d_enviado_at = now()
           WHERE id = $1`, [s.id]);
                enviados++;
            }
        }
        if (enviados > 0) {
            this.logger.log(`Avisos 3 días antes enviados: ${enviados}`);
        }
        return enviados;
    }
    async enviarAvisoVenceHoy() {
        const filas = await this.listarParaAvisoHoy();
        let enviados = 0;
        for (const s of filas) {
            const ok = await this.pushAviso(s, {
                titulo: 'Tu plan Foody vence hoy',
                cuerpo: `«${s.restaurante_nombre}»: hoy vence tu plan ${s.plan}. Renueva para seguir operando.`,
                tipo: 'suscripcion_aviso_hoy',
            });
            if (ok) {
                await this.database.consultar(`UPDATE suscripciones_restaurante
           SET aviso_vence_hoy_enviado_at = now()
           WHERE id = $1`, [s.id]);
                enviados++;
            }
        }
        if (enviados > 0) {
            this.logger.log(`Avisos vencimiento hoy enviados: ${enviados}`);
        }
        return enviados;
    }
    async listarParaAviso3Dias() {
        return this.database.consultar(`SELECT s.id, s.restaurante_id, s.plan, s.estado, s.fecha_vencimiento,
              r.nombre AS restaurante_nombre,
              (
                SELECT u.sucursal_id FROM usuarios u
                WHERE u.restaurante_id = s.restaurante_id
                  AND u.rol = 'admin' AND u.activo = true
                ORDER BY u.created_at ASC
                LIMIT 1
              ) AS sucursal_id
       FROM suscripciones_restaurante s
       INNER JOIN restaurantes r ON r.id = s.restaurante_id
       WHERE s.estado IN ('activa', 'prueba')
         AND s.plan <> 'gratis'
         AND s.aviso_3d_enviado_at IS NULL
         AND s.fecha_vencimiento::date = (CURRENT_DATE + 3)`);
    }
    async listarParaAvisoHoy() {
        return this.database.consultar(`SELECT s.id, s.restaurante_id, s.plan, s.estado, s.fecha_vencimiento,
              r.nombre AS restaurante_nombre,
              (
                SELECT u.sucursal_id FROM usuarios u
                WHERE u.restaurante_id = s.restaurante_id
                  AND u.rol = 'admin' AND u.activo = true
                ORDER BY u.created_at ASC
                LIMIT 1
              ) AS sucursal_id
       FROM suscripciones_restaurante s
       INNER JOIN restaurantes r ON r.id = s.restaurante_id
       WHERE s.estado IN ('activa', 'prueba')
         AND s.plan <> 'gratis'
         AND s.aviso_vence_hoy_enviado_at IS NULL
         AND s.fecha_vencimiento::date = CURRENT_DATE
         AND s.fecha_vencimiento > now()`);
    }
    async pushAviso(s, msg) {
        if (!s.sucursal_id)
            return false;
        try {
            await this.notificaciones.enviar({
                sucursal_id: s.sucursal_id,
                tipo: msg.tipo,
                titulo: msg.titulo,
                cuerpo: msg.cuerpo,
                roles: ['admin'],
                datos: {
                    restaurante_id: s.restaurante_id,
                    plan: s.plan,
                    fecha_vencimiento: s.fecha_vencimiento.toISOString(),
                },
            });
            return true;
        }
        catch (e) {
            this.logger.warn(`No se pudo enviar aviso suscripción ${s.id}: ${e instanceof Error ? e.message : e}`);
            return false;
        }
    }
    async diasGraciaBloqueo() {
        const fila = await this.database.consultarUno(`SELECT valor FROM configuracion_global_foody
       WHERE clave = 'dias_datos_restaurante_bloqueado'`);
        const n = Number(fila?.valor ?? 30);
        return Number.isFinite(n) && n > 0 ? n : 30;
    }
};
exports.SuscripcionesCronService = SuscripcionesCronService;
exports.SuscripcionesCronService = SuscripcionesCronService = SuscripcionesCronService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        notificaciones_service_1.NotificacionesService])
], SuscripcionesCronService);
//# sourceMappingURL=suscripciones-cron.service.js.map