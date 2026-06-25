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
const geografia_service_1 = require("./geografia.service");
let GeografiaController = class GeografiaController {
    geografia;
    constructor(geografia) {
        this.geografia = geografia;
    }
    buscar(consulta, lat, lng, limite) {
        return this.geografia.buscarDirecciones(consulta ?? '', {
            lat: lat != null ? Number(lat) : undefined,
            lng: lng != null ? Number(lng) : undefined,
            limite: limite != null ? Number(limite) : undefined,
        });
    }
};
exports.GeografiaController = GeografiaController;
__decorate([
    (0, common_1.Get)('buscar'),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('lat')),
    __param(2, (0, common_1.Query)('lng')),
    __param(3, (0, common_1.Query)('limite')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String]),
    __metadata("design:returntype", void 0)
], GeografiaController.prototype, "buscar", null);
exports.GeografiaController = GeografiaController = __decorate([
    (0, common_1.Controller)('geografia'),
    __metadata("design:paramtypes", [geografia_service_1.GeografiaService])
], GeografiaController);
//# sourceMappingURL=geografia.controller.js.map