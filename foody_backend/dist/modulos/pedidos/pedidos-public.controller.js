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
const crear_pedido_dto_1 = require("./dto/crear-pedido.dto");
const pedidos_service_1 = require("./pedidos.service");
let PedidosPublicController = class PedidosPublicController {
    pedidosService;
    constructor(pedidosService) {
        this.pedidosService = pedidosService;
    }
    crear(dto) {
        return this.pedidosService.crear(dto);
    }
    listarMios(deviceId) {
        if (!deviceId?.trim()) {
            throw new common_1.BadRequestException('device_id es obligatorio');
        }
        return this.pedidosService.listarPorDevice(deviceId.trim());
    }
    estado(id) {
        return this.pedidosService.obtenerEstadoPublico(id);
    }
};
exports.PedidosPublicController = PedidosPublicController;
__decorate([
    (0, common_1.Post)(),
    (0, rate_limit_guard_1.RateLimitPublico)(40, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_pedido_dto_1.CrearPedidoDto]),
    __metadata("design:returntype", void 0)
], PedidosPublicController.prototype, "crear", null);
__decorate([
    (0, common_1.Get)('mios'),
    (0, rate_limit_guard_1.RateLimitPublico)(60, 60_000),
    __param(0, (0, common_1.Query)('device_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PedidosPublicController.prototype, "listarMios", null);
__decorate([
    (0, common_1.Get)(':id/estado'),
    (0, rate_limit_guard_1.RateLimitPublico)(120, 60_000),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], PedidosPublicController.prototype, "estado", null);
exports.PedidosPublicController = PedidosPublicController = __decorate([
    (0, common_1.Controller)('pedidos'),
    __metadata("design:paramtypes", [pedidos_service_1.PedidosService])
], PedidosPublicController);
//# sourceMappingURL=pedidos-public.controller.js.map