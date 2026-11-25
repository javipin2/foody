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
exports.DomiciliariosIndependientesController = exports.DomiciliarioPlantaController = exports.DomiciliariosPlantaController = void 0;
const common_1 = require("@nestjs/common");
const permisos_decorator_1 = require("../../compartido/decoradores/permisos.decorator");
const usuario_actual_decorator_1 = require("../../compartido/decoradores/usuario-actual.decorator");
const jwt_payload_1 = require("../../core/auth/jwt-payload");
const domiciliario_independiente_guard_1 = require("../../core/auth/guards/domiciliario-independiente.guard");
const jwt_auth_guard_1 = require("../../core/auth/guards/jwt-auth.guard");
const rol_guard_1 = require("../../core/auth/guards/rol.guard");
const suscripcion_activa_guard_1 = require("../../core/auth/guards/suscripcion-activa.guard");
const plan_features_guard_1 = require("../../core/auth/guards/plan-features.guard");
const requiere_modulo_decorator_1 = require("../../compartido/decoradores/requiere-modulo.decorator");
const usuario_activo_guard_1 = require("../../core/auth/guards/usuario-activo.guard");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const dispatch_service_1 = require("./dispatch.service");
const domiciliarios_independientes_service_1 = require("./domiciliarios-independientes.service");
const domiciliarios_service_1 = require("./domiciliarios.service");
const asignar_domiciliario_dto_1 = require("./dto/asignar-domiciliario.dto");
const confirmar_entrega_dto_1 = require("./dto/confirmar-entrega.dto");
const config_domicilio_dto_1 = require("./dto/config-domicilio.dto");
const independiente_dto_1 = require("./dto/independiente.dto");
let DomiciliariosPlantaController = class DomiciliariosPlantaController {
    domiciliariosService;
    dispatchService;
    sucursalScope;
    constructor(domiciliariosService, dispatchService, sucursalScope) {
        this.domiciliariosService = domiciliariosService;
        this.dispatchService = dispatchService;
        this.sucursalScope = sucursalScope;
    }
    async listarDisponibles(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.domiciliariosService.listarPlantaDisponibles(id);
    }
    async resumenComisiones(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.domiciliariosService.resumenComisionesIndependientes(id);
    }
    async resumenLiquidacion(usuario, sucursalId) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.domiciliariosService.resumenLiquidacion(id);
    }
    async liquidar(domiciliarioPlantaId, usuario, sucursalId) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.domiciliariosService.liquidarDomiciliario(sid, domiciliarioPlantaId, usuario.sub);
    }
    async configurarFiado(usuario, sucursalId, body) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.domiciliariosService.configurarFiadoDomiciliario(id, body.permitir === true);
    }
    async resumenDomicilios(usuario, sucursalId, desde, hasta) {
        const id = await this.sucursalScope.resolverLecturaOperativa(usuario, sucursalId);
        return this.domiciliariosService.resumenDomicilios(id, desde, hasta);
    }
    async configurarDomicilioCaja(usuario, sucursalId, body) {
        const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.domiciliariosService.configurarDomicilioEnCaja(id, body.ingresa === true);
    }
    async asignar(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.domiciliariosService.asignarPlanta(dto, usuario.sub);
    }
    async reasignar(dto, usuario) {
        await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
        return this.domiciliariosService.reasignarPlanta(dto, usuario.sub);
    }
    async dispatchIndependiente(pedidoId, usuario, sucursalId) {
        const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
        return this.dispatchService.iniciarBusquedaIndependientes(pedidoId, sid);
    }
};
exports.DomiciliariosPlantaController = DomiciliariosPlantaController;
__decorate([
    (0, common_1.Get)('disponibles/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "listarDisponibles", null);
__decorate([
    (0, common_1.Get)('comisiones-independientes/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "resumenComisiones", null);
__decorate([
    (0, common_1.Get)('liquidacion/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios', 'ver_caja'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "resumenLiquidacion", null);
__decorate([
    (0, common_1.Post)('liquidar/:domiciliario_planta_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios', 'gestionar_caja'),
    __param(0, (0, common_1.Param)('domiciliario_planta_id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "liquidar", null);
__decorate([
    (0, common_1.Patch)('config-fiado/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, config_domicilio_dto_1.ConfigFiadoDomiciliarioDto]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "configurarFiado", null);
__decorate([
    (0, common_1.Get)('domicilios/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios', 'ver_caja'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Query)('desde')),
    __param(3, (0, common_1.Query)('hasta')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String, String]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "resumenDomicilios", null);
__decorate([
    (0, common_1.Patch)('config-domicilio-caja/:sucursal_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Param)('sucursal_id', common_1.ParseUUIDPipe)),
    __param(2, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, config_domicilio_dto_1.ConfigDomicilioCajaDto]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "configurarDomicilioCaja", null);
__decorate([
    (0, common_1.Post)('asignar'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [asignar_domiciliario_dto_1.AsignarDomiciliarioDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "asignar", null);
__decorate([
    (0, common_1.Post)('reasignar'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [asignar_domiciliario_dto_1.AsignarDomiciliarioDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "reasignar", null);
__decorate([
    (0, common_1.Post)('dispatch-independiente/:pedido_id'),
    (0, permisos_decorator_1.Permisos)('gestionar_domiciliarios'),
    __param(0, (0, common_1.Param)('pedido_id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(2, (0, common_1.Query)('sucursal_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload, String]),
    __metadata("design:returntype", Promise)
], DomiciliariosPlantaController.prototype, "dispatchIndependiente", null);
exports.DomiciliariosPlantaController = DomiciliariosPlantaController = __decorate([
    (0, common_1.Controller)('domiciliarios-planta'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('domiciliarios'),
    __metadata("design:paramtypes", [domiciliarios_service_1.DomiciliariosService,
        dispatch_service_1.DispatchService,
        sucursal_scope_service_1.SucursalScopeService])
], DomiciliariosPlantaController);
let DomiciliarioPlantaController = class DomiciliarioPlantaController {
    domiciliariosService;
    constructor(domiciliariosService) {
        this.domiciliariosService = domiciliariosService;
    }
    pedidosAsignados(usuario) {
        return this.domiciliariosService.pedidosAsignados(usuario.sub);
    }
    enCamino(pedidoId, usuario) {
        return this.domiciliariosService.marcarEnCamino(pedidoId, usuario.sub);
    }
    confirmarEntrega(pedidoId, dto, usuario) {
        return this.domiciliariosService.confirmarEntrega(pedidoId, usuario.sub, dto);
    }
    ubicacion(dto, usuario) {
        return this.domiciliariosService.registrarUbicacionEntrega(usuario.sub, dto);
    }
    historial(usuario, desde, hasta) {
        return this.domiciliariosService.historialEntregas(usuario.sub, {
            desde,
            hasta,
        });
    }
    estadisticas(usuario, desde, hasta) {
        return this.domiciliariosService.estadisticasPlanta(usuario.sub, {
            desde,
            hasta,
        });
    }
};
exports.DomiciliarioPlantaController = DomiciliarioPlantaController;
__decorate([
    (0, common_1.Get)('pedidos-asignados'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliarioPlantaController.prototype, "pedidosAsignados", null);
__decorate([
    (0, common_1.Patch)('pedidos/:id/en-camino'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliarioPlantaController.prototype, "enCamino", null);
__decorate([
    (0, common_1.Patch)('pedidos/:id/confirmar-entrega'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, confirmar_entrega_dto_1.ConfirmarEntregaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliarioPlantaController.prototype, "confirmarEntrega", null);
__decorate([
    (0, common_1.Post)('ubicacion'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [independiente_dto_1.UbicacionEntregaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliarioPlantaController.prototype, "ubicacion", null);
__decorate([
    (0, common_1.Get)('historial'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)('desde')),
    __param(2, (0, common_1.Query)('hasta')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", void 0)
], DomiciliarioPlantaController.prototype, "historial", null);
__decorate([
    (0, common_1.Get)('estadisticas'),
    (0, permisos_decorator_1.Permisos)('ver_pedidos'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)('desde')),
    __param(2, (0, common_1.Query)('hasta')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", void 0)
], DomiciliarioPlantaController.prototype, "estadisticas", null);
exports.DomiciliarioPlantaController = DomiciliarioPlantaController = __decorate([
    (0, common_1.Controller)('domiciliario'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, suscripcion_activa_guard_1.SuscripcionActivaGuard, plan_features_guard_1.PlanFeaturesGuard, rol_guard_1.RolGuard),
    (0, requiere_modulo_decorator_1.RequiereModulo)('domiciliarios'),
    __metadata("design:paramtypes", [domiciliarios_service_1.DomiciliariosService])
], DomiciliarioPlantaController);
let DomiciliariosIndependientesController = class DomiciliariosIndependientesController {
    independientesService;
    constructor(independientesService) {
        this.independientesService = independientesService;
    }
    iniciarSesion(dto, usuario) {
        return this.independientesService.iniciarSesion(usuario.sub, dto);
    }
    ubicacion(dto, usuario) {
        return this.independientesService.actualizarUbicacion(usuario.sub, dto);
    }
    cerrarSesion(usuario) {
        return this.independientesService.cerrarSesion(usuario.sub);
    }
    estadoSesion(usuario) {
        return this.independientesService.estadoSesion(usuario.sub);
    }
    ofertasActivas(usuario) {
        return this.independientesService.ofertasActivas(usuario.sub);
    }
    responderOferta(ofertaId, dto, usuario) {
        return this.independientesService.responderOferta(ofertaId, usuario.sub, dto);
    }
    pedidosActivos(usuario) {
        return this.independientesService.pedidosActivos(usuario.sub);
    }
    enCamino(pedidoId, usuario) {
        return this.independientesService.marcarEnCamino(pedidoId, usuario.sub);
    }
    confirmarEntrega(pedidoId, dto, usuario) {
        return this.independientesService.confirmarEntrega(pedidoId, usuario.sub, dto);
    }
    ganancias(usuario, desde, hasta) {
        return this.independientesService.ganancias(usuario.sub, { desde, hasta });
    }
};
exports.DomiciliariosIndependientesController = DomiciliariosIndependientesController;
__decorate([
    (0, common_1.Post)('sesion/iniciar'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [independiente_dto_1.IniciarSesionDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "iniciarSesion", null);
__decorate([
    (0, common_1.Post)('sesion/ubicacion'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [independiente_dto_1.UbicacionEntregaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "ubicacion", null);
__decorate([
    (0, common_1.Post)('sesion/cerrar'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "cerrarSesion", null);
__decorate([
    (0, common_1.Get)('sesion/estado'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "estadoSesion", null);
__decorate([
    (0, common_1.Get)('ofertas-activas'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "ofertasActivas", null);
__decorate([
    (0, common_1.Post)('ofertas/:id/responder'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, independiente_dto_1.ResponderOfertaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "responderOferta", null);
__decorate([
    (0, common_1.Get)('pedidos-activos'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "pedidosActivos", null);
__decorate([
    (0, common_1.Patch)('pedidos/:id/en-camino'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "enCamino", null);
__decorate([
    (0, common_1.Patch)('pedidos/:id/confirmar-entrega'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, confirmar_entrega_dto_1.ConfirmarEntregaDto,
        jwt_payload_1.JwtPayload]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "confirmarEntrega", null);
__decorate([
    (0, common_1.Get)('ganancias'),
    (0, permisos_decorator_1.Permisos)('domiciliario_independiente'),
    __param(0, (0, usuario_actual_decorator_1.UsuarioActual)()),
    __param(1, (0, common_1.Query)('desde')),
    __param(2, (0, common_1.Query)('hasta')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [jwt_payload_1.JwtPayload, String, String]),
    __metadata("design:returntype", void 0)
], DomiciliariosIndependientesController.prototype, "ganancias", null);
exports.DomiciliariosIndependientesController = DomiciliariosIndependientesController = __decorate([
    (0, common_1.Controller)('domiciliarios'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, usuario_activo_guard_1.UsuarioActivoGuard, domiciliario_independiente_guard_1.DomiciliarioIndependienteGuard, rol_guard_1.RolGuard),
    __metadata("design:paramtypes", [domiciliarios_independientes_service_1.DomiciliariosIndependientesService])
], DomiciliariosIndependientesController);
//# sourceMappingURL=domiciliarios.controller.js.map