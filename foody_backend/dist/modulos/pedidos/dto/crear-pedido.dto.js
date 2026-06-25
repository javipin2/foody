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
exports.CrearPedidoDto = exports.ComboPedidoDto = exports.ItemPedidoDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
const cobrar_mesa_dto_1 = require("./cobrar-mesa.dto");
class ToppingItemDto {
    topping_id;
}
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], ToppingItemDto.prototype, "topping_id", void 0);
class BebidaItemDto {
    bebida_id;
    cantidad;
}
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], BebidaItemDto.prototype, "bebida_id", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], BebidaItemDto.prototype, "cantidad", void 0);
class ItemPedidoDto {
    producto_id;
    cantidad;
    precio;
    observaciones;
    toppings;
    bebidas;
}
exports.ItemPedidoDto = ItemPedidoDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], ItemPedidoDto.prototype, "producto_id", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], ItemPedidoDto.prototype, "cantidad", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], ItemPedidoDto.prototype, "precio", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], ItemPedidoDto.prototype, "observaciones", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => ToppingItemDto),
    __metadata("design:type", Array)
], ItemPedidoDto.prototype, "toppings", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => BebidaItemDto),
    __metadata("design:type", Array)
], ItemPedidoDto.prototype, "bebidas", void 0);
class ComboPedidoDto {
    combo_id;
    cantidad;
    precio;
}
exports.ComboPedidoDto = ComboPedidoDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], ComboPedidoDto.prototype, "combo_id", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], ComboPedidoDto.prototype, "cantidad", void 0);
__decorate([
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], ComboPedidoDto.prototype, "precio", void 0);
class CrearPedidoDto {
    sucursal_id;
    mesa_id;
    device_id;
    tipo;
    cliente_nombre;
    cliente_telefono;
    direccion_entrega;
    lat;
    lng;
    metodo_pago;
    requiere_factura;
    nit_cliente;
    nombre_fiscal_cliente;
    email_cliente;
    observaciones;
    items;
    combos;
    codigo_promocion;
    idempotency_key;
    pagos;
    propina;
}
exports.CrearPedidoDto = CrearPedidoDto;
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "sucursal_id", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "mesa_id", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "device_id", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['mesa', 'para_llevar', 'domicilio', 'encargo']),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "tipo", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "cliente_nombre", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "cliente_telefono", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "direccion_entrega", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], CrearPedidoDto.prototype, "lat", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    __metadata("design:type", Number)
], CrearPedidoDto.prototype, "lng", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(['efectivo', 'tarjeta', 'transferencia', 'nequi', 'pendiente']),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "metodo_pago", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    __metadata("design:type", Boolean)
], CrearPedidoDto.prototype, "requiere_factura", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "nit_cliente", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "nombre_fiscal_cliente", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "email_cliente", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "observaciones", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => ItemPedidoDto),
    __metadata("design:type", Array)
], CrearPedidoDto.prototype, "items", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => ComboPedidoDto),
    __metadata("design:type", Array)
], CrearPedidoDto.prototype, "combos", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "codigo_promocion", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], CrearPedidoDto.prototype, "idempotency_key", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => cobrar_mesa_dto_1.PagoLineaDto),
    __metadata("design:type", Array)
], CrearPedidoDto.prototype, "pagos", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CrearPedidoDto.prototype, "propina", void 0);
//# sourceMappingURL=crear-pedido.dto.js.map