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
exports.PlanFeaturesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
const plan_features_config_1 = require("./plan-features.config");
let PlanFeaturesService = class PlanFeaturesService {
    database;
    constructor(database) {
        this.database = database;
    }
    async obtenerPlanRestaurante(restauranteId) {
        if (!restauranteId)
            return 'basico';
        const fila = await this.database.consultarUno(`SELECT plan FROM suscripciones_restaurante
       WHERE restaurante_id = $1
       LIMIT 1`, [restauranteId]);
        return (0, plan_features_config_1.normalizarPlan)(fila?.plan);
    }
    modulosDelPlan(plan) {
        return (0, plan_features_config_1.modulosDelPlan)(plan);
    }
    incluyeModulo(plan, modulo) {
        return (0, plan_features_config_1.planIncluyeModulo)(plan, modulo);
    }
    async assertLimiteSucursales(restauranteId) {
        const plan = (0, plan_features_config_1.normalizarPlan)(await this.obtenerPlanRestaurante(restauranteId));
        const limite = plan_features_config_1.LIMITES_POR_PLAN[plan].max_sucursales;
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM sucursales
       WHERE restaurante_id = $1 AND activa = true`, [restauranteId]);
        const actual = Number(fila?.total ?? 0);
        if (actual >= limite) {
            throw new common_1.ForbiddenException({
                error: 'PLAN_LIMITE_EXCEDIDO',
                message: `Tu plan «${plan}» permite hasta ${limite} sucursal(es). Actualiza el plan para crear más.`,
                limite,
                actual,
            });
        }
    }
    async assertLimiteUsuariosStaff(restauranteId) {
        const plan = (0, plan_features_config_1.normalizarPlan)(await this.obtenerPlanRestaurante(restauranteId));
        const limite = plan_features_config_1.LIMITES_POR_PLAN[plan].max_usuarios_staff;
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM usuarios
       WHERE restaurante_id = $1 AND activo = true
         AND rol NOT IN ('super_admin', 'domiciliario_independiente')`, [restauranteId]);
        const actual = Number(fila?.total ?? 0);
        if (actual >= limite) {
            throw new common_1.ForbiddenException({
                error: 'PLAN_LIMITE_EXCEDIDO',
                message: `Tu plan «${plan}» permite hasta ${limite} usuarios staff. Actualiza el plan para invitar más.`,
                limite,
                actual,
            });
        }
    }
    async assertLimiteMesas(restauranteId, sucursalId) {
        const plan = (0, plan_features_config_1.normalizarPlan)(await this.obtenerPlanRestaurante(restauranteId));
        const limite = plan_features_config_1.LIMITES_POR_PLAN[plan].max_mesas;
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM mesas
       WHERE sucursal_id = $1 AND activa = true`, [sucursalId]);
        const actual = Number(fila?.total ?? 0);
        if (actual >= limite) {
            throw new common_1.ForbiddenException({
                error: 'PLAN_LIMITE_EXCEDIDO',
                message: `Tu plan «${plan}» permite hasta ${limite} mesas activas. Actualiza el plan para agregar más.`,
                limite,
                actual,
            });
        }
    }
    async assertLimiteProductos(restauranteId, sucursalId) {
        const plan = (0, plan_features_config_1.normalizarPlan)(await this.obtenerPlanRestaurante(restauranteId));
        const limite = plan_features_config_1.LIMITES_POR_PLAN[plan].max_productos;
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM productos
       WHERE sucursal_id = $1`, [sucursalId]);
        const actual = Number(fila?.total ?? 0);
        if (actual >= limite) {
            throw new common_1.ForbiddenException({
                error: 'PLAN_LIMITE_EXCEDIDO',
                message: `Tu plan «${plan}» permite hasta ${limite} productos activos. Actualiza el plan para agregar más.`,
                limite,
                actual,
            });
        }
    }
    async assertLimiteIngredientes(restauranteId, sucursalId) {
        const plan = (0, plan_features_config_1.normalizarPlan)(await this.obtenerPlanRestaurante(restauranteId));
        const limite = plan_features_config_1.LIMITES_POR_PLAN[plan].max_ingredientes;
        const fila = await this.database.consultarUno(`SELECT COUNT(*)::text AS total FROM ingredientes
       WHERE sucursal_id = $1 AND activo = true`, [sucursalId]);
        const actual = Number(fila?.total ?? 0);
        if (actual >= limite) {
            throw new common_1.ForbiddenException({
                error: 'PLAN_LIMITE_EXCEDIDO',
                message: `Tu plan «${plan}» permite hasta ${limite} ingredientes/insumos activos. Actualiza el plan para agregar más.`,
                limite,
                actual,
            });
        }
    }
};
exports.PlanFeaturesService = PlanFeaturesService;
exports.PlanFeaturesService = PlanFeaturesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], PlanFeaturesService);
//# sourceMappingURL=plan-features.service.js.map