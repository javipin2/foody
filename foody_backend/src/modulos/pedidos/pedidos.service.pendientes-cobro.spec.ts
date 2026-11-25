import { PedidosService } from './pedidos.service';

describe('PedidosService — domicilios entregados con saldo', () => {
  const crearServicio = () => {
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
      {} as never,
    );
    return { database, service };
  };

  it('incluye domicilio entregado con saldo en la lista operativa', async () => {
    const { database, service } = crearServicio();

    await service.listarPorSucursal('sucursal-1', {
      soloActivos: true,
      limite: 20,
    });

    const sql = database.consultar.mock.calls[0][0] as string;
    expect(sql).toContain("p.estado = 'entregado'");
    expect(sql).toContain("p.tipo = 'domicilio'");
    expect(sql).toContain('COALESCE(p.monto_pagado, 0) < p.total - 0.01');
  });

  it('no presenta domicilio entregado impago en Cerrados', async () => {
    const { database, service } = crearServicio();

    await service.listarCerradosHoy('sucursal-1', { limite: 20 });

    const sql = database.consultar.mock.calls[0][0] as string;
    expect(sql).toContain("p.estado = 'entregado'");
    expect(sql).toContain('COALESCE(p.monto_pagado, 0) >= p.total - 0.01');
  });
});
