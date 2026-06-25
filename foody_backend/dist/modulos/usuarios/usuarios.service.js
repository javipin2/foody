"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UsuariosService = void 0;
const common_1 = require("@nestjs/common");
const bcrypt = __importStar(require("bcrypt"));
const database_service_1 = require("../../core/database/database.service");
const plan_features_service_1 = require("../../core/auth/plan-features.service");
let UsuariosService = class UsuariosService {
    database;
    planFeatures;
    constructor(database, planFeatures) {
        this.database = database;
        this.planFeatures = planFeatures;
    }
    async listarPorSucursal(sucursalId) {
        return this.database.consultar(`SELECT u.id, u.nombre, u.email, u.rol, u.activo, u.telefono,
              u.ultimo_acceso, u.created_at,
              dp.id IS NOT NULL AS es_domiciliario_planta
       FROM usuarios u
       LEFT JOIN domiciliarios_planta dp ON dp.usuario_id = u.id AND dp.activo = true
       WHERE u.sucursal_id = $1
         AND u.rol <> 'super_admin'
       ORDER BY u.nombre`, [sucursalId]);
    }
    async crear(dto) {
        const sucursal = await this.database.consultarUno(`SELECT restaurante_id FROM sucursales WHERE id = $1 AND activa = true`, [dto.sucursal_id]);
        if (!sucursal) {
            throw new common_1.BadRequestException('Sucursal no válida');
        }
        await this.planFeatures.assertLimiteUsuariosStaff(sucursal.restaurante_id);
        const existe = await this.database.consultarUno(`SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1)`, [dto.email.trim()]);
        if (existe) {
            throw new common_1.ConflictException('El correo ya está registrado');
        }
        const hash = await bcrypt.hash(dto.contrasena, 10);
        return this.database.enTransaccion(async (client) => {
            const insert = await client.query(`INSERT INTO usuarios (
           id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena
         ) VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, true, $6)
         RETURNING id`, [
                dto.sucursal_id,
                sucursal.restaurante_id,
                dto.nombre.trim(),
                dto.email.trim().toLowerCase(),
                dto.rol,
                hash,
            ]);
            const usuarioId = insert.rows[0].id;
            if (dto.rol === 'domiciliario_planta') {
                await client.query(`INSERT INTO domiciliarios_planta (usuario_id, sucursal_id, activo)
           VALUES ($1, $2, true)`, [usuarioId, dto.sucursal_id]);
            }
            return {
                id: usuarioId,
                nombre: dto.nombre.trim(),
                email: dto.email.trim().toLowerCase(),
                rol: dto.rol,
                activo: true,
            };
        });
    }
    async cambiarEstado(usuarioId, sucursalId, dto) {
        const fila = await this.database.consultarUno(`UPDATE usuarios
       SET activo = $3
       WHERE id = $1 AND sucursal_id = $2 AND rol <> 'super_admin'
       RETURNING id, rol`, [usuarioId, sucursalId, dto.activo]);
        if (!fila) {
            throw new common_1.NotFoundException('Usuario no encontrado');
        }
        if (fila.rol === 'domiciliario_planta') {
            await this.database.consultar(`UPDATE domiciliarios_planta SET activo = $2 WHERE usuario_id = $1`, [usuarioId, dto.activo]);
        }
        return { id: usuarioId, activo: dto.activo };
    }
};
exports.UsuariosService = UsuariosService;
exports.UsuariosService = UsuariosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        plan_features_service_1.PlanFeaturesService])
], UsuariosService);
//# sourceMappingURL=usuarios.service.js.map