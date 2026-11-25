import { ConfigService } from '@nestjs/config';
import { RealtimeBroadcastService } from './realtime-broadcast.service';

describe('RealtimeBroadcastService.pedidoDesasignadoIndep', () => {
  it('emite el cambio al canal privado del domiciliario independiente', async () => {
    const service = new RealtimeBroadcastService({
      get: jest.fn().mockReturnValue(undefined),
    } as unknown as ConfigService);
    const testable = service as unknown as {
      enviarBroadcast: (
        canal: string,
        evento: string,
        payload: Record<string, unknown>,
      ) => Promise<void>;
    };
    const enviar = jest
      .spyOn(testable, 'enviarBroadcast')
      .mockResolvedValue(undefined);

    await service.pedidoDesasignadoIndep('dom-1', {
      pedido_id: 'pedido-1',
      accion: 'cancelado',
    });

    expect(enviar).toHaveBeenCalledWith(
      service.topicDomiciliarioIndep('dom-1'),
      'pedido_desasignado',
      {
        domiciliario_id: 'dom-1',
        pedido_id: 'pedido-1',
        accion: 'cancelado',
      },
    );
  });
});
