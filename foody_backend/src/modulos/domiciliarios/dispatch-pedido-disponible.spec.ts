import { DatabaseService } from '../../core/database/database.service';
import { DispatchService } from './dispatch.service';

describe('guardas de despacho de domicilio', () => {
  const database = {
    consultarUno: jest.fn(),
  };
  const servicio = new DispatchService(
    database as unknown as DatabaseService,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
    {} as never,
  );

  beforeEach(() => jest.clearAllMocks());

  it('bloquea el dispatch automático con ítems no disponibles', async () => {
    database.consultarUno.mockResolvedValue({
      id: 'pedido-1',
      tipo: 'domicilio',
      estado: 'listo',
      direccion_entrega: 'Calle 10 # 5-20',
      tiene_items: true,
      tiene_items_no_disponibles: true,
      tiene_items_cocina_pendientes: false,
    });

    await expect(
      servicio.intentarDispatchAutomatico('pedido-1', 'sucursal-1'),
    ).resolves.toMatchObject({
      iniciado: false,
      motivo: 'PEDIDO_ITEMS_NO_DISPONIBLES',
      mensaje: expect.stringContaining('confirma el total'),
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(1);
  });

  it('no crea oferta manual cuando queda una línea no disponible', async () => {
    database.consultarUno.mockResolvedValue({
      id: 'pedido-1',
      tipo: 'domicilio',
      estado: 'listo',
      direccion_entrega: 'Calle 10 # 5-20',
      tiene_items: true,
      tiene_items_no_disponibles: true,
      tiene_items_cocina_pendientes: false,
    });

    await expect(
      servicio.iniciarBusquedaIndependientes('pedido-1', 'sucursal-1'),
    ).resolves.toMatchObject({
      iniciado: false,
      motivo: 'PEDIDO_ITEMS_NO_DISPONIBLES',
    });
    expect(database.consultarUno).toHaveBeenCalledTimes(1);
  });

  it('bloquea domicilios sin líneas para entregar', async () => {
    database.consultarUno.mockResolvedValue({
      id: 'pedido-1',
      tipo: 'domicilio',
      estado: 'listo',
      direccion_entrega: 'Calle 10 # 5-20',
      tiene_items: false,
      tiene_items_no_disponibles: false,
      tiene_items_cocina_pendientes: false,
    });

    await expect(
      servicio.intentarDispatchAutomatico('pedido-1', 'sucursal-1'),
    ).resolves.toMatchObject({
      iniciado: false,
      motivo: 'PEDIDO_SIN_ITEMS',
    });
  });

  it('bloquea el despacho de una dirección pendiente de confirmar', async () => {
    database.consultarUno.mockResolvedValue({
      id: 'pedido-1',
      tipo: 'domicilio',
      estado: 'listo',
      direccion_entrega: ' Por confirmar ',
      tiene_items: true,
      tiene_items_no_disponibles: false,
      tiene_items_cocina_pendientes: false,
    });

    await expect(
      servicio.intentarDispatchAutomatico('pedido-1', 'sucursal-1'),
    ).resolves.toMatchObject({
      iniciado: false,
      motivo: 'PEDIDO_DIRECCION_INCOMPLETA',
    });
  });

  it('vuelve a validar y bloquea dentro de la transacción con la fila bloqueada', async () => {
    const query = jest.fn().mockResolvedValue({
      rows: [
        {
          id: 'pedido-1',
          tipo: 'domicilio',
          estado: 'listo',
          direccion_entrega: 'Calle 10 # 5-20',
          tiene_items: true,
          tiene_items_no_disponibles: true,
          tiene_items_cocina_pendientes: false,
        },
      ],
    });
    const client = { query } as never;

    const result = await servicio.validarPedidoParaDespacho(
      'pedido-1',
      'sucursal-1',
      client,
    );

    expect(result).toMatchObject({
      valido: false,
      motivo: 'PEDIDO_ITEMS_NO_DISPONIBLES',
    });
    expect(query.mock.calls[0][0]).toContain('FOR UPDATE');
    expect(query.mock.calls[0][1]).toEqual(['pedido-1', 'sucursal-1']);
  });

  it('bloquea asignación mientras existan líneas pendientes o preparando', async () => {
    database.consultarUno.mockResolvedValue({
      id: 'pedido-1',
      tipo: 'domicilio',
      estado: 'listo',
      direccion_entrega: 'Calle 10 # 5-20',
      tiene_items: true,
      tiene_items_no_disponibles: false,
      tiene_items_cocina_pendientes: true,
    });

    await expect(
      servicio.intentarDispatchAutomatico('pedido-1', 'sucursal-1'),
    ).resolves.toMatchObject({
      iniciado: false,
      motivo: 'PEDIDO_COCINA_INCOMPLETA',
      mensaje: expect.stringContaining('pendientes de preparación'),
    });
    expect(database.consultarUno.mock.calls[0][0]).toContain(
      "NOT IN ('listo', 'no_disponible')",
    );
  });
});
