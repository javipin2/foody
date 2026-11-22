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
const auth_service_1 = require("../../core/auth/auth.service");
const database_service_1 = require("../../core/database/database.service");
const plan_features_service_1 = require("../../core/auth/plan-features.service");
const registro_antispike_1 = require("../../core/auth/registro-antispike");
const roles_food_1 = require("../../core/auth/roles-food");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const crear_usuario_dto_1 = require("./dto/crear-usuario.dto");
const paginacion_dto_1 = require("../../compartido/dto/paginacion.dto");
const ROLES_NO_EDITABLES = new Set(['admin', 'super_admin']);
let UsuariosService = class UsuariosService {
    database;
    planFeatures;
    authService;
    sucursalScope;
    constructor(database, planFeatures, authService, sucursalScope) {
        this.database = database;
        this.planFeatures = planFeatures;
        this.authService = authService;
        this.sucursalScope = sucursalScope;
    }
    async listarPorSucursal(sucursalId, query = {}) {
        const opts = (0, paginacion_dto_1.opcionesListado)(query, 50);
        const select = `SELECT u.id, u.nombre, u.email, u.rol, u.activo, u.telefono,
              u.cocina_id, c.nombre AS cocina_nombre,
              u.ultimo_acceso, u.created_at,
              dp.id IS NOT NULL AS es_domiciliario_planta
       FROM usuarios u
       LEFT JOIN domiciliarios_planta dp ON dp.usuario_id = u.id AND dp.activo = true
       LEFT JOIN cocinas c ON c.id = u.cocina_id
       WHERE u.sucursal_id = $1
         AND u.rol <> 'super_admin'`;
        if (!opts.paginar) {
            return this.database.consultar(`${select}
       ORDER BY u.nombre
       LIMIT $2`, [sucursalId, opts.limite]);
        }
        const { page, limit, offset } = (0, paginacion_dto_1.resolverPaginacion)(opts.page, opts.limite, 50);
        const [items, totalRow] = await Promise.all([
            this.database.consultar(`${select}
       ORDER BY u.nombre
       LIMIT $2 OFFSET $3`, [sucursalId, limit, offset]),
            this.database.consultarUno(`SELECT COUNT(*)::int AS count FROM usuarios
         WHERE sucursal_id = $1 AND rol <> 'super_admin'`, [sucursalId]),
        ]);
        return (0, paginacion_dto_1.envolverPaginado)(items, totalRow?.count ?? 0, page, limit);
    }
    async listarMeserosActivos(sucursalId) {
        return this.database.consultar(`SELECT u.id, u.nombre
       FROM usuarios u
       WHERE u.sucursal_id = $1
         AND u.rol = 'mesero'
         AND u.activo = true
       ORDER BY u.nombre`, [sucursalId]);
    }
    async crear(dto, actor) {
        await this.sucursalScope.assertPerteneceRestaurante(dto.sucursal_id, actor.restaurante_id);
        if (!this.sucursalScope.esCorporativo(actor) &&
            dto.sucursal_id !== actor.sucursal_id) {
            throw new common_1.ForbiddenException('Solo puedes crear usuarios en tu sucursal asignada');
        }
        if (dto.rol === roles_food_1.ROL_GERENTE_CADENA &&
            !this.sucursalScope.esCorporativo(actor)) {
            throw new common_1.ForbiddenException('Solo usuarios corporativos pueden crear un gerente de cadena');
        }
        const sucursal = await this.database.consultarUno(`SELECT restaurante_id FROM sucursales WHERE id = $1 AND activa = true`, [dto.sucursal_id]);
        if (!sucursal) {
            throw new common_1.BadRequestException('Sucursal no válida');
        }
        await this.planFeatures.assertLimiteUsuariosStaff(sucursal.restaurante_id);
        const cocinaId = await this.resolverCocinaIdParaRol(dto.rol, dto.sucursal_id, dto.cocina_id);
        const existe = await this.database.consultarUno(`SELECT id FROM usuarios WHERE LOWER(email) = LOWER($1)`, [dto.email.trim()]);
        if (existe) {
            throw new common_1.ConflictException('El correo ya está registrado');
        }
        const hash = await bcrypt.hash(dto.contrasena, (0, registro_antispike_1.bcryptRoundsRegistro)());
        return this.database.enTransaccion(async (client) => {
            const insert = await client.query(`INSERT INTO usuarios (
           id, sucursal_id, restaurante_id, nombre, email, rol, activo, hash_contrasena, cocina_id
         ) VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, true, $6, $7)
         RETURNING id`, [
                dto.sucursal_id,
                sucursal.restaurante_id,
                dto.nombre.trim(),
                dto.email.trim().toLowerCase(),
                dto.rol,
                hash,
                cocinaId,
            ]);
            const usuarioId = insert.rows[0].id;
            if (dto.rol === 'domiciliario_planta') {
                await client.query(`INSERT INTO domiciliarios_planta (usuario_id, sucursal_id, activo)
           VALUES ($1, $2, true)`, [usuarioId, dto.sucursal_id]);
            }
            let permisos = await this.authService.permisosDelRol(dto.rol);
            if (dto.permisos !== undefined) {
                permisos = await this.authService.reemplazarPermisosUsuario(usuarioId, dto.rol, dto.permisos, client);
            }
            return {
                id: usuarioId,
                nombre: dto.nombre.trim(),
                email: dto.email.trim().toLowerCase(),
                rol: dto.rol,
                cocina_id: cocinaId,
                activo: true,
                permisos,
            };
        });
    }
    async resolverCocinaIdParaRol(rol, sucursalId, cocinaId) {
        if (!(0, roles_food_1.esRolCocina)(rol)) {
            return null;
        }
        if (!cocinaId) {
            throw new common_1.BadRequestException('El rol Cocina requiere asignar una estación de cocina');
        }
        const cocina = await this.database.consultarUno(`SELECT id FROM cocinas
       WHERE id = $1 AND sucursal_id = $2 AND activa = true`, [cocinaId, sucursalId]);
        if (!cocina) {
            throw new common_1.BadRequestException('Cocina no válida para esta sucursal');
        }
        return cocina.id;
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
    async catalogoRolesPermisos() {
        const filas = await this.database.consultar(`SELECT rol, permiso FROM roles_permisos
       WHERE rol = ANY($1::text[])
       ORDER BY rol, permiso`, [[...crear_usuario_dto_1.ROLES_STAFF_ASIGNABLES]]);
        const mapa = new Map();
        for (const f of filas) {
            const lista = mapa.get(f.rol) ?? [];
            lista.push(f.permiso);
            mapa.set(f.rol, lista);
        }
        const permisosDisponibles = await this.authService.catalogoPermisosDisponibles();
        return {
            roles: crear_usuario_dto_1.ROLES_STAFF_ASIGNABLES.map((rol) => ({
                rol,
                permisos: mapa.get(rol) ?? [],
            })),
            permisos_disponibles: permisosDisponibles,
        };
    }
    async permisosDeUsuario(usuarioId, sucursalId) {
        const u = await this.database.consultarUno(`SELECT id, rol FROM usuarios
       WHERE id = $1 AND sucursal_id = $2 AND rol <> 'super_admin'`, [usuarioId, sucursalId]);
        if (!u) {
            throw new common_1.NotFoundException('Usuario no encontrado');
        }
        const personalizado = await this.authService.tienePermisosPersonalizados(usuarioId);
        const permisos = await this.authService.permisosEfectivos(usuarioId, u.rol);
        const plantilla = await this.authService.permisosDelRol(u.rol);
        return {
            usuario_id: usuarioId,
            rol: u.rol,
            personalizado,
            permisos,
            plantilla_rol: plantilla,
        };
    }
    async actualizar(usuarioId, sucursalContexto, dto, actor) {
        if (dto.rol === roles_food_1.ROL_GERENTE_CADENA &&
            !this.sucursalScope.esCorporativo(actor)) {
            throw new common_1.ForbiddenException('Solo usuarios corporativos pueden asignar gerente de cadena');
        }
        if (dto.sucursal_id && dto.sucursal_id !== sucursalContexto) {
            if (!this.sucursalScope.esCorporativo(actor)) {
                throw new common_1.ForbiddenException('Solo usuarios corporativos pueden mover staff a otra sucursal');
            }
            await this.sucursalScope.assertPerteneceRestaurante(dto.sucursal_id, actor.restaurante_id);
        }
        if (!dto.nombre?.trim() &&
            !dto.rol &&
            !dto.sucursal_id &&
            dto.cocina_id === undefined &&
            dto.permisos === undefined) {
            throw new common_1.BadRequestException('Indica nombre, rol, sucursal, cocina o permisos a actualizar');
        }
        const actorId = actor.sub;
        const actual = await this.database.consultarUno(`SELECT id, rol, sucursal_id, restaurante_id, nombre, cocina_id
       FROM usuarios
       WHERE id = $1 AND sucursal_id = $2 AND rol <> 'super_admin'`, [usuarioId, sucursalContexto]);
        if (!actual) {
            throw new common_1.NotFoundException('Usuario no encontrado');
        }
        if (ROLES_NO_EDITABLES.has(actual.rol)) {
            throw new common_1.ForbiddenException('No puedes editar el rol del administrador principal');
        }
        if (dto.rol && dto.rol !== actual.rol && usuarioId === actorId) {
            throw new common_1.ForbiddenException('No puedes cambiar tu propio rol');
        }
        const nuevaSucursal = dto.sucursal_id ?? actual.sucursal_id;
        if (nuevaSucursal !== actual.sucursal_id) {
            const suc = await this.database.consultarUno(`SELECT id FROM sucursales
         WHERE id = $1 AND restaurante_id = $2 AND activa = true`, [nuevaSucursal, actual.restaurante_id]);
            if (!suc) {
                throw new common_1.BadRequestException('Sucursal destino no válida');
            }
        }
        const nuevoRolRaw = dto.rol ?? actual.rol;
        const nuevoRol = (0, roles_food_1.esRolCocina)(nuevoRolRaw) ? 'cocina' : nuevoRolRaw;
        const nombre = dto.nombre?.trim() ?? actual.nombre;
        const cocinaId = await this.resolverCocinaIdParaRol(nuevoRol, nuevaSucursal, dto.cocina_id !== undefined ? dto.cocina_id : actual.cocina_id);
        return this.database.enTransaccion(async (client) => {
            const upd = await client.query(`UPDATE usuarios SET
           nombre = $3,
           rol = $4,
           sucursal_id = $5,
           cocina_id = $6
         WHERE id = $1 AND sucursal_id = $2
         RETURNING id, nombre, email, rol, activo, sucursal_id, cocina_id`, [
                usuarioId,
                sucursalContexto,
                nombre,
                nuevoRol,
                nuevaSucursal,
                cocinaId,
            ]);
            if (!upd.rows[0]) {
                throw new common_1.NotFoundException('Usuario no encontrado');
            }
            if (actual.rol === 'domiciliario_planta' && nuevoRol !== 'domiciliario_planta') {
                await client.query(`UPDATE domiciliarios_planta SET activo = false WHERE usuario_id = $1`, [usuarioId]);
            }
            if (nuevoRol === 'domiciliario_planta') {
                const dp = await client.query(`SELECT id FROM domiciliarios_planta WHERE usuario_id = $1 LIMIT 1`, [usuarioId]);
                if (dp.rows[0]) {
                    await client.query(`UPDATE domiciliarios_planta SET sucursal_id = $2, activo = true WHERE usuario_id = $1`, [usuarioId, nuevaSucursal]);
                }
                else {
                    await client.query(`INSERT INTO domiciliarios_planta (usuario_id, sucursal_id, activo)
             VALUES ($1, $2, true)`, [usuarioId, nuevaSucursal]);
                }
            }
            let permisos;
            if (dto.permisos !== undefined) {
                permisos = await this.authService.reemplazarPermisosUsuario(usuarioId, nuevoRol, dto.permisos, client);
            }
            else if (dto.rol && dto.rol !== actual.rol) {
                await client.query(`DELETE FROM usuario_permisos WHERE usuario_id = $1`, [usuarioId]);
                permisos = await this.authService.permisosDelRol(nuevoRol);
            }
            else {
                permisos = await this.authService.permisosEfectivos(usuarioId, nuevoRol);
            }
            return { ...upd.rows[0], permisos };
        });
    }
};
exports.UsuariosService = UsuariosService;
exports.UsuariosService = UsuariosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        plan_features_service_1.PlanFeaturesService,
        auth_service_1.AuthService,
        sucursal_scope_service_1.SucursalScopeService])
], UsuariosService);
//# sourceMappingURL=usuarios.service.js.map