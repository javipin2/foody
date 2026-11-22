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
exports.AnaliticaController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const requiere_modulo_decorator_1 = require("../../compartido/decoradores/requiere-modulo.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const plan_features_guard_1 = require("../../core/auth/guards/plan-features.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const analitica_service_1 = require("./analitica.service");
const filtro_analitica_dto_1 = require("./dto/filtro-analitica.dto");
let AnaliticaController = class AnaliticaController {
    analiticaService;
    constructor(analiticaService) {
        this.analiticaService = analiticaService;
    }
    async resumen(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.resumen(sucursalId, periodo, anterior, filtros);
    }
    async ventas(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.ventas(sucursalId, periodo, filtros, anterior);
    }
    async productos(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.productos(sucursalId, periodo, filtros, anterior);
    }
    async cocinas(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.cocinas(sucursalId, periodo, filtros, anterior);
    }
    async inventario(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.inventario(sucursalId, periodo, filtros, anterior);
    }
    async domiciliarios(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.domiciliarios(sucursalId, periodo, filtros, anterior);
    }
    async caja(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.caja(sucursalId, periodo, filtros, anterior);
    }
    async rentabilidad(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.rentabilidad(sucursalId, periodo, filtros, anterior);
    }
    async riesgo(usuario, query) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        return this.analiticaService.riesgo(sucursalId, periodo, filtros, anterior);
    }
    async pedidosRecientes(usuario, query) {
        const { sucursalId, periodo, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        const limite = Math.min(Math.max(query.limite ?? 15, 1), 50);
        return this.analiticaService.pedidosRecientes(sucursalId, periodo, filtros, limite);
    }
    async export(usuario, query, res) {
        const { sucursalId, periodo, anterior, filtros } = await this.analiticaService.resolverContexto(usuario, query);
        const archivo = await this.analiticaService.exportarCsv(sucursalId, periodo, anterior, filtros);
        res.setHeader('Content-Type', archivo.mime);
        res.setHeader('Content-Disposition', `attachment; filename="${archivo.filename}"`);
        res.end(archivo.buffer);
    }
    async comparativaSedes(usuario, query) {
        return this.analiticaService.comparativaSedesParaUsuario(usuario, query);
    }
};
exports.AnaliticaController = AnaliticaController;
__decorate([
    (0, common_1.Get)('resumen'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "resumen", null);
__decorate([
    (0, common_1.Get)('ventas'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "ventas", null);
__decorate([
    (0, common_1.Get)('productos'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "productos", null);
__decorate([
    (0, common_1.Get)('cocinas'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "cocinas", null);
__decorate([
    (0, common_1.Get)('inventario'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "inventario", null);
__decorate([
    (0, common_1.Get)('domiciliarios'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "domiciliarios", null);
__decorate([
    (0, common_1.Get)('caja'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "caja", null);
__decorate([
    (0, common_1.Get)('rentabilidad'),
    (0, permisos_decorator_1.Permisos)('ver_finanzas'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "rentabilidad", null);
__decorate([
    (0, common_1.Get)('riesgo'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "riesgo", null);
__decorate([
    (0, common_1.Get)('pedidos-recientes'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "pedidosRecientes", null);
__decorate([
    (0, common_1.Get)('export'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __param(2, (0, common_1.Res)({ passthrough: false })),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto, Object]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "export", null);
__decorate([
    (0, common_1.Get)('comparativa-sedes'),
    (0, permisos_decorator_1.Permisos)('ver_analitica', 'ver_reportes'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload,
        filtro_analitica_dto_1.FiltroAnaliticaDto]),
    __metadata("design:returntype", Promise)
], AnaliticaController.prototype, "comparativaSedes", null);
exports.AnaliticaController = AnaliticaController = __decorate([
    (0, common_1.Controller)('analitica'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('analitica'),
    __metadata("design:paramtypes", [analitica_service_1.AnaliticaService])
], AnaliticaController);
//# sourceMappingURL=analitica.controller.js.map