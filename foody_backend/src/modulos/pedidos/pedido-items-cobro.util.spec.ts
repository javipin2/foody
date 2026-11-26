import { validarLineaSinCobroAsignado } from './pedido-items-cobro.util';

describe('validarLineaSinCobroAsignado', () => {
  it.each([
    ['cobrado', false],
    ['pendiente', true],
  ])('bloquea estado=%s, pago asociado=%s', (estado, asociado) => {
    expect(() => validarLineaSinCobroAsignado(estado, asociado)).toThrow(
      expect.objectContaining({
        response: expect.objectContaining({
          error: 'ITEM_REQUIERE_AJUSTE_COBRO',
        }),
      }),
    );
  });

  it('permite la línea pendiente sin pago asociado', () => {
    expect(() =>
      validarLineaSinCobroAsignado('pendiente', false),
    ).not.toThrow();
  });
});
