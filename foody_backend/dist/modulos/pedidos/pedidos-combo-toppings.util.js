"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolverDestinosToppingsCombo = resolverDestinosToppingsCombo;
exports.validarToppingsAsociadosAProductos = validarToppingsAsociadosAProductos;
const common_1 = require("@nestjs/common");
function resolverDestinosToppingsCombo(selecciones, productos) {
    const porId = new Map(productos.map((producto) => [producto.id.toLowerCase(), producto]));
    const ids = [...porId.keys()];
    return selecciones.map((seleccion) => {
        const productoId = seleccion.producto_id?.toLowerCase() ??
            (ids.length === 1 ? ids[0] : null);
        if (!productoId) {
            throw new common_1.BadRequestException({
                error: 'COMBO_TOPPING_REQUIERE_PRODUCTO',
                message: 'Indica a cuál plato del combo se agrega cada topping.',
            });
        }
        const producto = porId.get(productoId);
        if (!producto) {
            throw new common_1.BadRequestException({
                error: 'COMBO_TOPPING_PRODUCTO_INVALIDO',
                message: 'El plato elegido no pertenece a este combo.',
            });
        }
        return {
            topping_id: seleccion.topping_id,
            producto_id: producto.id,
            producto_nombre: producto.nombre,
            cocina_id: producto.cocina_id,
        };
    });
}
function validarToppingsAsociadosAProductos(destinos, asociaciones) {
    const pares = new Set(asociaciones.map((asociacion) => `${asociacion.producto_id.toLowerCase()}:${asociacion.topping_id.toLowerCase()}`));
    for (const destino of destinos) {
        if (pares.has(`${destino.producto_id.toLowerCase()}:${destino.topping_id.toLowerCase()}`)) {
            continue;
        }
        throw new common_1.BadRequestException({
            error: 'TOPPING_NO_DISPONIBLE_PARA_PRODUCTO',
            message: 'Ese topping no está habilitado para el plato elegido.',
        });
    }
}
//# sourceMappingURL=pedidos-combo-toppings.util.js.map