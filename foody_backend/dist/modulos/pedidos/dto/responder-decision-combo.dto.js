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
exports.ResponderDecisionComboDto = void 0;
const class_validator_1 = require("class-validator");
class ResponderDecisionComboDto {
    accion;
    cotizacion_version;
    total_aceptado;
    motivo;
}
exports.ResponderDecisionComboDto = ResponderDecisionComboDto;
__decorate([
    (0, class_validator_1.IsIn)(['aceptar_sustitucion', 'cancelar_combo']),
    __metadata("design:type", String)
], ResponderDecisionComboDto.prototype, "accion", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => o.accion === 'aceptar_sustitucion'),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], ResponderDecisionComboDto.prototype, "cotizacion_version", void 0);
__decorate([
    (0, class_validator_1.ValidateIf)((o) => o.accion === 'aceptar_sustitucion'),
    (0, class_validator_1.IsNumber)({ maxDecimalPlaces: 2 }),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], ResponderDecisionComboDto.prototype, "total_aceptado", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(300),
    __metadata("design:type", String)
], ResponderDecisionComboDto.prototype, "motivo", void 0);
//# sourceMappingURL=responder-decision-combo.dto.js.map