import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../database/database.service';
import { ImpresionService } from './impresion.service';

describe('ImpresionService QA isolation', () => {
  const envAnterior = process.env.FOODY_QA_SIN_EFECTOS;

  afterEach(() => {
    if (envAnterior === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
    else process.env.FOODY_QA_SIN_EFECTOS = envAnterior;
    jest.restoreAllMocks();
  });

  it('does not drain queued jobs or ping the local printer agent in isolated QA', async () => {
    process.env.FOODY_QA_SIN_EFECTOS = '1';
    const database = {
      consultar: jest.fn().mockResolvedValue([]),
    } as unknown as DatabaseService;
    const config = {
      get: jest.fn().mockReturnValue('ws://127.0.0.1:8765'),
    } as unknown as ConfigService;
    const service = new ImpresionService(database, config);
    const enviarWs = jest.spyOn(service as never, 'enviarWs' as never);

    await service.procesarColaManual();
    const estado = await service.verificarAgente();

    expect(database.consultar).not.toHaveBeenCalled();
    expect(enviarWs).not.toHaveBeenCalled();
    expect(estado).toEqual({
      conectado: false,
      url: 'ws://127.0.0.1:8765',
      mensaje: 'Agente de impresión desactivado en QA aislada',
    });
  });

  it('continues processing normally when QA isolation is not enabled', async () => {
    delete process.env.FOODY_QA_SIN_EFECTOS;
    const database = {
      consultar: jest.fn().mockResolvedValue([]),
    } as unknown as DatabaseService;
    const config = {
      get: jest.fn(),
    } as unknown as ConfigService;
    const service = new ImpresionService(database, config);

    await service.procesarColaManual();

    expect(database.consultar).toHaveBeenCalledTimes(1);
  });
});
