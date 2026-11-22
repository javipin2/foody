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
const dispositivos_dto_1 = require("./dto/dispositivos.dto");
let DispositivosController = class DispositivosController {
    dispositivosService;
    constructor(dispositivosService) {
        this.dispositivosService = dispositivosService;
    }
    registrar(body) {
        return this.dispositivosService.registrar(body);
    }
    vincularAuth(body) {
        return this.dispositivosService.vincularAuth(body);
    }
    async anonimizar(deviceId, fcmTokenQuery, body = {}, authorization, fcmHeader) {
        const bearer = body.access_token?.trim() ||
            (authorization?.toLowerCase().startsWith('bearer ')
                ? authorization.slice(7).trim()
                : undefined);
        const fcm = fcmTokenQuery?.trim() || fcmHeader?.trim() || body.fcm_token?.trim();
        const ok = await this.dispositivosService.verificarPosesionParaAnonimizar(deviceId, { fcm_token: fcm, access_token: bearer });
        if (!ok) {
            throw new common_1.ForbiddenException({
                error: 'DISPOSITIVO_NO_AUTORIZADO',
                message: 'Debes probar posesión del dispositivo (fcm_token actual o sesión Google)',
            });
        }
        return this.dispositivosService.anonimizar(deviceId);
    }
};
exports.DispositivosController = DispositivosController;
__decorate([
    (0, common_1.Post)('registrar'),
    (0, rate_limit_guard_1.RateLimitPublico)(30, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [dispositivos_dto_1.RegistrarDispositivoDto]),
    __metadata("design:returntype", void 0)
], DispositivosController.prototype, "registrar", null);
__decorate([
    (0, common_1.Post)('vincular-auth'),
    (0, rate_limit_guard_1.RateLimitPublico)(20, 60_000),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [dispositivos_dto_1.VincularAuthDispositivoDto]),
    __metadata("design:returntype", void 0)
], DispositivosController.prototype, "vincularAuth", null);
__decorate([
    (0, common_1.Delete)('anonimizar/:device_id'),
    (0, rate_limit_guard_1.RateLimitPublico)(10, 60_000),
    __param(0, (0, common_1.Param)('device_id')),
    __param(1, (0, common_1.Query)('fcm_token')),
    __param(2, (0, common_1.Body)()),
    __param(3, (0, common_1.Headers)('authorization')),
    __param(4, (0, common_1.Headers)('x-foody-fcm-token')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, dispositivos_dto_1.AnonimizarDispositivoDto, String, String]),
    __metadata("design:returntype", Promise)
], DispositivosController.prototype, "anonimizar", null);
exports.DispositivosController = DispositivosController = __decorate([
    (0, common_1.Controller)('dispositivos'),
    __metadata("design:paramtypes", [dispositivos_service_1.DispositivosService])
], DispositivosController);
//# sourceMappingURL=dispositivos.controller.js.map