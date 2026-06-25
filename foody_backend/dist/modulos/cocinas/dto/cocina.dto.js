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
exports.CambiarEstadoItemDto = exports.ActualizarImpresoraDto = exports.CrearImpresoraDto = exports.ActualizarCocinaDto = exports.CrearCocinaDto = void 0;
const class_validator_1 = require("class-validator");
class CrearCocinaDto {
    sucursal_id;
    nombre;
}
exports.CrearCocinaDto = CrearCocinaDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearCocinaDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], CrearCocinaDto.prototype, "nombre", void 0);
class ActualizarCocinaDto {
    nombre;
    activa;
}
exports.ActualizarCocinaDto = ActualizarCocinaDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], ActualizarCocinaDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ActualizarCocinaDto.prototype, "activa", void 0);
class CrearImpresoraDto {
    sucursal_id;
    cocina_id;
    nombre;
    ip_local;
    tipo;
}
exports.CrearImpresoraDto = CrearImpresoraDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearImpresoraDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearImpresoraDto.prototype, "cocina_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], CrearImpresoraDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearImpresoraDto.prototype, "ip_local", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['termica_red', 'termica_usb', 'pdf']),
    __metadata("design:type", String)
], CrearImpresoraDto.prototype, "tipo", void 0);
class ActualizarImpresoraDto {
    nombre;
    cocina_id;
    ip_local;
    tipo;
    activa;
}
exports.ActualizarImpresoraDto = ActualizarImpresoraDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    __metadata("design:type", String)
], ActualizarImpresoraDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], ActualizarImpresoraDto.prototype, "cocina_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], ActualizarImpresoraDto.prototype, "ip_local", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['termica_red', 'termica_usb', 'pdf']),
    __metadata("design:type", String)
], ActualizarImpresoraDto.prototype, "tipo", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ActualizarImpresoraDto.prototype, "activa", void 0);
class CambiarEstadoItemDto {
    estado_cocina;
    motivo;
}
exports.CambiarEstadoItemDto = CambiarEstadoItemDto;
__decorate([
    (0, class_validator_1.IsIn)(['pendiente', 'preparando', 'listo', 'no_disponible']),
    __metadata("design:type", String)
], CambiarEstadoItemDto.prototype, "estado_cocina", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CambiarEstadoItemDto.prototype, "motivo", void 0);
//# sourceMappingURL=cocina.dto.js.map