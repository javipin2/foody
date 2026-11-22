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
exports.ActualizarExtraDto = exports.VincularBebidaDto = exports.ConfigurarToppingsDto = exports.VincularToppingDto = exports.CambiarDisponibilidadDto = void 0;
const class_validator_1 = require("class-validator");
class CambiarDisponibilidadDto {
    disponible;
}
exports.CambiarDisponibilidadDto = CambiarDisponibilidadDto;
__decorate([
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], CambiarDisponibilidadDto.prototype, "disponible", void 0);
class VincularToppingDto {
    topping_id;
}
exports.VincularToppingDto = VincularToppingDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], VincularToppingDto.prototype, "topping_id", void 0);
class ConfigurarToppingsDto {
    topping_ids;
}
exports.ConfigurarToppingsDto = ConfigurarToppingsDto;
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayUnique)(),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], ConfigurarToppingsDto.prototype, "topping_ids", void 0);
class VincularBebidaDto {
    bebida_id;
}
exports.VincularBebidaDto = VincularBebidaDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], VincularBebidaDto.prototype, "bebida_id", void 0);
class ActualizarExtraDto {
    nombre;
    precio;
    disponible;
}
exports.ActualizarExtraDto = ActualizarExtraDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], ActualizarExtraDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], ActualizarExtraDto.prototype, "precio", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ActualizarExtraDto.prototype, "disponible", void 0);
//# sourceMappingURL=extras-mutacion.dto.js.map