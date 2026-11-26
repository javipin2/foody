import { PoolClient } from 'pg';
import { CatalogoService } from './catalogo.service';

describe('CatalogoService.crearTopping — asociaciones por plato', () => {
  const crearServicio = (rowsValidos: string[]) => {
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('FROM productos p')) {
        return { rows: rowsValidos.map((id) => ({ id })) };
      }
      if (sql.includes('INSERT INTO toppings')) {
        return {
          rows: [
            {
              id: 'topping-1',
              nombre: 'Queso',
              precio: '1000',
              disponible: true,
            },
          ],
        };
      }
      return { rows: [] };
    });
    const client = { query } as unknown as PoolClient;
    const database = {
      enTransaccion: jest.fn((fn: (tx: PoolClient) => unknown) => fn(client)),
    };
    const menuCache = { invalidar: jest.fn() };
    const service = new CatalogoService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      menuCache as never,
    );
    return { service, query, menuCache };
  };

  it('crea el topping y liga los platos en la misma transacción', async () => {
    const { service, query, menuCache } = crearServicio(['plato-1', 'plato-2']);

    await expect(
      service.crearTopping({
        sucursal_id: 'sucursal-1',
        nombre: 'Queso',
        precio: 1000,
        producto_ids: ['plato-1', 'plato-2', 'plato-1'],
      }),
    ).resolves.toMatchObject({
      id: 'topping-1',
      producto_ids: ['plato-1', 'plato-2'],
    });
    const asociacion = query.mock.calls.find(([sql]) =>
      sql.includes('INSERT INTO producto_toppings'),
    );
    expect(asociacion?.[1]).toEqual([['plato-1', 'plato-2'], 'topping-1']);
    expect(menuCache.invalidar).toHaveBeenCalledWith('sucursal-1');
  });

  it('no crea el topping si una asociación no es un plato válido de la sede', async () => {
    const { service, query } = crearServicio(['plato-1']);

    await expect(
      service.crearTopping({
        sucursal_id: 'sucursal-1',
        nombre: 'Tocineta',
        precio: 1500,
        producto_ids: ['plato-1', 'bebida-1'],
      }),
    ).rejects.toMatchObject({
      response: { error: 'TOPPING_PRODUCTO_INVALIDO' },
    });
    expect(query).not.toHaveBeenCalledWith(
      expect.stringContaining('INSERT INTO toppings'),
      expect.anything(),
    );
  });
});
