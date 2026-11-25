import { NotificacionesService } from './notificaciones.service';

describe('NotificacionesService — aislamiento QA externo', () => {
  const original = process.env.FOODY_QA_SIN_EFECTOS;

  afterEach(() => {
    if (original === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
    else process.env.FOODY_QA_SIN_EFECTOS = original;
  });

  it('no lee, reintenta ni envía la cola FCM en QA aislada', async () => {
    process.env.FOODY_QA_SIN_EFECTOS = '1';
    const database = { consultar: jest.fn(), consultarUno: jest.fn() };
    const fcm = { estaListo: jest.fn(() => true), enviarMulticast: jest.fn() };
    const service = new NotificacionesService(database as never, fcm as never);

    await expect(service.procesarPendientes()).resolves.toEqual({
      procesadas: 0,
      enviados: 0,
      abandonadas: 0,
      modo: 'qa_sin_efectos',
    });
    expect(database.consultar).not.toHaveBeenCalled();
    expect(database.consultarUno).not.toHaveBeenCalled();
    expect(fcm.estaListo).not.toHaveBeenCalled();
    expect(fcm.enviarMulticast).not.toHaveBeenCalled();
  });
});
