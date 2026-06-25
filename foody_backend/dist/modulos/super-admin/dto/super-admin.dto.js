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
exports.RechazarDocumentoDto = exports.AprobarDocumentoDto = exports.ActualizarConfiguracionDto = exports.CambiarEstadoUsuarioSuperDto = exports.CambiarContrasenaSuperDto = exports.ActualizarUsuarioSuperDto = exports.CrearUsuarioSuperDto = exports.CrearRestauranteDto = exports.ActualizarDomiciliarioEstadoDto = exports.ActualizarSuscripcionDto = exports.ActualizarRestauranteDto = exports.ActualizarCiudadDto = exports.CrearCiudadDto = void 0;
const class_validator_1 = require("class-validator");
class CrearCiudadDto {
    nombre;
    slug;
}
exports.CrearCiudadDto = CrearCiudadDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], CrearCiudadDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    (0, class_validator_1.MaxLength)(80),
    __metadata("design:type", String)
], CrearCiudadDto.prototype, "slug", void 0);
class ActualizarCiudadDto {
    nombre;
    activa;
}
exports.ActualizarCiudadDto = ActualizarCiudadDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], ActualizarCiudadDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ActualizarCiudadDto.prototype, "activa", void 0);
class ActualizarRestauranteDto {
    activo;
    motivo_bloqueo;
}
exports.ActualizarRestauranteDto = ActualizarRestauranteDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ActualizarRestauranteDto.prototype, "activo", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(500),
    __metadata("design:type", String)
], ActualizarRestauranteDto.prototype, "motivo_bloqueo", void 0);
class ActualizarSuscripcionDto {
    estado;
    plan;
    fecha_vencimiento;
}
exports.ActualizarSuscripcionDto = ActualizarSuscripcionDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['prueba', 'activa', 'vencida', 'bloqueada']),
    __metadata("design:type", String)
], ActualizarSuscripcionDto.prototype, "estado", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['gratis', 'basico', 'pro', 'enterprise']),
    __metadata("design:type", String)
], ActualizarSuscripcionDto.prototype, "plan", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], ActualizarSuscripcionDto.prototype, "fecha_vencimiento", void 0);
class ActualizarDomiciliarioEstadoDto {
    estado_cuenta;
    motivo;
}
exports.ActualizarDomiciliarioEstadoDto = ActualizarDomiciliarioEstadoDto;
__decorate([
    (0, class_validator_1.IsIn)(['pendiente_verificacion', 'activo', 'suspendido', 'bloqueado']),
    __metadata("design:type", String)
], ActualizarDomiciliarioEstadoDto.prototype, "estado_cuenta", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], ActualizarDomiciliarioEstadoDto.prototype, "motivo", void 0);
const ROLES_STAFF_SUPER = [
    'admin',
    'gerente',
    'cajero',
    'mesero',
    'domiciliario_planta',
    'cocina_principal',
];
class CrearRestauranteDto {
    ciudad_id;
    nombre_restaurante;
    nombre_sucursal;
    direccion_sucursal;
    admin_nombre;
    admin_email;
    admin_contrasena;
}
exports.CrearRestauranteDto = CrearRestauranteDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearRestauranteDto.prototype, "ciudad_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], CrearRestauranteDto.prototype, "nombre_restaurante", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], CrearRestauranteDto.prototype, "nombre_sucursal", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(300),
    __metadata("design:type", String)
], CrearRestauranteDto.prototype, "direccion_sucursal", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    (0, class_validator_1.MaxLength)(120),
    __metadata("design:type", String)
], CrearRestauranteDto.prototype, "admin_nombre", void 0);
__decorate([
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], CrearRestauranteDto.prototype, "admin_email", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], CrearRestauranteDto.prototype, "admin_contrasena", void 0);
class CrearUsuarioSuperDto {
    nombre;
    email;
    contrasena;
    rol;
    sucursal_id;
}
exports.CrearUsuarioSuperDto = CrearUsuarioSuperDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    __metadata("design:type", String)
], CrearUsuarioSuperDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], CrearUsuarioSuperDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], CrearUsuarioSuperDto.prototype, "contrasena", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsIn)(ROLES_STAFF_SUPER),
    __metadata("design:type", Object)
], CrearUsuarioSuperDto.prototype, "rol", void 0);
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearUsuarioSuperDto.prototype, "sucursal_id", void 0);
class ActualizarUsuarioSuperDto {
    nombre;
    email;
    rol;
}
exports.ActualizarUsuarioSuperDto = ActualizarUsuarioSuperDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(2),
    __metadata("design:type", String)
], ActualizarUsuarioSuperDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsEmail)(),
    __metadata("design:type", String)
], ActualizarUsuarioSuperDto.prototype, "email", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsIn)(ROLES_STAFF_SUPER),
    __metadata("design:type", Object)
], ActualizarUsuarioSuperDto.prototype, "rol", void 0);
class CambiarContrasenaSuperDto {
    contrasena;
}
exports.CambiarContrasenaSuperDto = CambiarContrasenaSuperDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(6),
    __metadata("design:type", String)
], CambiarContrasenaSuperDto.prototype, "contrasena", void 0);
class CambiarEstadoUsuarioSuperDto {
    activo;
}
exports.CambiarEstadoUsuarioSuperDto = CambiarEstadoUsuarioSuperDto;
__decorate([
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], CambiarEstadoUsuarioSuperDto.prototype, "activo", void 0);
class ActualizarConfiguracionDto {
    valor;
}
exports.ActualizarConfiguracionDto = ActualizarConfiguracionDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(1),
    (0, class_validator_1.MaxLength)(500),
    __metadata("design:type", String)
], ActualizarConfiguracionDto.prototype, "valor", void 0);
class AprobarDocumentoDto {
    documento_id;
}
exports.AprobarDocumentoDto = AprobarDocumentoDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], AprobarDocumentoDto.prototype, "documento_id", void 0);
class RechazarDocumentoDto {
    documento_id;
    motivo;
}
exports.RechazarDocumentoDto = RechazarDocumentoDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], RechazarDocumentoDto.prototype, "documento_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(3),
    __metadata("design:type", String)
], RechazarDocumentoDto.prototype, "motivo", void 0);
//# sourceMappingURL=super-admin.dto.js.map