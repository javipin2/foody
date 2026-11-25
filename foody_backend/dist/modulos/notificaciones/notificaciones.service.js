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
var NotificacionesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificacionesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const qa_safety_1 = require("../../core/config/qa-safety");
const fcm_service_1 = require("./fcm.service");
let NotificacionesService = NotificacionesService_1 = class NotificacionesService {
    database;
    fcm;
    log = new common_1.Logger(NotificacionesService_1.name);
    constructor(database, fcm) {
        this.database = database;
        this.fcm = fcm;
    }
    async enviarPrueba(usuario) {
        const base = {
            tipo: 'prueba_foody',
            titulo: 'Foody — prueba FCM',
            cuerpo: 'Si ves esto, push operativo ✅',
        };
        if (usuario.rol === 'domiciliario_independiente') {
            return this.enviar({
                ...base,
                destinatario_domiciliario_id: usuario.sub,
                datos: { ruta: '/domiciliario/independiente' },
            });
        }
        return this.enviar({
            ...base,
            destinatario_usuario_id: usuario.sub,
            datos: { ruta: '/admin/panel' },
        });
    }
    async enviar(dto) {
        const payload = {
            titulo: dto.titulo,
            cuerpo: dto.cuerpo,
            ...(dto.datos ?? {}),
        };
        if (dto.roles?.length)
            payload['roles'] = dto.roles;
        if (dto.device_id)
            payload['device_id'] = dto.device_id;
        if (dto.destinatario_domiciliario_id) {
            payload['domiciliario_id'] = dto.destinatario_domiciliario_id;
        }
        await this.encolar({
            sucursal_id: dto.sucursal_id,
            tipo: dto.tipo,
            destinatario_usuario_id: dto.destinatario_usuario_id,
            payload,
        });
        return this.procesarPendientes(5);
    }
    async encolar(dto) {
        const fila = await this.database.consultarUno(`INSERT INTO notificaciones_pendientes (
         sucursal_id, tipo, destinatario_rol, destinatario_usuario_id, payload
       ) VALUES ($1,$2,$3,$4,$5::jsonb)
       RETURNING id`, [
            dto.sucursal_id ?? null,
            dto.tipo,
            dto.destinatario_rol ?? null,
            dto.destinatario_usuario_id ?? null,
            JSON.stringify(dto.payload ?? {}),
        ]);
        return { id: fila.id, encolada: true };
    }
    maxIntentosFcm() {
        const n = Number(process.env.FCM_MAX_INTENTOS);
        return Number.isFinite(n) && n > 0 ? Math.floor(n) : 10;
    }
    async procesarPendientes(limite = 50) {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.log.warn('Procesamiento FCM bloqueado en QA aislada');
            return {
                procesadas: 0,
                enviados: 0,
                abandonadas: 0,
                modo: 'qa_sin_efectos',
            };
        }
        const maxIntentos = this.maxIntentosFcm();
        const pendientes = await this.database.consultar(`SELECT id, sucursal_id, tipo, destinatario_rol, destinatario_usuario_id,
              payload, intentos
       FROM notificaciones_pendientes
       WHERE enviada = false AND abandonada = false
       ORDER BY created_at ASC
       LIMIT $1`, [limite]);
        let enviados = 0;
        let abandonadas = 0;
        for (const n of pendientes) {
            const tokens = await this._resolverTokens(n);
            const titulo = n.payload['titulo'] ??
                n.payload['title'] ??
                'Foody';
            const cuerpo = n.payload['cuerpo'] ??
                n.payload['body'] ??
                n.tipo;
            let marcarEnviada = true;
            if (tokens.length > 0 && this.fcm.estaListo()) {
                const data = {};
                for (const [k, v] of Object.entries(n.payload)) {
                    if (v != null && typeof v !== 'object')
                        data[k] = String(v);
                }
                data['tipo'] = n.tipo;
                const res = await this.fcm.enviarMulticast(tokens, { title: titulo, body: cuerpo }, data);
                marcarEnviada = res.enviados > 0;
                enviados += res.enviados;
                this.log.log(`FCM ${n.tipo}: ${res.enviados} enviados, ${res.fallos} fallos`);
                if (!marcarEnviada && res.fallos > 0) {
                    this.log.warn(`FCM ${n.tipo}: todos los tokens fallaron (${res.fallos}) — se reintentará`);
                }
            }
            else if (!tokens.length) {
                this.log.debug(`FCM ${n.tipo}: sin tokens registrados`);
            }
            else {
                marcarEnviada = false;
                this.log.warn(`FCM ${n.tipo}: Firebase Admin no listo — se reintentará en cola`);
            }
            if (marcarEnviada) {
                await this.database.consultar(`UPDATE notificaciones_pendientes SET enviada = true WHERE id = $1`, [n.id]);
            }
            else {
                const fila = await this.database.consultarUno(`UPDATE notificaciones_pendientes
           SET intentos = intentos + 1,
               abandonada = (intentos + 1 >= $2)
           WHERE id = $1
           RETURNING intentos, abandonada`, [n.id, maxIntentos]);
                if (fila?.abandonada) {
                    abandonadas += 1;
                    this.log.warn(`FCM ${n.tipo}: abandonada tras ${fila.intentos} intentos (máx ${maxIntentos})`);
                }
            }
        }
        return {
            procesadas: pendientes.length,
            enviados,
            abandonadas,
            modo: this.fcm.estaListo() ? 'fcm' : 'sin_admin',
        };
    }
    async diagnostico() {
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS n FROM notificaciones_pendientes
       WHERE enviada = false AND abandonada = false`);
        const aband = await this.database.consultarUno(`SELECT COUNT(*)::text AS n FROM notificaciones_pendientes
       WHERE abandonada = true
         AND created_at > now() - interval '24 hours'`);
        const webStaff = await this.database.consultarUno(`SELECT COUNT(*)::text AS n FROM tokens_push_admin
       WHERE activo = true AND plataforma = 'web'`);
        const webCliente = await this.database.consultarUno(`SELECT COUNT(*)::text AS n FROM dispositivos_cliente
       WHERE anonimizado = false AND fcm_token IS NOT NULL AND plataforma = 'web'`);
        const webDomi = await this.database.consultarUno(`SELECT COUNT(*)::text AS n FROM tokens_push_domiciliario
       WHERE activo = true AND plataforma = 'web'`);
        return {
            firebase_admin: this.fcm.estaListo(),
            pendientes: Number(fila?.n ?? 0),
            abandonadas_24h: Number(aband?.n ?? 0),
            max_intentos: this.maxIntentosFcm(),
            tokens_web_staff: Number(webStaff?.n ?? 0),
            tokens_web_cliente: Number(webCliente?.n ?? 0),
            tokens_web_domiciliario: Number(webDomi?.n ?? 0),
        };
    }
    async purgarHistorialCrecimiento(opciones) {
        const diasCola = opciones?.diasCola ?? 14;
        const diasAuditoria = opciones?.diasAuditoria ?? 90;
        const cola = await this.database.consultarUno(`WITH borradas AS (
         DELETE FROM notificaciones_pendientes
         WHERE (enviada = true OR abandonada = true)
           AND created_at < now() - make_interval(days => $1)
         RETURNING 1
       )
       SELECT COUNT(*)::text AS n FROM borradas`, [diasCola]);
        const auditoria = await this.database.consultarUno(`WITH borradas AS (
         DELETE FROM auditoria_logs
         WHERE created_at < now() - make_interval(days => $1)
         RETURNING 1
       )
       SELECT COUNT(*)::text AS n FROM borradas`, [diasAuditoria]);
        return {
            cola: Number(cola?.n ?? 0),
            auditoria: Number(auditoria?.n ?? 0),
        };
    }
    async enviarPruebaWeb(opciones) {
        const tokens = new Set();
        if (opciones?.usuario_id && !opciones.todos_web) {
            if (opciones.rol === 'domiciliario_independiente') {
                const filas = await this.database.consultar(`SELECT fcm_token FROM tokens_push_domiciliario
           WHERE domiciliario_id = $1 AND activo = true AND plataforma = 'web'`, [opciones.usuario_id]);
                for (const f of filas)
                    tokens.add(f.fcm_token);
            }
            else {
                const filas = await this.database.consultar(`SELECT fcm_token FROM tokens_push_admin
           WHERE usuario_id = $1 AND activo = true AND plataforma = 'web'`, [opciones.usuario_id]);
                for (const f of filas)
                    tokens.add(f.fcm_token);
            }
            if (!tokens.size) {
                return {
                    enviados: 0,
                    tokens_web: 0,
                    mensaje: 'Sin tokens web propios para prueba',
                };
            }
        }
        else if (opciones?.todos_web) {
            const staff = await this.database.consultar(`SELECT fcm_token FROM tokens_push_admin
         WHERE activo = true AND plataforma = 'web'`);
            const clientes = await this.database.consultar(`SELECT fcm_token FROM dispositivos_cliente
         WHERE anonimizado = false AND fcm_token IS NOT NULL AND plataforma = 'web'`);
            const domi = await this.database.consultar(`SELECT fcm_token FROM tokens_push_domiciliario
         WHERE activo = true AND plataforma = 'web'`);
            for (const f of [...staff, ...clientes, ...domi])
                tokens.add(f.fcm_token);
        }
        const lista = [...tokens];
        if (!lista.length) {
            return {
                enviados: 0,
                tokens_web: 0,
                mensaje: 'Sin tokens web registrados. Abre Foody en Chrome, acepta notificaciones y recarga.',
            };
        }
        if (!this.fcm.estaListo()) {
            return {
                enviados: 0,
                tokens_web: lista.length,
                mensaje: 'Firebase Admin no inicializado en el backend',
            };
        }
        const res = await this.fcm.enviarMulticast(lista, {
            title: 'Foody — prueba WEB',
            body: 'Push web operativo ✅ (Chrome)',
        }, {
            tipo: 'prueba_foody_web',
            ruta: '/',
        });
        this.log.log(`FCM prueba-web: ${res.enviados} enviados, ${res.fallos} fallos (${lista.length} tokens)`);
        return {
            enviados: res.enviados,
            fallos: res.fallos,
            tokens_web: lista.length,
            modo: 'fcm',
        };
    }
    async _resolverTokens(n) {
        const tokens = new Set();
        if (n.destinatario_usuario_id) {
            const filas = await this.database.consultar(`SELECT fcm_token FROM tokens_push_admin
         WHERE usuario_id = $1 AND activo = true`, [n.destinatario_usuario_id]);
            for (const f of filas)
                tokens.add(f.fcm_token);
        }
        const domiciliarioId = n.payload['domiciliario_id'];
        if (domiciliarioId) {
            const filas = await this.database.consultar(`SELECT fcm_token FROM tokens_push_domiciliario
         WHERE domiciliario_id = $1 AND activo = true`, [domiciliarioId]);
            for (const f of filas)
                tokens.add(f.fcm_token);
        }
        const deviceId = n.payload['device_id'];
        if (deviceId) {
            const fila = await this.database.consultarUno(`SELECT fcm_token FROM dispositivos_cliente
         WHERE device_id = $1 AND anonimizado = false AND fcm_token IS NOT NULL`, [deviceId]);
            if (fila?.fcm_token)
                tokens.add(fila.fcm_token);
        }
        const roles = n.payload['roles'];
        if (roles?.length && n.sucursal_id) {
            const incluyeCocina = roles.includes('cocina');
            const rolesExactos = roles.filter((r) => r !== 'cocina');
            const filas = await this.database.consultar(`SELECT DISTINCT t.fcm_token
         FROM tokens_push_admin t
         INNER JOIN usuarios u ON u.id = t.usuario_id
         WHERE u.sucursal_id = $1
           AND u.activo = true
           AND t.activo = true
           AND (
             (cardinality($2::text[]) > 0 AND u.rol = ANY($2::text[]))
             OR ($3::boolean AND u.rol LIKE 'cocina%')
           )`, [n.sucursal_id, rolesExactos, incluyeCocina]);
            for (const f of filas)
                tokens.add(f.fcm_token);
        }
        return [...tokens];
    }
};
exports.NotificacionesService = NotificacionesService;
exports.NotificacionesService = NotificacionesService = NotificacionesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        fcm_service_1.FcmService])
], NotificacionesService);
//# sourceMappingURL=notificaciones.service.js.map