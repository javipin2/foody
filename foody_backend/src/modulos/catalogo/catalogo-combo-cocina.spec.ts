import { PoolClient } from 'pg';
import { CatalogoService } from './catalogo.service';

describe('CatalogoService.crearCombo — cocina por componente', () => {
  it('acepta productos del combo asignados a cocinas distintas', async () => {
    const query = jest.fn(async (sql: string) => {
      if (sql.includes('INSERT INTO combos')) {
        return { rows: [{ id: 'combo-1' }] };
      }
      if (sql.includes('SELECT id FROM productos')) {
        return { rows: [{ id: 'producto-1' }] };
      }
      if (sql.includes('INSERT INTO combo_items')) {
        return { rows: [] };
      }
      if (sql.includes('SELECT DISTINCT cocina_id FROM productos')) {
        return {
          rows: [{ cocina_id: 'cocina-1' }, { cocina_id: 'cocina-2' }],
        };
      }
      throw new Error(`Consulta inesperada: ${sql}`);
    });
    const database = {
      enTransaccion: jest.fn(async (callback: (tx: PoolClient) => unknown) =>
        callback({ query } as unknown as PoolClient),
      ),
    };
    const menuCache = { invalidar: jest.fn() };
    const service = new CatalogoService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      menuCache as never,
    );

    await expect(
      service.crearCombo({
        sucursal_id: 'sucursal-1',
        nombre: 'Combo mixto',
        precio_fijo: 25000,
        items: [
          { tipo_item: 'producto', item_id: 'producto-1', cantidad: 1 },
          { tipo_item: 'producto', item_id: 'producto-2', cantidad: 1 },
        ],
      }),
    ).resolves.toMatchObject({ id: 'combo-1', nombre: 'Combo mixto' });
    expect(menuCache.invalidar).toHaveBeenCalledWith('sucursal-1');
  });
});
