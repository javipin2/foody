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
exports.ConfigurarRecetaProductoDto = exports.RecetaItemDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class RecetaItemDto {
    tipo_item;
    ingrediente_id;
    subreceta_id;
    cantidad;
    unidad;
}
exports.RecetaItemDto = RecetaItemDto;
__decorate([
    (0, class_validator_1.IsIn)(['ingrediente', 'subreceta', 'empaque']),
    __metadata("design:type", String)
], RecetaItemDto.prototype, "tipo_item", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => o.tipo_item === 'ingrediente' || o.tipo_item === 'empaque'),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], RecetaItemDto.prototype, "ingrediente_id", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => o.tipo_item === 'subreceta'),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], RecetaItemDto.prototype, "subreceta_id", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0.001),
    __metadata("design:type", Number)
], RecetaItemDto.prototype, "cantidad", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], RecetaItemDto.prototype, "unidad", void 0);
class ConfigurarRecetaProductoDto {
    producto_id;
    tipo_entidad;
    items;
    margen_error;
}
exports.ConfigurarRecetaProductoDto = ConfigurarRecetaProductoDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], ConfigurarRecetaProductoDto.prototype, "producto_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['producto', 'bebida', 'topping']),
    __metadata("design:type", String)
], ConfigurarRecetaProductoDto.prototype, "tipo_entidad", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMinSize)(1),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => RecetaItemDto),
    __metadata("design:type", Array)
], ConfigurarRecetaProductoDto.prototype, "items", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], ConfigurarRecetaProductoDto.prototype, "margen_error", void 0);
//# sourceMappingURL=configurar-receta-producto.dto.js.map