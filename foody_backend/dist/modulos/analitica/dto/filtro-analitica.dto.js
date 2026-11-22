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
exports.FiltroAnaliticaDto = exports.PRESETS_ANALITICA = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
exports.PRESETS_ANALITICA = [
    'hoy',
    'ayer',
    'semana',
    'mes',
    'mes_anterior',
    '7d',
    '30d',
    'anio',
    'rango',
];
function aLista(value) {
    if (value == null || value === '')
        return undefined;
    const raw = Array.isArray(value) ? value : String(value).split(',');
    const list = raw.map((v) => String(v).trim()).filter(Boolean);
    return list.length ? list : undefined;
}
function aEntero(value) {
    if (value == null || value === '')
        return undefined;
    const n = Number(value);
    return Number.isFinite(n) ? n : undefined;
}
class FiltroAnaliticaDto {
    preset;
    desde;
    hasta;
    comparar;
    comparar_desde;
    comparar_hasta;
    sucursal_id;
    hora_desde;
    hora_hasta;
    estados;
    incluir_cancelados;
    item_estados_cocina;
    solo_pendiente_pago;
    solo_facturados;
    mesera_ids;
    cocina_ids;
    producto_ids;
    categoria_ids;
    domiciliario_ids;
    caja_ids;
    cajero_ids;
    metodos_pago;
    cliente_telefono;
    device_id;
    cliente_segmento;
    formato;
    limite;
}
exports.FiltroAnaliticaDto = FiltroAnaliticaDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)([...exports.PRESETS_ANALITICA]),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "preset", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "desde", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "hasta", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBooleanString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "comparar", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "comparar_desde", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "comparar_hasta", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aEntero(value)),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(23),
    __metadata("design:type", Number)
], FiltroAnaliticaDto.prototype, "hora_desde", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aEntero(value)),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(23),
    __metadata("design:type", Number)
], FiltroAnaliticaDto.prototype, "hora_hasta", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "estados", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBooleanString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "incluir_cancelados", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "item_estados_cocina", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBooleanString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "solo_pendiente_pago", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBooleanString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "solo_facturados", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "mesera_ids", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "cocina_ids", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "producto_ids", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "categoria_ids", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "domiciliario_ids", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "caja_ids", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "cajero_ids", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aLista(value)),
    (0, class_validator_1.IsString)({ each: true }),
    __metadata("design:type", Array)
], FiltroAnaliticaDto.prototype, "metodos_pago", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "cliente_telefono", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "device_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['frecuente', 'nuevo', 'todos']),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "cliente_segmento", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['csv', 'xlsx']),
    __metadata("design:type", String)
], FiltroAnaliticaDto.prototype, "formato", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Transform)(({ value }) => aEntero(value)),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(50),
    __metadata("design:type", Number)
], FiltroAnaliticaDto.prototype, "limite", void 0);
//# sourceMappingURL=filtro-analitica.dto.js.map