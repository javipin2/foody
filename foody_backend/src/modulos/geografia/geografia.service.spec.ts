import { BadGatewayException, GatewayTimeoutException } from '@nestjs/common';
import { GeografiaService } from './geografia.service';

describe('GeografiaService', () => {
  const qaOriginal = process.env.FOODY_QA_SIN_EFECTOS;
  let fetchSpy: jest.SpyInstance;

  beforeEach(() => {
    delete process.env.FOODY_QA_SIN_EFECTOS;
    fetchSpy = jest.spyOn(global, 'fetch');
  });

  afterEach(() => {
    fetchSpy.mockRestore();
    if (qaOriginal === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
    else process.env.FOODY_QA_SIN_EFECTOS = qaOriginal;
  });

  it('envía señal de timeout de cinco segundos y cachea respuestas correctas', async () => {
    fetchSpy.mockResolvedValue(
      new Response(
        JSON.stringify({
          features: [
            {
              geometry: { coordinates: [-74.1, 4.6] },
              properties: { name: 'Bogotá', street: 'Calle 10' },
            },
          ],
        }),
        { status: 200 },
      ),
    );
    const service = new GeografiaService();

    const primero = await service.buscarDirecciones('Calle 10 Bogotá');
    const segundo = await service.buscarDirecciones('calle 10 bogotá');

    expect(primero).toEqual([
      { etiqueta: 'Bogotá, Calle 10', lat: 4.6, lng: -74.1 },
    ]);
    expect(segundo).toEqual(primero);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const signal = fetchSpy.mock.calls[0][1].signal as AbortSignal;
    expect(signal).toBeInstanceOf(AbortSignal);
    expect(signal.aborted).toBe(false);
  });

  it('responde timeout 504 cuando Photon vence el límite', async () => {
    const timeoutSignal = AbortSignal.abort(
      new DOMException('timeout', 'TimeoutError'),
    );
    const timeoutSpy = jest
      .spyOn(AbortSignal, 'timeout')
      .mockReturnValue(timeoutSignal);
    fetchSpy.mockRejectedValue(timeoutSignal.reason);
    const service = new GeografiaService();

    await expect(
      service.buscarDirecciones('Calle 10 Bogotá'),
    ).rejects.toBeInstanceOf(GatewayTimeoutException);
    expect(timeoutSpy).toHaveBeenCalledWith(5000);
    timeoutSpy.mockRestore();
  });

  it('traduce errores de red y respuestas HTTP fallidas como 502', async () => {
    const service = new GeografiaService();
    fetchSpy.mockRejectedValueOnce(new TypeError('network down'));
    await expect(
      service.buscarDirecciones('Calle 10 Bogotá'),
    ).rejects.toBeInstanceOf(BadGatewayException);

    fetchSpy.mockResolvedValueOnce(new Response('', { status: 503 }));
    await expect(
      service.buscarDirecciones('Carrera 20 Bogotá'),
    ).rejects.toBeInstanceOf(BadGatewayException);
  });
});
