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
exports.AnonimizarDispositivoDto = exports.VincularAuthDispositivoDto = exports.RegistrarDispositivoDto = void 0;
const class_validator_1 = require("class-validator");
class RegistrarDispositivoDto {
    device_id;
    fcm_token;
    ciudad_id;
    plataforma;
}
exports.RegistrarDispositivoDto = RegistrarDispositivoDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(8),
    __metadata("design:type", String)
], RegistrarDispositivoDto.prototype, "device_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RegistrarDispositivoDto.prototype, "fcm_token", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], RegistrarDispositivoDto.prototype, "ciudad_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RegistrarDispositivoDto.prototype, "plataforma", void 0);
class VincularAuthDispositivoDto {
    device_id;
    access_token;
}
exports.VincularAuthDispositivoDto = VincularAuthDispositivoDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(8),
    __metadata("design:type", String)
], VincularAuthDispositivoDto.prototype, "device_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(10),
    __metadata("design:type", String)
], VincularAuthDispositivoDto.prototype, "access_token", void 0);
class AnonimizarDispositivoDto {
    fcm_token;
    access_token;
}
exports.AnonimizarDispositivoDto = AnonimizarDispositivoDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], AnonimizarDispositivoDto.prototype, "fcm_token", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], AnonimizarDispositivoDto.prototype, "access_token", void 0);
//# sourceMappingURL=dispositivos.dto.js.map