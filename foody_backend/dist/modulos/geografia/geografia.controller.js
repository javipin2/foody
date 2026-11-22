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
exports.GeografiaController = void 0;
const common_1 = require("@nestjs/common");
const rate_limit_guard_1 = require("../../compartido/guards/rate-limit.guard");
const buscar_geografia_dto_1 = require("./dto/buscar-geografia.dto");
const geografia_service_1 = require("./geografia.service");
let GeografiaController = class GeografiaController {
    geografia;
    constructor(geografia) {
        this.geografia = geografia;
    }
    buscar(dto) {
        return this.geografia.buscarDirecciones(dto.q ?? '', {
            lat: dto.lat,
            lng: dto.lng,
            limite: dto.limite,
        });
    }
};
exports.GeografiaController = GeografiaController;
__decorate([
    (0, common_1.Get)('buscar'),
    (0, rate_limit_guard_1.RateLimitPublico)(40, 60_000),
    __param(0, (0, common_1.Query)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [buscar_geografia_dto_1.BuscarGeografiaDto]),
    __metadata("design:returntype", void 0)
], GeografiaController.prototype, "buscar", null);
exports.GeografiaController = GeografiaController = __decorate([
    (0, common_1.Controller)('geografia'),
    __metadata("design:paramtypes", [geografia_service_1.GeografiaService])
], GeografiaController);
//# sourceMappingURL=geografia.controller.js.map