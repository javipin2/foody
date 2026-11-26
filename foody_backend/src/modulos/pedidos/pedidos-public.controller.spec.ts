import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { PedidosPublicController } from './pedidos-public.controller';

describe('PedidosPublicController capability invitado', () => {
  const capability = 'a'.repeat(64);
  let pedidos: {
    crear: jest.Mock;
    estimar: jest.Mock;
    listarPorDevice: jest.Mock;
    obtenerEstadoPublico: jest.Mock;
  };
  let dispositivos: {
    exigirCapability: jest.Mock;
    verificarCapability: jest.Mock;
  };
  let supabaseAuth: {
    estaConfigurado: jest.Mock;
    usuarioDesdeAccessToken: jest.Mock;
  };
  let controller: PedidosPublicController;

  beforeEach(() => {
    pedidos = {
      crear: jest.fn().mockResolvedValue({ id: 'pedido-1' }),
      estimar: jest.fn(),
      listarPorDevice: jest.fn().mockResolvedValue([]),
      obtenerEstadoPublico: jest
        .fn()
        .mockResolvedValue({ estado_actual: 'pendiente' }),
    };
    dispositivos = {
      exigirCapability: jest.fn().mockResolvedValue(undefined),
      verificarCapability: jest.fn().mockResolvedValue(false),
    };
    supabaseAuth = {
      estaConfigurado: jest.fn().mockReturnValue(false),
      usuarioDesdeAccessToken: jest.fn(),
    };
    controller = new PedidosPublicController(
      pedidos as never,
      supabaseAuth as never,
      dispositivos as never,
    );
  });

  it('bloquea la creación antes de ejecutar el flujo del pedido si no hay prueba', async () => {
    dispositivos.exigirCapability.mockRejectedValueOnce(
      new ForbiddenException('sin capability'),
    );

    await expect(
      controller.crear({ device_id: 'device-1' } as never),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(pedidos.crear).not.toHaveBeenCalled();
  });

  it('no permite que Checkout público declare pagos o propinas cobradas', async () => {
    dispositivos.exigirCapability.mockResolvedValueOnce(undefined);

    await expect(
      controller.crear({
        device_id: 'device-1',
        propina: 3000,
        pagos: [{ metodo_pago: 'efectivo', monto: 30000 }],
      } as never),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(pedidos.crear).not.toHaveBeenCalled();
  });

  it('permite consultar el estado con una capability válida', async () => {
    dispositivos.verificarCapability.mockResolvedValueOnce(true);

    await expect(
      controller.estado('pedido-1', 'device-1', undefined, capability),
    ).resolves.toEqual({ estado_actual: 'pendiente' });
    expect(pedidos.obtenerEstadoPublico).toHaveBeenCalledWith('pedido-1', {
      deviceId: 'device-1',
      seguimientoToken: undefined,
    });
  });

  it('mantiene el acceso de seguimiento por token individual sin device id', async () => {
    await controller.estado('pedido-1', undefined, 'token-del-pedido');
    expect(pedidos.obtenerEstadoPublico).toHaveBeenCalledWith('pedido-1', {
      deviceId: undefined,
      seguimientoToken: 'token-del-pedido',
    });
  });

  it('no deja que un token de otro device autorice una consulta', async () => {
    await expect(
      controller.estado('pedido-1', 'device-1', undefined, 'b'.repeat(64)),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(pedidos.obtenerEstadoPublico).not.toHaveBeenCalled();
  });

  it('incluye pedidos de dispositivos vinculados al usuario Supabase autenticado', async () => {
    const authUid = '6ad7f4f0-5c0b-44bb-a302-0de1c30eb927';
    supabaseAuth.estaConfigurado.mockReturnValue(true);
    supabaseAuth.usuarioDesdeAccessToken.mockResolvedValue({ id: authUid });

    await controller.listarMios(
      'device-actual',
      'Bearer access-token-valido',
      capability,
    );

    expect(dispositivos.exigirCapability).toHaveBeenCalledWith(
      'device-actual',
      capability,
    );
    expect(supabaseAuth.usuarioDesdeAccessToken).toHaveBeenCalledWith(
      'access-token-valido',
    );
    expect(pedidos.listarPorDevice).toHaveBeenCalledWith(
      'device-actual',
      authUid,
    );
  });

  it('mantiene historial limitado al dispositivo si el token Supabase no es válido', async () => {
    supabaseAuth.estaConfigurado.mockReturnValue(true);
    supabaseAuth.usuarioDesdeAccessToken.mockRejectedValue(
      new Error('token inválido'),
    );

    await controller.listarMios(
      'device-actual',
      'Bearer access-token-invalido',
      capability,
    );

    expect(pedidos.listarPorDevice).toHaveBeenCalledWith('device-actual', null);
  });
});
