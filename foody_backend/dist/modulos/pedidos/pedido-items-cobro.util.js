"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validarLineaSinCobroAsignado = validarLineaSinCobroAsignado;
const common_1 = require("@nestjs/common");
function validarLineaSinCobroAsignado(estadoCobro, tienePagoAsociado) {
    if (estadoCobro !== 'cobrado' && !tienePagoAsociado)
        return;
    throw new common_1.ConflictException({
        error: 'ITEM_REQUIERE_AJUSTE_COBRO',
        message: 'Este producto ya tiene un cobro asignado. Ajusta el cobro o registra el reembolso antes de modificar su importe.',
    });
}
//# sourceMappingURL=pedido-items-cobro.util.js.map