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
exports.CiudadesController = void 0;
const common_1 = require("@nestjs/common");
const rate_limit_guard_1 = require("../../compartido/guards/rate-limit.guard");
const ciudades_service_1 = require("./ciudades.service");
let CiudadesController = class CiudadesController {
    ciudadesService;
    constructor(ciudadesService) {
        this.ciudadesService = ciudadesService;
    }
    listarCiudades() {
        return this.ciudadesService.listarActivas();
    }
    listarRestaurantes(slug) {
        return this.ciudadesService.listarRestaurantesPorSlug(slug);
    }
};
exports.CiudadesController = CiudadesController;
__decorate([
    (0, common_1.Get)('ciudades'),
    (0, rate_limit_guard_1.RateLimitPublico)(120, 60_000),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], CiudadesController.prototype, "listarCiudades", null);
__decorate([
    (0, common_1.Get)('ciudades/:slug/restaurantes'),
    (0, rate_limit_guard_1.RateLimitPublico)(90, 60_000),
    __param(0, (0, common_1.Param)('slug')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CiudadesController.prototype, "listarRestaurantes", null);
exports.CiudadesController = CiudadesController = __decorate([
    (0, common_1.Controller)(),
    __metadata("design:paramtypes", [ciudades_service_1.CiudadesService])
], CiudadesController);
//# sourceMappingURL=ciudades.controller.js.map