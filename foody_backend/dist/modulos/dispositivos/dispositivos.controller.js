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
exports.DispositivosController = void 0;
const common_1 = require("@nestjs/common");
const rate_limit_guard_1 = require("../../compartido/guards/rate-limit.guard");
const dispositivos_service_1 = require("./dispositivos.service");
let DispositivosController = class DispositivosController {
    dispositivosService;
    constructor(dispositivosService) {
        this.dispositivosService = dispositivosService;
    }
    registrar(body) {
        return this.dispositivosService.registrar(body);
    }
    anonimizar(deviceId) {
        return this.dispositivosService.anonimizar(deviceId);
    }
};
exports.DispositivosController = DispositivosController;
__decorate([
    (0, common_1.Post)('registrar'),
    (0, rate_limit_guard_1.RateLimitPublico)(30, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], DispositivosController.prototype, "registrar", null);
__decorate([
    (0, common_1.Delete)('anonimizar/:device_id'),
    (0, rate_limit_guard_1.RateLimitPublico)(10, 60_000),
    __param(0, (0, common_1.Param)('device_id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], DispositivosController.prototype, "anonimizar", null);
exports.DispositivosController = DispositivosController = __decorate([
    (0, common_1.Controller)('dispositivos'),
    __metadata("design:paramtypes", [dispositivos_service_1.DispositivosService])
], DispositivosController);
//# sourceMappingURL=dispositivos.controller.js.map