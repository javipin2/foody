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
exports.SubirVideoQueryDto = exports.SubirImagenQueryDto = void 0;
const class_validator_1 = require("class-validator");
const TIPOS_IMAGEN = [
    'producto',
    'categoria',
    'combo',
    'promocion',
    'general',
];
class SubirImagenQueryDto {
    sucursal_id;
    tipo;
    entidad_id;
}
exports.SubirImagenQueryDto = SubirImagenQueryDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], SubirImagenQueryDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(TIPOS_IMAGEN),
    __metadata("design:type", Object)
], SubirImagenQueryDto.prototype, "tipo", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], SubirImagenQueryDto.prototype, "entidad_id", void 0);
class SubirVideoQueryDto {
    sucursal_id;
    tipo;
}
exports.SubirVideoQueryDto = SubirVideoQueryDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], SubirVideoQueryDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(TIPOS_IMAGEN),
    __metadata("design:type", Object)
], SubirVideoQueryDto.prototype, "tipo", void 0);
//# sourceMappingURL=subir-media-query.dto.js.map