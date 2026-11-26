import {
  huellaIdempotenciaPedido,
  validarTotalEsperadoPedido,
} from './pedidos-idempotencia.util';

describe('huellaIdempotenciaPedido', () => {
  it('ignora el orden de claves y la propia clave idempotente', () => {
    const a = huellaIdempotenciaPedido({
      idempotency_key: 'key-a',
      sucursal_id: 'branch-a',
      items: [{ producto_id: 'product-a', cantidad: 1 }],
    });
    const b = huellaIdempotenciaPedido({
      items: [{ cantidad: 1, producto_id: 'product-a' }],
      sucursal_id: 'branch-a',
      idempotency_key: 'key-b',
    });

    expect(a).toBe(b);
  });

  it('distingue cambios en el contenido funcional', () => {
    const base = huellaIdempotenciaPedido({
      sucursal_id: 'branch-a',
      items: [{ producto_id: 'product-a', cantidad: 1 }],
    });
    const modificado = huellaIdempotenciaPedido({
      sucursal_id: 'branch-a',
      items: [{ producto_id: 'product-a', cantidad: 2 }],
    });

    expect(modificado).not.toBe(base);
  });

  it('no cambia la huella al refrescar solo la precondición de total', () => {
    const a = huellaIdempotenciaPedido({
      sucursal_id: 'branch-a',
      items: [{ producto_id: 'product-a', cantidad: 1 }],
      total_esperado: 12000,
    });
    const b = huellaIdempotenciaPedido({
      sucursal_id: 'branch-a',
      items: [{ producto_id: 'product-a', cantidad: 1 }],
      total_esperado: 12500,
    });

    expect(a).toBe(b);
  });

  it('rechaza el cobro si la cotización no coincide y acepta tolerancia de un centavo', () => {
    expect(() =>
      validarTotalEsperadoPedido(12000, 12500, {
        subtotal: 12500,
        costoDomicilio: 0,
        descuento: 0,
      }),
    ).toThrow(
      expect.objectContaining({
        response: expect.objectContaining({
          error: 'TOTAL_PEDIDO_CAMBIO',
          total_esperado: 12000,
          total_actual: 12500,
        }),
      }),
    );
    expect(() =>
      validarTotalEsperadoPedido(12000, 12000.01, {
        subtotal: 12000.01,
        costoDomicilio: 0,
        descuento: 0,
      }),
    ).not.toThrow();
  });

  it('exige la precondición antes del cobro inmediato', () => {
    expect(() =>
      validarTotalEsperadoPedido(undefined, 12000, {
        subtotal: 12000,
        costoDomicilio: 0,
        descuento: 0,
      }),
    ).toThrow(
      expect.objectContaining({
        response: expect.objectContaining({
          error: 'TOTAL_ESPERADO_REQUERIDO',
        }),
      }),
    );
  });
});
