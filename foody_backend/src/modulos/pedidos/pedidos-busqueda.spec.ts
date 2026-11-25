import { PedidosService } from './pedidos.service';

describe('PedidosService búsqueda administrativa', () => {
  it('filtra en SQL por texto y mantiene el scope de sucursal/paginación', async () => {
    const database = {
      consultar: jest.fn().mockResolvedValue([]),
      consultarUno: jest.fn().mockResolvedValue({ count: 0 }),
    };
    const service = new PedidosService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    await service.listarPorSucursal('sucursal-1', {
      soloActivos: true,
      paginar: true,
      page: 1,
      limite: 6,
      busqueda: 'Ana',
    });

    const [sql, params] = database.consultar.mock.calls[0];
    expect(sql).toContain('p.sucursal_id = $1');
    expect(sql).toContain("p.estado IN ('pendiente'");
    expect(sql).toContain('p.numero_pedido::text ILIKE $2');
    expect(sql).toContain("COALESCE(m.nombre, '') ILIKE $2");
    expect(sql).toContain('LIMIT $3 OFFSET $4');
    expect(params).toEqual(['sucursal-1', '%Ana%', 6, 0]);

    const [countSql, countParams] = database.consultarUno.mock.calls[0];
    expect(countSql).toContain('p.cliente_telefono');
    expect(countParams).toEqual(['sucursal-1', '%Ana%']);
  });
});
