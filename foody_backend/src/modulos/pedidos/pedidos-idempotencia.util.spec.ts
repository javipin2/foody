import { huellaIdempotenciaPedido } from './pedidos-idempotencia.util';

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
});
