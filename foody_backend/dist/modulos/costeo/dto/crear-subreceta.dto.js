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
exports.CrearSubrecetaDto = exports.SubrecetaItemDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class SubrecetaItemDto {
    tipo_item;
    ingrediente_id;
    subreceta_id;
    cantidad;
    unidad;
}
exports.SubrecetaItemDto = SubrecetaItemDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['ingrediente', 'subreceta']),
    __metadata("design:type", String)
], SubrecetaItemDto.prototype, "tipo_item", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => (o.tipo_item ?? 'ingrediente') === 'ingrediente'),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], SubrecetaItemDto.prototype, "ingrediente_id", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => o.tipo_item === 'subreceta'),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], SubrecetaItemDto.prototype, "subreceta_id", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0.001),
    __metadata("design:type", Number)
], SubrecetaItemDto.prototype, "cantidad", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], SubrecetaItemDto.prototype, "unidad", void 0);
class CrearSubrecetaDto {
    sucursal_id;
    nombre;
    cantidad_resultado;
    unidad_resultado;
    margen_error;
    usa_produccion_lote;
    items;
}
exports.CrearSubrecetaDto = CrearSubrecetaDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearSubrecetaDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearSubrecetaDto.prototype, "nombre", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0.001),
    __metadata("design:type", Number)
], CrearSubrecetaDto.prototype, "cantidad_resultado", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearSubrecetaDto.prototype, "unidad_resultado", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CrearSubrecetaDto.prototype, "margen_error", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], CrearSubrecetaDto.prototype, "usa_produccion_lote", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMinSize)(1),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => SubrecetaItemDto),
    __metadata("design:type", Array)
], CrearSubrecetaDto.prototype, "items", void 0);
//# sourceMappingURL=crear-subreceta.dto.js.map