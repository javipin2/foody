import { BadRequestException } from '@nestjs/common';
import { CatalogoService } from './catalogo.service';

describe('CatalogoService — referencias de producto limitadas a la sede', () => {
  let database: { consultarUno: jest.Mock; consultar: jest.Mock };
  let service: CatalogoService;

  beforeEach(() => {
    database = {
      consultarUno: jest.fn(),
      consultar: jest.fn(),
    };
    service = new CatalogoService(
      database as never,
      { recalcularProductoPorId: jest.fn() } as never,
      { catalogoDisponibilidad: jest.fn() } as never,
      { assertLimiteProductos: jest.fn() } as never,
      { invalidar: jest.fn().mockResolvedValue(undefined) } as never,
    );
  });

  it('rechaza una categoría que no pertenece a la sede antes de insertar', async () => {
    database.consultarUno.mockResolvedValueOnce(null);

    await expect(
      service.crearProducto({
        sucursal_id: 'sede-1',
        categoria_id: 'categoria-ajena',
        nombre: 'Producto',
        precio: 10000,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(database.consultarUno).toHaveBeenCalledTimes(1);
    expect(database.consultarUno.mock.calls[0][0]).toContain(
      'sucursal_id = $2 AND activa = true',
    );
    expect(
      database.consultarUno.mock.calls.some((call) =>
        String(call[0]).includes('INSERT INTO productos'),
      ),
    ).toBe(false);
  });

  it('no publica un producto si la sede no tiene cocina activa', async () => {
    database.consultarUno
      .mockResolvedValueOnce({ id: 'categoria-1' })
      .mockResolvedValueOnce(null);

    await expect(
      service.crearProducto({
        sucursal_id: 'sede-1',
        categoria_id: 'categoria-1',
        nombre: 'Producto',
        precio: 10000,
      }),
    ).rejects.toMatchObject({
      response: {
        error: 'COCINA_REQUERIDA',
      },
    });

    expect(database.consultarUno).toHaveBeenCalledTimes(2);
  });

  it('rechaza una cocina de otra sede en vez de guardar una línea invisible para KDS', async () => {
    database.consultarUno
      .mockResolvedValueOnce({ id: 'categoria-1' })
      .mockResolvedValueOnce(null);

    await expect(
      service.crearProducto({
        sucursal_id: 'sede-1',
        categoria_id: 'categoria-1',
        cocina_id: 'cocina-ajena',
        nombre: 'Producto',
        precio: 10000,
      }),
    ).rejects.toMatchObject({
      response: {
        error: 'COCINA_NO_DISPONIBLE',
      },
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(2);
  });

  it('no crea una bebida vendible sin cocina activa en la sede', async () => {
    database.consultarUno.mockResolvedValueOnce(null);

    await expect(
      service.crearBebida({
        sucursal_id: 'sede-1',
        nombre: 'Gaseosa',
        precio: 5000,
      }),
    ).rejects.toMatchObject({
      response: { error: 'COCINA_REQUERIDA' },
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(1);
  });

  it('usa una cocina activa de la misma sede como predeterminada', async () => {
    database.consultarUno
      .mockResolvedValueOnce({ id: 'categoria-1' })
      .mockResolvedValueOnce({ id: 'cocina-1' })
      .mockResolvedValueOnce({ id: 'producto-1' });

    await service.crearProducto({
      sucursal_id: 'sede-1',
      categoria_id: 'categoria-1',
      nombre: 'Producto',
      precio: 10000,
    });

    const insert = database.consultarUno.mock.calls[2];
    expect(insert[0]).toContain('INSERT INTO productos');
    expect(insert[1][0]).toBe('sede-1');
    expect(insert[1][1]).toBe('categoria-1');
    expect(insert[1][2]).toBe('cocina-1');
  });

  it('no permite activar un producto antiguo sin cocina asignada', async () => {
    database.consultarUno.mockResolvedValueOnce({
      id: 'producto-1',
      disponible: false,
      cocina_id: null,
    });

    await expect(
      service.cambiarDisponibilidad('producto-1', 'sede-1', true),
    ).rejects.toMatchObject({
      response: {
        error: 'COCINA_REQUERIDA',
      },
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(1);
  });

  it('no permite mover un producto a una categoría de otra sede', async () => {
    database.consultarUno
      .mockResolvedValueOnce({
        id: 'producto-1',
        disponible: true,
        cocina_id: 'cocina-1',
      })
      .mockResolvedValueOnce(null);

    await expect(
      service.actualizarProducto('producto-1', 'sede-1', {
        categoria_id: 'categoria-ajena',
      }),
    ).rejects.toMatchObject({
      response: { error: 'CATEGORIA_NO_DISPONIBLE' },
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(2);
  });

  it('no permite mover un producto a una cocina de otra sede', async () => {
    database.consultarUno
      .mockResolvedValueOnce({
        id: 'producto-1',
        disponible: true,
        cocina_id: 'cocina-1',
      })
      .mockResolvedValueOnce(null);

    await expect(
      service.actualizarProducto('producto-1', 'sede-1', {
        cocina_id: 'cocina-ajena',
      }),
    ).rejects.toMatchObject({
      response: { error: 'COCINA_NO_DISPONIBLE' },
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(2);
  });
});
