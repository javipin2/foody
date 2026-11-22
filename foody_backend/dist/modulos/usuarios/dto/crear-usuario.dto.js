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
exports.ActualizarUsuarioDto = exports.CambiarEstadoUsuarioDto = exports.CrearUsuarioDto = exports.ROLES_STAFF_ASIGNABLES = void 0;
const class_validator_1 = require("class-validator");
const ROLES_STAFF = [
    'gerente',
    'gerente_cadena',
    'cajero',
    'mesero',
    'domiciliario_planta',
    'cocina',
];
exports.ROLES_STAFF_ASIGNABLES = ROLES_STAFF;
class CrearUsuarioDto {
    nombre;
    email;
    contrasena;
    rol;
    sucursal_id;
    cocina_id;
    permisos;
}
exports.CrearUsuarioDto = CrearUsuarioDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    __metadata("design:type", String)
], CrearUsuarioDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], CrearUsuarioDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], CrearUsuarioDto.prototype, "contrasena", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsIn)(ROLES_STAFF),
    __metadata("design:type", Object)
], CrearUsuarioDto.prototype, "rol", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearUsuarioDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => o.rol === 'cocina'),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearUsuarioDto.prototype, "cocina_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayUnique)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], CrearUsuarioDto.prototype, "permisos", void 0);
class CambiarEstadoUsuarioDto {
    activo;
}
exports.CambiarEstadoUsuarioDto = CambiarEstadoUsuarioDto;
__decorate([
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], CambiarEstadoUsuarioDto.prototype, "activo", void 0);
class ActualizarUsuarioDto {
    nombre;
    rol;
    sucursal_id;
    cocina_id;
    permisos;
}
exports.ActualizarUsuarioDto = ActualizarUsuarioDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    __metadata("design:type", String)
], ActualizarUsuarioDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsIn)(ROLES_STAFF),
    __metadata("design:type", String)
], ActualizarUsuarioDto.prototype, "rol", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], ActualizarUsuarioDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", Object)
], ActualizarUsuarioDto.prototype, "cocina_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayUnique)(),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], ActualizarUsuarioDto.prototype, "permisos", void 0);
//# sourceMappingURL=crear-usuario.dto.js.map