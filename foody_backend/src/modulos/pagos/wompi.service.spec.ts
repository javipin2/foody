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

  it('consulta transacciones del lado servidor con la llave privada', async () => {
    const clavePublica = process.env.FOODY_QA_SIN_EFECTOS;
    delete process.env.FOODY_QA_SIN_EFECTOS;
    const config = {
      get: jest.fn((clave: string) => {
        const valores: Record<string, string> = {
          WOMPI_PUBLIC_KEY: 'pub_test_publica',
          WOMPI_PRIVATE_KEY: 'prv_test_privada',
          WOMPI_AMBIENTE: 'sandbox',
        };
        return valores[clave];
      }),
    } as unknown as ConfigService;
    const respuesta = {
      ok: true,
      statusText: 'OK',
      json: jest.fn().mockResolvedValue({
        data: {
          id: 'tx-123',
          status: 'APPROVED',
          reference: 'fdy-ref-1',
          amount_in_cents: 500000,
        },
      }),
    };
    fetchSpy.mockResolvedValue(respuesta as never);
    const wompi = new WompiService(config);

    try {
      await expect(wompi.consultarTransaccion('tx/123')).resolves.toMatchObject({
        id: 'tx-123',
        status: 'APPROVED',
        reference: 'fdy-ref-1',
      });
      expect(fetchSpy).toHaveBeenCalledWith(
        'https://sandbox.wompi.co/v1/transactions/tx%2F123',
        { headers: { Authorization: 'Bearer prv_test_privada' } },
      );
    } finally {
      if (clavePublica === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
      else process.env.FOODY_QA_SIN_EFECTOS = clavePublica;
    }
  });
});
