import { BadRequestException } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { DomiciliariosService } from './domiciliarios.service';
import { DispatchService } from './dispatch.service';

describe('asignación manual de domicilio', () => {
  it('bloquea la fila del domiciliario antes de comprobar ocupación', async () => {
    const queries: string[] = [];
    const query = jest.fn(async (sql: string) => {
      queries.push(sql);
      if (sql.includes('FROM domiciliarios_planta dp')) {
        return {
          rows: [
            {
              id: 'repartidor-1',
              sucursal_id: 'sucursal-1',
              usuario_id: 'usuario-repartidor-1',
            },
          ],
        };
      }
      return { rows: [] };
    });
    const database = {
      enTransaccion: (callback: (client: unknown) => Promise<unknown>) =>
        callback({ query }),
    };
    const dispatch = {
      validarPedidoParaDespacho: jest.fn().mockResolvedValue({
        valido: true,
        pedido: {
          id: 'pedido-1',
          tipo: 'domicilio',
          estado: 'listo',
          tiene_items: true,
          tiene_items_no_disponibles: false,
          tiene_items_cocina_pendientes: false,
        },
      }),
    };
    const servicio = new DomiciliariosService(
      database as unknown as DatabaseService,
      {} as never,
      {
        domiciliarioPlantaActualizado: jest.fn(),
        pedidoActualizado: jest.fn(),
      } as never,
      {} as never,
      { aplicarEstadoEnTransaccion: jest.fn() } as never,
      {} as never,
      dispatch as unknown as DispatchService,
    );

    await servicio.asignarPlanta(
      {
        pedido_id: 'pedido-1',
        sucursal_id: 'sucursal-1',
        domiciliario_planta_id: 'repartidor-1',
      },
      'usuario-admin',
    );

    const lockIndex = queries.findIndex(
      (sql) =>
        sql.includes('FROM domiciliarios_planta dp') &&
        sql.includes('FOR UPDATE'),
    );
    const ocupacionIndex = queries.findIndex((sql) =>
      sql.includes('FROM asignaciones_domicilio ad'),
    );
    expect(lockIndex).toBeGreaterThanOrEqual(0);
    expect(ocupacionIndex).toBeGreaterThan(lockIndex);
  });

  it('rechaza asignar planta mientras el pedido tenga una línea no disponible', async () => {
    const query = jest.fn();
    const dispatch = {
      validarPedidoParaDespacho: jest.fn().mockResolvedValue({
        valido: false,
        motivo: 'PEDIDO_ITEMS_NO_DISPONIBLES',
        mensaje: 'Ajusta las líneas antes de asignar.',
      }),
    };
    const database = {
      enTransaccion: (callback: (client: unknown) => Promise<unknown>) =>
        callback({ query }),
    };
    const servicio = new DomiciliariosService(
      database as unknown as DatabaseService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      dispatch as unknown as DispatchService,
    );

    await expect(
      servicio.asignarPlanta(
        {
          pedido_id: 'pedido-1',
          sucursal_id: 'sucursal-1',
          domiciliario_planta_id: 'repartidor-1',
        },
        'usuario-1',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(query).not.toHaveBeenCalled();
    expect(dispatch.validarPedidoParaDespacho).toHaveBeenCalledWith(
      'pedido-1',
      'sucursal-1',
      expect.anything(),
    );
  });
});

describe('aislamiento de asignaciones del domiciliario de planta', () => {
  function crearServicioSinAsignacionDelRepartidor() {
    const query = jest.fn().mockResolvedValue({ rows: [] });
    const database = {
      consultarUno: jest.fn().mockResolvedValue({
        id: 'repartidor-autenticado',
        sucursal_id: 'sucursal-1',
      }),
      enTransaccion: (callback: (client: unknown) => Promise<unknown>) =>
        callback({ query }),
    };
    const service = new DomiciliariosService(
      database as unknown as DatabaseService,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );
    return { service, database, query };
  }

  it('no permite iniciar un pedido asignado a otro repartidor', async () => {
    const { service, database, query } =
      crearServicioSinAsignacionDelRepartidor();

    await expect(
      service.marcarEnCamino('pedido-ajeno', 'usuario-1'),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(database.consultarUno).toHaveBeenCalledWith(
      expect.stringContaining('FROM domiciliarios_planta'),
      ['usuario-1'],
    );
    expect(query).toHaveBeenCalledTimes(1);
    expect(query.mock.calls[0][0]).toContain('AND domiciliario_planta_id = $2');
    expect(query.mock.calls[0][1]).toEqual([
      'pedido-ajeno',
      'repartidor-autenticado',
    ]);
  });

  it('no permite confirmar la entrega de un pedido asignado a otro repartidor', async () => {
    const { service, query } = crearServicioSinAsignacionDelRepartidor();

    await expect(
      service.confirmarEntrega('pedido-ajeno', 'usuario-1', {
        metodo_pago: 'efectivo',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(query).toHaveBeenCalledTimes(1);
    expect(query.mock.calls[0][0]).toContain('AND domiciliario_planta_id = $2');
    expect(query.mock.calls[0][0]).toContain("estado = 'en_camino'");
    expect(query.mock.calls[0][1]).toEqual([
      'pedido-ajeno',
      'repartidor-autenticado',
    ]);
  });
});
