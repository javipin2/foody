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
exports.RestaurantesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const plan_features_service_1 = require("../../core/auth/plan-features.service");
let RestaurantesService = class RestaurantesService {
    database;
    planFeatures;
    constructor(database, planFeatures) {
        this.database = database;
        this.planFeatures = planFeatures;
    }
    async listarSucursales(restauranteId) {
        const existe = await this.database.consultarUno(`SELECT id FROM restaurantes WHERE id = $1 AND activo = true`, [restauranteId]);
        if (!existe) {
            throw new common_1.NotFoundException('Restaurante no encontrado');
        }
        return this.database.consultar(`SELECT s.id, s.nombre, s.direccion, s.lat, s.lng, s.activa, s.ciudad_id, c.nombre AS ciudad_nombre
       FROM sucursales s
       LEFT JOIN ciudades c ON c.id = s.ciudad_id
       WHERE s.restaurante_id = $1 AND s.activa = true
       ORDER BY s.nombre ASC`, [restauranteId]);
    }
    async listarSucursalesStaff(restauranteId, usuarioRestauranteId) {
        if (restauranteId !== usuarioRestauranteId) {
            throw new common_1.ForbiddenException('No puedes ver sucursales de otro restaurante');
        }
        return this.listarSucursales(restauranteId);
    }
    async crearSucursal(restauranteId, usuarioRestauranteId, dto) {
        if (restauranteId !== usuarioRestauranteId) {
            throw new common_1.ForbiddenException('No puedes crear sucursales en otro restaurante');
        }
        await this.planFeatures.assertLimiteSucursales(restauranteId);
        const restaurante = await this.database.consultarUno(`SELECT id, ciudad_id FROM restaurantes WHERE id = $1 AND activo = true`, [restauranteId]);
        if (!restaurante)
            throw new common_1.NotFoundException('Restaurante no encontrado');
        const ciudadId = dto.ciudad_id ?? restaurante.ciudad_id;
        return this.database.enTransaccion(async (client) => {
            const insert = await client.query(`INSERT INTO sucursales (
           restaurante_id, ciudad_id, nombre, direccion, telefono, activa
         ) VALUES ($1, $2, $3, $4, $5, true)
         RETURNING id`, [
                restauranteId,
                ciudadId,
                dto.nombre.trim(),
                dto.direccion?.trim() ?? null,
                dto.telefono?.trim() ?? null,
            ]);
            const sucursalId = insert.rows[0].id;
            await client.query(`INSERT INTO cocinas (sucursal_id, nombre) VALUES ($1, 'Cocina principal')`, [sucursalId]);
            await client.query(`INSERT INTO horarios_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, activo)
         SELECT $1, d, '08:00', '22:00', true FROM generate_series(0, 6) AS d`, [sucursalId]);
            return {
                id: sucursalId,
                nombre: dto.nombre.trim(),
                restaurante_id: restauranteId,
                ciudad_id: ciudadId,
            };
        });
    }
    async exigirSucursalDelRestaurante(sucursalId, restauranteId) {
        const sucursal = await this.database.consultarUno(`SELECT id FROM sucursales
       WHERE id = $1 AND restaurante_id = $2 AND activa = true`, [sucursalId, restauranteId]);
        if (!sucursal) {
            throw new common_1.NotFoundException('Sucursal no encontrada');
        }
        return sucursal;
    }
    async listarHorarios(sucursalId, restauranteId) {
        await this.exigirSucursalDelRestaurante(sucursalId, restauranteId);
        return this.database.consultar(`SELECT id, dia_semana, hora_apertura::text, hora_cierre::text, activo
       FROM horarios_sucursal
       WHERE sucursal_id = $1
       ORDER BY dia_semana ASC`, [sucursalId]);
    }
    async actualizarHorario(horarioId, restauranteId, dto) {
        const fila = await this.database.consultarUno(`UPDATE horarios_sucursal h
       SET hora_apertura = COALESCE($2::time, h.hora_apertura),
           hora_cierre = COALESCE($3::time, h.hora_cierre),
           activo = COALESCE($4, h.activo)
       FROM sucursales s
       WHERE h.id = $1
         AND h.sucursal_id = s.id
         AND s.restaurante_id = $5
       RETURNING h.id, h.dia_semana, h.hora_apertura::text, h.hora_cierre::text, h.activo`, [
            horarioId,
            dto.hora_apertura ?? null,
            dto.hora_cierre ?? null,
            dto.activo ?? null,
            restauranteId,
        ]);
        if (!fila) {
            throw new common_1.NotFoundException('Horario no encontrado');
        }
        return fila;
    }
};
exports.RestaurantesService = RestaurantesService;
exports.RestaurantesService = RestaurantesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        plan_features_service_1.PlanFeaturesService])
], RestaurantesService);
//# sourceMappingURL=restaurantes.service.js.map