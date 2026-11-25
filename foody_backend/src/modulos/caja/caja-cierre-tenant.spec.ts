import { ForbiddenException } from '@nestjs/common';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CajaService } from './caja.service';

describe('CajaService cerrar — aislamiento por sucursal', () => {
  it('rechaza la caja de otra sucursal antes de expirar QR o escribir movimientos', async () => {
    const cajaAjena = {
      id: 'caja-tenant-b',
      sucursal_id: 'sucursal-tenant-b',
      estado: 'abierta',
      monto_inicial: '50000',
    };
    const query = jest.fn().mockResolvedValue({ rows: [cajaAjena] });
    const client = { query };
    const database = {
      consultarUno: jest.fn().mockResolvedValue(undefined),
      enTransaccion: jest.fn((callback: (tx: typeof client) => unknown) =>
        callback(client),
      ),
    };
    const pedidosEstado = {
      expirarQrPendientesAlCierreEnTransaccion: jest.fn(),
    };
    const auditoria = { registrarEnTransaccion: jest.fn() };
    const alertas = { registrarEnTransaccion: jest.fn() };
    const realtime = { cajaMovimiento: jest.fn() };
    const scope = new SucursalScopeService(database as never);
    const service = new CajaService(
      database as never,
      alertas as never,
      realtime as never,
      pedidosEstado as never,
      {} as never,
      auditoria as never,
      scope as never,
    );

    await expect(
      service.cerrar(
        { caja_id: cajaAjena.id, monto_final_contado: 0 },
        {
          sub: 'usuario-tenant-a',
          sucursal_id: 'sucursal-tenant-a',
          restaurante_id: 'restaurante-tenant-a',
        } as never,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(database.consultarUno).toHaveBeenCalledWith(
      expect.stringContaining('restaurante_id = $2 AND activa = true'),
      ['sucursal-tenant-b', 'restaurante-tenant-a'],
    );
    expect(query).toHaveBeenCalledTimes(1);
    expect(pedidosEstado.expirarQrPendientesAlCierreEnTransaccion).not.toHaveBeenCalled();
    expect(auditoria.registrarEnTransaccion).not.toHaveBeenCalled();
    expect(alertas.registrarEnTransaccion).not.toHaveBeenCalled();
    expect(realtime.cajaMovimiento).not.toHaveBeenCalled();
  });
});
