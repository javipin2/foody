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
exports.GuardarConfigFiscalDto = void 0;
const class_validator_1 = require("class-validator");
class GuardarConfigFiscalDto {
    sucursal_id;
    nit;
    razon_social;
    regimen;
    aplica_iva;
    porcentaje_iva;
    resolucion_dian;
    prefijo_factura;
}
exports.GuardarConfigFiscalDto = GuardarConfigFiscalDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], GuardarConfigFiscalDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GuardarConfigFiscalDto.prototype, "nit", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GuardarConfigFiscalDto.prototype, "razon_social", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['simplificado', 'comun']),
    __metadata("design:type", String)
], GuardarConfigFiscalDto.prototype, "regimen", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], GuardarConfigFiscalDto.prototype, "aplica_iva", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(100),
    __metadata("design:type", Number)
], GuardarConfigFiscalDto.prototype, "porcentaje_iva", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GuardarConfigFiscalDto.prototype, "resolucion_dian", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], GuardarConfigFiscalDto.prototype, "prefijo_factura", void 0);
//# sourceMappingURL=guardar-config-fiscal.dto.js.map