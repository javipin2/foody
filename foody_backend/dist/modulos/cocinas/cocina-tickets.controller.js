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
exports.CocinaTicketsController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const plan_features_guard_1 = require("../../core/auth/guards/plan-features.guard");
const requiere_modulo_decorator_1 = require("../../compartido/decoradores/requiere-modulo.decorator");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const cocinas_service_1 = require("./cocinas.service");
const cocina_dto_1 = require("./dto/cocina.dto");
const item_kds_mutacion_dto_1 = require("./dto/item-kds-mutacion.dto");
let CocinaTicketsController = class CocinaTicketsController {
    cocinas;
    constructor(cocinas) {
        this.cocinas = cocinas;
    }
    listarCocinas(usuario) {
        return this.cocinas.listarCocinasParaKds(usuario);
    }
    async tickets(cocinaId, usuario) {
        await this.cocinas.exigirAccesoCocinaKds(usuario, cocinaId);
        return this.cocinas.listarTickets(cocinaId, usuario.sucursal_id);
    }
    async cambiarEstadoItem(itemId, dto, usuario) {
        await this.cocinas.exigirAccesoItemKds(usuario, itemId);
        return this.cocinas.cambiarEstadoItem(itemId, usuario.sucursal_id, dto.estado_cocina, usuario.sub ?? null, dto.motivo);
    }
    async cambiarEstadoTareaCombo(tareaId, dto, usuario) {
        await this.cocinas.exigirAccesoTareaComboKds(usuario, tareaId);
        return this.cocinas.cambiarEstadoTareaCombo(tareaId, usuario.sucursal_id, dto.estado_cocina, usuario.sub ?? null);
    }
    async marcarTareaComboNoDisponible(tareaId, dto, usuario) {
        await this.cocinas.exigirAccesoTareaComboKds(usuario, tareaId);
        return this.cocinas.marcarTareaComboNoDisponible(tareaId, usuario.sucursal_id, usuario.sub ?? null, dto.motivo);
    }
    async falloPreparacion(itemId, dto, usuario) {
        await this.cocinas.exigirAccesoItemKds(usuario, itemId);
        return this.cocinas.falloPreparacion(itemId, usuario.sucursal_id, usuario.sub ?? null, dto.motivo);
    }
    async actualizarObservaciones(itemId, body, usuario) {
        await this.cocinas.exigirAccesoItemKds(usuario, itemId);
        return this.cocinas.actualizarObservacionesItem(itemId, usuario.sucursal_id, body.observaciones ?? '');
    }
    async prioridad(itemId, body, usuario) {
        await this.cocinas.exigirAccesoItemKds(usuario, itemId);
        return this.cocinas.marcarPrioridadItem(itemId, usuario.sucursal_id, body.urgente === true);
    }
};
exports.CocinaTicketsController = CocinaTicketsController;
__decorate([
    (0, common_1.Get)('cocinas'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], CocinaTicketsController.prototype, "listarCocinas", null);
__decorate([
    (0, common_1.Get)('tickets/:cocina_id'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, common_1.Param)('cocina_id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinaTicketsController.prototype, "tickets", null);
__decorate([
    (0, common_1.Patch)('items/:item_id/estado'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, common_1.Param)('item_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cocina_dto_1.CambiarEstadoItemDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinaTicketsController.prototype, "cambiarEstadoItem", null);
__decorate([
    (0, common_1.Patch)('combo-tareas/:tarea_id/estado'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, common_1.Param)('tarea_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cocina_dto_1.CambiarEstadoItemDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinaTicketsController.prototype, "cambiarEstadoTareaCombo", null);
__decorate([
    (0, common_1.Patch)('combo-tareas/:tarea_id/no-disponible'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, common_1.Param)('tarea_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cocina_dto_1.NoDisponibleTareaComboDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinaTicketsController.prototype, "marcarTareaComboNoDisponible", null);
__decorate([
    (0, common_1.Post)('items/:item_id/fallo-preparacion'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, common_1.Param)('item_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cocina_dto_1.FalloPreparacionDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinaTicketsController.prototype, "falloPreparacion", null);
__decorate([
    (0, common_1.Patch)('items/:item_id/observaciones'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, common_1.Param)('item_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, item_kds_mutacion_dto_1.ActualizarObservacionesItemDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinaTicketsController.prototype, "actualizarObservaciones", null);
__decorate([
    (0, common_1.Patch)('items/:item_id/prioridad'),
    (0, permisos_decorator_1.Permisos)('ver_cocina'),
    __param(0, (0, common_1.Param)('item_id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, item_kds_mutacion_dto_1.PrioridadItemCocinaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], CocinaTicketsController.prototype, "prioridad", null);
exports.CocinaTicketsController = CocinaTicketsController = __decorate([
    (0, common_1.Controller)('cocina'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('cocina'),
    __metadata("design:paramtypes", [cocinas_service_1.CocinasService])
], CocinaTicketsController);
//# sourceMappingURL=cocina-tickets.controller.js.map