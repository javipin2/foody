import { ConfigService } from '@nestjs/config';
import { WompiService } from './wompi.service';

describe('WompiService en QA aislada', () => {
  const originalQa = process.env.FOODY_QA_SIN_EFECTOS;
  let fetchSpy: jest.SpyInstance;

  beforeEach(() => {
    process.env.FOODY_QA_SIN_EFECTOS = '1';
    fetchSpy = jest.spyOn(global, 'fetch');
  });

  afterEach(() => {
    fetchSpy.mockRestore();
    if (originalQa === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
    else process.env.FOODY_QA_SIN_EFECTOS = originalQa;
  });

  it('no reporta configuración aunque existan claves y no llama al proveedor', async () => {
    const config = {
      get: jest.fn((clave: string) =>
        clave === 'WOMPI_PRIVATE_KEY'
          ? 'private_prod_test'
          : clave === 'WOMPI_EVENTS_SECRET'
            ? 'event_secret_test'
            : 'public_test',
      ),
    } as unknown as ConfigService;
    const wompi = new WompiService(config);

    expect(wompi.estaConfigurado()).toBe(false);
    await expect(
      wompi.crearEnlacePago({
        nombre: 'QA',
        descripcion: 'QA',
        montoCentavos: 5000,
        referenciaInterna: 'qa-test',
      }),
    ).rejects.toThrow('Wompi no configurado');
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
