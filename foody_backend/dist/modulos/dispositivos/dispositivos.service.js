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
exports.DispositivosService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const supabase_auth_service_1 = require("../../core/auth/supabase-auth.service");
let DispositivosService = class DispositivosService {
    database;
    supabaseAuth;
    constructor(database, supabaseAuth) {
        this.database = database;
        this.supabaseAuth = supabaseAuth;
    }
    async registrar(datos) {
        await this.database.consultar(`INSERT INTO dispositivos_cliente (device_id, fcm_token, ciudad_id, plataforma, ultimo_acceso)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (device_id) DO UPDATE SET
         fcm_token = COALESCE(EXCLUDED.fcm_token, dispositivos_cliente.fcm_token),
         ciudad_id = COALESCE(EXCLUDED.ciudad_id, dispositivos_cliente.ciudad_id),
         plataforma = COALESCE(EXCLUDED.plataforma, dispositivos_cliente.plataforma),
         ultimo_acceso = now()
       WHERE dispositivos_cliente.anonimizado = false`, [
            datos.device_id,
            datos.fcm_token ?? null,
            datos.ciudad_id ?? null,
            datos.plataforma ?? 'android',
        ]);
        return { device_id: datos.device_id, registrado: true };
    }
    async vincularAuth(datos) {
        const deviceId = datos.device_id?.trim();
        if (!deviceId) {
            throw new common_1.BadRequestException('device_id es obligatorio');
        }
        const user = await this.supabaseAuth.usuarioDesdeAccessToken(datos.access_token);
        const authUid = user.id;
        await this.database.consultar(`INSERT INTO dispositivos_cliente (device_id, auth_uid, ultimo_acceso, plataforma)
       VALUES ($1, $2::uuid, now(), 'android')
       ON CONFLICT (device_id) DO UPDATE SET
         auth_uid = EXCLUDED.auth_uid,
         ultimo_acceso = now()
       WHERE dispositivos_cliente.anonimizado = false`, [deviceId, authUid]);
        const reclamados = await this.database.consultarUno(`WITH u AS (
         UPDATE pedidos
         SET cliente_auth_uid = $2::uuid
         WHERE device_id = $1
           AND (cliente_auth_uid IS NULL OR cliente_auth_uid = $2::uuid)
         RETURNING id
       )
       SELECT count(*)::text AS n FROM u`, [deviceId, authUid]);
        return {
            device_id: deviceId,
            auth_uid: authUid,
            email: user.email ?? null,
            nombre: user.user_metadata?.['full_name'] ??
                user.user_metadata?.['name'] ??
                null,
            pedidos_vinculados: Number(reclamados?.n ?? 0),
        };
    }
    async verificarPosesionParaAnonimizar(deviceId, prueba) {
        const fila = await this.database.consultarUno(`SELECT fcm_token, auth_uid, anonimizado FROM dispositivos_cliente
       WHERE device_id = $1`, [deviceId]);
        if (!fila || fila.anonimizado)
            return false;
        if (prueba.fcm_token && fila.fcm_token && prueba.fcm_token === fila.fcm_token) {
            return true;
        }
        if (prueba.access_token && fila.auth_uid) {
            try {
                const user = await this.supabaseAuth.usuarioDesdeAccessToken(prueba.access_token);
                return !!user?.id && user.id === fila.auth_uid;
            }
            catch {
                return false;
            }
        }
        return false;
    }
    async anonimizar(deviceId) {
        const fila = await this.database.consultarUno(`UPDATE dispositivos_cliente
       SET fcm_token = NULL,
           ciudad_id = NULL,
           auth_uid = NULL,
           anonimizado = true,
           anonimizado_at = now()
       WHERE device_id = $1 AND anonimizado = false
       RETURNING device_id`, [deviceId]);
        if (!fila) {
            return { device_id: deviceId, anonimizado: false, motivo: 'no_encontrado' };
        }
        return { device_id: deviceId, anonimizado: true };
    }
};
exports.DispositivosService = DispositivosService;
exports.DispositivosService = DispositivosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        supabase_auth_service_1.SupabaseAuthService])
], DispositivosService);
//# sourceMappingURL=dispositivos.service.js.map