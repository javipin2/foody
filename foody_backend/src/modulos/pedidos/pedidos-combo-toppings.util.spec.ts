import { BadRequestException } from '@nestjs/common';
import {
  resolverDestinosToppingsCombo,
  validarToppingsAsociadosAProductos,
} from './pedidos-combo-toppings.util';

describe('toppings asociados a platos de combo', () => {
  const platos = [
    { id: 'plato-1', nombre: 'Hamburguesa', cocina_id: 'cocina-1' },
    { id: 'plato-2', nombre: 'Salchipapa', cocina_id: 'cocina-2' },
  ];

  it('infiere el plato cuando un combo legacy contiene uno solo', () => {
    expect(
      resolverDestinosToppingsCombo([{ topping_id: 'top-1' }], [platos[0]]),
    ).toEqual([
      {
        topping_id: 'top-1',
        producto_id: 'plato-1',
        producto_nombre: 'Hamburguesa',
        cocina_id: 'cocina-1',
      },
    ]);
  });

  it('rechaza destinos ambiguos e IDs de platos fuera del combo', () => {
    expect(() =>
      resolverDestinosToppingsCombo([{ topping_id: 'top-1' }], platos),
    ).toThrow(BadRequestException);
    expect(() =>
      resolverDestinosToppingsCombo(
        [{ topping_id: 'top-1', producto_id: 'otro-plato' }],
        platos,
      ),
    ).toThrow(BadRequestException);
  });

  it('requiere la asociación vigente topping↔plato', () => {
    const destinos = resolverDestinosToppingsCombo(
      [
        { topping_id: 'top-1', producto_id: 'plato-1' },
        { topping_id: 'top-1', producto_id: 'plato-2' },
      ],
      platos,
    );
    expect(() =>
      validarToppingsAsociadosAProductos(destinos, [
        { topping_id: 'top-1', producto_id: 'plato-1' },
      ]),
    ).toThrow(BadRequestException);
    expect(() =>
      validarToppingsAsociadosAProductos(destinos, [
        { topping_id: 'top-1', producto_id: 'plato-1' },
        { topping_id: 'top-1', producto_id: 'plato-2' },
      ]),
    ).not.toThrow();
  });
});
