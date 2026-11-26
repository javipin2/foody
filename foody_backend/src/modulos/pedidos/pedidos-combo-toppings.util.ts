import { BadRequestException } from '@nestjs/common';

export type ProductoComboTopping = {
  id: string;
  nombre: string;
  cocina_id: string | null;
};

export type SeleccionToppingCombo = {
  topping_id: string;
  producto_id?: string;
};

export type DestinoToppingCombo = {
  topping_id: string;
  producto_id: string;
  producto_nombre: string;
  cocina_id: string | null;
};

export function resolverDestinosToppingsCombo(
  selecciones: SeleccionToppingCombo[],
  productos: ProductoComboTopping[],
): DestinoToppingCombo[] {
  const porId = new Map(
    productos.map((producto) => [producto.id.toLowerCase(), producto]),
  );
  const ids = [...porId.keys()];

  return selecciones.map((seleccion) => {
    const productoId =
      seleccion.producto_id?.toLowerCase() ??
      (ids.length === 1 ? ids[0] : null);
    if (!productoId) {
      throw new BadRequestException({
        error: 'COMBO_TOPPING_REQUIERE_PRODUCTO',
        message: 'Indica a cuál plato del combo se agrega cada topping.',
      });
    }
    const producto = porId.get(productoId);
    if (!producto) {
      throw new BadRequestException({
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

export function validarToppingsAsociadosAProductos(
  destinos: DestinoToppingCombo[],
  asociaciones: { producto_id: string; topping_id: string }[],
): void {
  const pares = new Set(
    asociaciones.map(
      (asociacion) =>
        `${asociacion.producto_id.toLowerCase()}:${asociacion.topping_id.toLowerCase()}`,
    ),
  );
  for (const destino of destinos) {
    if (
      pares.has(
        `${destino.producto_id.toLowerCase()}:${destino.topping_id.toLowerCase()}`,
      )
    ) {
      continue;
    }
    throw new BadRequestException({
      error: 'TOPPING_NO_DISPONIBLE_PARA_PRODUCTO',
      message: 'Ese topping no está habilitado para el plato elegido.',
    });
  }
}
