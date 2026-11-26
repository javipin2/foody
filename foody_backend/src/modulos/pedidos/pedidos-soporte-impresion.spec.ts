import { DatabaseService } from '../../core/database/database.service';
import { ImpresionService } from '../../core/impresion/impresion.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { PedidosSoporteService } from './pedidos-soporte.service';

describe('PedidosSoporteService kitchen side effects', () => {
  it('still attempts to queue a ticket if resolving kitchens fails', async () => {
    const database = {
      consultar: jest.fn().mockRejectedValue(new Error('database timeout')),
    } as unknown as DatabaseService;
    const realtime = {
      cocinaActualizada: jest.fn(),
    } as unknown as RealtimeBroadcastService;
    const impresion = {
      encolarPorPedido: jest.fn().mockResolvedValue(undefined),
    } as unknown as ImpresionService;
    const service = new PedidosSoporteService(
      database,
      realtime,
      {} as NotificacionesService,
      impresion,
    );
    const logger = jest.spyOn(service['logger'], 'error').mockImplementation();

    await expect(
      service.notificarCocinasPorPedido('pedido-1', 'sucursal-1'),
    ).resolves.toBeUndefined();

    expect(realtime.cocinaActualizada).not.toHaveBeenCalled();
    expect(impresion.encolarPorPedido).toHaveBeenCalledWith(
      'pedido-1',
      'sucursal-1',
    );
    expect(logger).toHaveBeenCalledWith(
      expect.stringContaining('database timeout'),
    );
  });

  it('handles realtime publish rejection without skipping ticket queueing', async () => {
    const database = {
      consultar: jest.fn().mockResolvedValue([{ cocina_id: 'cocina-1' }]),
    } as unknown as DatabaseService;
    const realtime = {
      cocinaActualizada: jest
        .fn()
        .mockRejectedValue(new Error('realtime unavailable')),
    } as unknown as RealtimeBroadcastService;
    const impresion = {
      encolarPorPedido: jest.fn().mockResolvedValue(undefined),
    } as unknown as ImpresionService;
    const service = new PedidosSoporteService(
      database,
      realtime,
      {} as NotificacionesService,
      impresion,
    );
    const logger = jest.spyOn(service['logger'], 'warn').mockImplementation();

    await service.notificarCocinasPorPedido('pedido-1', 'sucursal-1');
    await Promise.resolve();

    expect(realtime.cocinaActualizada).toHaveBeenCalledWith('cocina-1', {
      pedido_id: 'pedido-1',
      sucursal_id: 'sucursal-1',
    });
    expect(impresion.encolarPorPedido).toHaveBeenCalledWith(
      'pedido-1',
      'sucursal-1',
    );
    expect(logger).toHaveBeenCalledWith(
      expect.stringContaining('realtime unavailable'),
    );
  });
});
