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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CosteoController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const plan_features_guard_1 = require("../../core/auth/guards/plan-features.guard");
const requiere_modulo_decorator_1 = require("../../compartido/decoradores/requiere-modulo.decorator");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const costeo_service_1 = require("./costeo.service");
const actualizar_subreceta_dto_1 = require("./dto/actualizar-subreceta.dto");
const crear_subreceta_dto_1 = require("./dto/crear-subreceta.dto");
let CosteoController = class CosteoController {
    costeo;
    constructor(costeo) {
        this.costeo = costeo;
    }
    resumen(sucursalId) {
        return this.costeo.resumenSucursal(sucursalId);
    }
    subrecetaDetalle(recetaId, sucursalId) {
        return this.costeo.obtenerSubrecetaDetalle(recetaId, sucursalId);
    }
    subrecetas(sucursalId) {
        return this.costeo.listarSubrecetas(sucursalId);
    }
    combos(sucursalId) {
        return this.costeo.listarCombos(sucursalId);
    }
    recalcular(sucursalId) {
        return this.costeo.recalcularSucursal(sucursalId);
    }
    impactoStock(productoId, sucursalId, cantidad) {
        const cant = cantidad != null ? Math.max(1, Number(cantidad) || 1) : 1;
        return this.costeo.impactoStockProducto(productoId, sucursalId, cant);
    }
    recalcularProducto(productoId, sucursalId) {
        return this.costeo.recalcularProductoPorId(productoId, sucursalId);
    }
    recalcularCombo(comboId, sucursalId) {
        return this.costeo.recalcularComboPorId(comboId, sucursalId);
    }
    crearSubreceta(dto) {
        return this.costeo.crearSubreceta(dto);
    }
    actualizarSubreceta(recetaId, dto) {
        return this.costeo.actualizarSubreceta(recetaId, dto);
    }
    recalcularSubreceta(recetaId, sucursalId) {
        return this.costeo.recalcularSubrecetaPorId(recetaId, sucursalId);
    }
};
exports.CosteoController = CosteoController;
__decorate([
    (0, common_1.Get)('resumen/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "resumen", null);
__decorate([
    (0, common_1.Get)('subrecetas/detalle/:id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "subrecetaDetalle", null);
__decorate([
    (0, common_1.Get)('subrecetas/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "subrecetas", null);
__decorate([
    (0, common_1.Get)('combos/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "combos", null);
__decorate([
    (0, common_1.Post)('recalcular/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "recalcular", null);
__decorate([
    (0, common_1.Get)('productos/:id/impacto-stock'),
    (0, permisos_decorator_1.Permisos)('ver_inventario'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __param(2, (0, common_1.Query)('cantidad')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "impactoStock", null);
__decorate([
    (0, common_1.Post)('productos/:id/recalcular'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "recalcularProducto", null);
__decorate([
    (0, common_1.Post)('combos/:id/recalcular'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "recalcularCombo", null);
__decorate([
    (0, common_1.Post)('subrecetas'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_subreceta_dto_1.CrearSubrecetaDto]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "crearSubreceta", null);
__decorate([
    (0, common_1.Patch)('subrecetas/:id'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, actualizar_subreceta_dto_1.ActualizarSubrecetaDto]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "actualizarSubreceta", null);
__decorate([
    (0, common_1.Post)('subrecetas/:id/recalcular'),
    (0, permisos_decorator_1.Permisos)('editar_inventario'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], CosteoController.prototype, "recalcularSubreceta", null);
exports.CosteoController = CosteoController = __decorate([
    (0, common_1.Controller)('costeo'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('costeo'),
    __metadata("design:paramtypes", [costeo_service_1.CosteoService])
], CosteoController);
//# sourceMappingURL=costeo.controller.js.map