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
Object.defineProperty(exports, "__esModule", { value: true });
exports.FiltroPopularidadQueryDto = void 0;
const class_validator_1 = require("class-validator");
const PRESETS = [
    'hoy',
    'ayer',
    'semana',
    'mes',
    'mes_anterior',
    '7d',
    '30d',
    'rango',
];
class FiltroPopularidadQueryDto {
    preset;
    desde;
    hasta;
}
exports.FiltroPopularidadQueryDto = FiltroPopularidadQueryDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(PRESETS),
    __metadata("design:type", Object)
], FiltroPopularidadQueryDto.prototype, "preset", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FiltroPopularidadQueryDto.prototype, "desde", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FiltroPopularidadQueryDto.prototype, "hasta", void 0);
//# sourceMappingURL=filtro-popularidad.dto.js.map