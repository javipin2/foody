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
exports.PedidosPublicController = void 0;
const common_1 = require("@nestjs/common");
const rate_limit_guard_1 = require("../../compartido/guards/rate-limit.guard");
const supabase_auth_service_1 = require("../../core/auth/supabase-auth.service");
const cancelar_pedido_cliente_dto_1 = require("./dto/cancelar-pedido-cliente.dto");
const calificar_domicilio_cliente_dto_1 = require("./dto/calificar-domicilio-cliente.dto");
const llamar_mesera_cliente_dto_1 = require("./dto/llamar-mesera-cliente.dto");
const crear_pedido_dto_1 = require("./dto/crear-pedido.dto");
const pedidos_service_1 = require("./pedidos.service");
const dispositivos_service_1 = require("../dispositivos/dispositivos.service");
let PedidosPublicController = class PedidosPublicController {
    pedidosService;
    supabaseAuth;
    dispositivos;
    constructor(pedidosService, supabaseAuth, dispositivos) {
        this.pedidosService = pedidosService;
        this.supabaseAuth = supabaseAuth;
        this.dispositivos = dispositivos;
    }
    async verificarDevice(deviceId, capability) {
        await this.dispositivos.exigirCapability(deviceId, capability);
    }
    async crear(dto, capability) {
        await this.verificarDevice(dto.device_id, capability);
        return this.pedidosService.crear(dto);
    }
    async estimar(dto, capability) {
        await this.verificarDevice(dto.device_id, capability);
        return this.pedidosService.estimar(dto);
    }
    async listarMios(deviceId, authorization, capability) {
        if (!deviceId?.trim()) {
            throw new common_1.BadRequestException('device_id es obligatorio');
        }
        await this.verificarDevice(deviceId.trim(), capability);
        let authUid = null;
        const bearer = authorization?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
        if (bearer && this.supabaseAuth.estaConfigurado()) {
            try {
                const user = await this.supabaseAuth.usuarioDesdeAccessToken(bearer);
                authUid = user.id;
            }
            catch {
            }
        }
        return this.pedidosService.listarPorDevice(deviceId.trim(), authUid);
    }
    async cancelar(id, dto, capability) {
        await this.verificarDevice(dto.device_id.trim(), capability);
        return this.pedidosService.cancelarPorCliente(id, dto.device_id.trim(), dto.motivo.trim());
    }
    async llamarMesera(id, dto, capability) {
        await this.verificarDevice(dto.device_id.trim(), capability);
        return this.pedidosService.llamarMesera(id, dto.device_id.trim(), dto.mensaje?.trim());
    }
    async calificar(id, dto, capability) {
        await this.verificarDevice(dto.device_id.trim(), capability);
        return this.pedidosService.calificarDomicilio(id, dto.device_id.trim(), dto.calificacion, dto.comentario?.trim());
    }
    async estado(id, deviceId, seguimientoToken, capability) {
        const capabilityValida = !!deviceId?.trim() &&
            !!capability &&
            (await this.dispositivos.verificarCapability(deviceId.trim(), capability));
        if (!capabilityValida && !seguimientoToken?.trim()) {
            throw new common_1.ForbiddenException({
                error: 'SEGUIMIENTO_NO_AUTORIZADO',
                message: 'Se requiere una capability de dispositivo o token de seguimiento.',
            });
        }
        return this.pedidosService.obtenerEstadoPublico(id, {
            deviceId,
            seguimientoToken,
        });
    }
};
exports.PedidosPublicController = PedidosPublicController;
__decorate([
    (0, common_1.Post)(),
    (0, common_1.HttpCode)(common_1.HttpStatus.CREATED),
    (0, rate_limit_guard_1.RateLimitPublico)(40, 60_000),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Headers)('x-foody-device-capability')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_pedido_dto_1.CrearPedidoDto, String]),
    __metadata("design:returntype", Promise)
], PedidosPublicController.prototype, "crear", null);
__decorate([
    (0, common_1.Post)('estimar'),
    (0, rate_limit_guard_1.RateLimitPublico)(60, 60_000),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Headers)('x-foody-device-capability')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_pedido_dto_1.CrearPedidoDto, String]),
    __metadata("design:returntype", Promise)
], PedidosPublicController.prototype, "estimar", null);
__decorate([
    (0, common_1.Get)('mios'),
    (0, rate_limit_guard_1.RateLimitPublico)(60, 60_000),
    __param(0, (0, common_1.Query)('device_id')),
    __param(1, (0, common_1.Headers)('authorization')),
    __param(2, (0, common_1.Headers)('x-foody-device-capability')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", Promise)
], PedidosPublicController.prototype, "listarMios", null);
__decorate([
    (0, common_1.Post)(':id/cancelar'),
    (0, rate_limit_guard_1.RateLimitPublico)(20, 60_000),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Headers)('x-foody-device-capability')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, cancelar_pedido_cliente_dto_1.CancelarPedidoClienteDto, String]),
    __metadata("design:returntype", Promise)
], PedidosPublicController.prototype, "cancelar", null);
__decorate([
    (0, common_1.Post)(':id/llamar-mesera'),
    (0, rate_limit_guard_1.RateLimitPublico)(15, 60_000),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Headers)('x-foody-device-capability')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, llamar_mesera_cliente_dto_1.LlamarMeseraClienteDto, String]),
    __metadata("design:returntype", Promise)
], PedidosPublicController.prototype, "llamarMesera", null);
__decorate([
    (0, common_1.Post)(':id/calificar'),
    (0, rate_limit_guard_1.RateLimitPublico)(20, 60_000),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Body)()),
    __param(2, (0, common_1.Headers)('x-foody-device-capability')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, calificar_domicilio_cliente_dto_1.CalificarDomicilioClienteDto, String]),
    __metadata("design:returntype", Promise)
], PedidosPublicController.prototype, "calificar", null);
__decorate([
    (0, common_1.Get)(':id/estado'),
    (0, rate_limit_guard_1.RateLimitPublico)(120, 60_000),
    __param(0, (0, common_1.Param)('id', common_1.ParseUUIDPipe)),
    __param(1, (0, common_1.Query)('device_id')),
    __param(2, (0, common_1.Query)('token')),
    __param(3, (0, common_1.Headers)('x-foody-device-capability')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String]),
    __metadata("design:returntype", Promise)
], PedidosPublicController.prototype, "estado", null);
exports.PedidosPublicController = PedidosPublicController = __decorate([
    (0, common_1.Controller)('pedidos'),
    __metadata("design:paramtypes", [pedidos_service_1.PedidosService,
        supabase_auth_service_1.SupabaseAuthService,
        dispositivos_service_1.DispositivosService])
], PedidosPublicController);
//# sourceMappingURL=pedidos-public.controller.js.map