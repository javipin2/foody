import { BadRequestException } from '@nestjs/common';
import { CocinasService } from './cocinas.service';

describe('CocinasService: desactivación segura de cocina', () => {
  function crearServicio(uso: {
    productos_disponibles: string;
    items_pendientes: string;
  }) {
    const database = {
      consultarUno: jest
        .fn()
        .mockResolvedValueOnce({ id: 'cocina-1' })
        .mockResolvedValueOnce(uso),
      consultar: jest.fn().mockResolvedValue([]),
    };
    const service = new CocinasService(
      database as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    return { service, database };
  }

  it('bloquea desactivar una cocina con productos disponibles', async () => {
    const { service, database } = crearServicio({
      productos_disponibles: '2',
      items_pendientes: '0',
    });

    await expect(
      service.actualizarCocina('cocina-1', 'sucursal-1', { activa: false }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(database.consultar).not.toHaveBeenCalled();
  });

  it('bloquea desactivar una cocina con ítems operativos pendientes', async () => {
    const { service, database } = crearServicio({
      productos_disponibles: '0',
      items_pendientes: '1',
    });

    await expect(
      service.actualizarCocina('cocina-1', 'sucursal-1', { activa: false }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(database.consultar).not.toHaveBeenCalled();
  });

  it('permite desactivar una cocina vacía y sin pedidos pendientes', async () => {
    const { service, database } = crearServicio({
      productos_disponibles: '0',
      items_pendientes: '0',
    });

    await expect(
      service.actualizarCocina('cocina-1', 'sucursal-1', { activa: false }),
    ).resolves.toEqual({ id: 'cocina-1' });
    expect(database.consultar).toHaveBeenCalledTimes(1);
    expect(database.consultar).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE cocinas SET activa = $1'),
      [false, 'cocina-1', 'sucursal-1'],
    );
  });
});
