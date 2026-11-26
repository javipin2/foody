import { BadRequestException, ConflictException } from '@nestjs/common';
import { PedidosComboDecisionesService } from './pedidos-combo-decisiones.service';

const decisionBase = () => ({
  decision_id: 'decision-1',
  pedido_id: 'pedido-1',
  pedido_item_id: 'item-1',
  tarea_id: 'task-1',
  sucursal_id: 'sucursal-1',
  estado_decision: 'pendiente_cliente',
  anterior: {
    tipo_item: 'producto',
    componente_id: 'producto-agotado',
    nombre: 'Plato anterior',
    cantidad: 2,
    precio_unitario: 10,
    costo_unitario: 5,
    cocina_id: 'cocina-1',
    producto_padre_id: null,
    producto_padre: null,
  },
  reemplazo: null,
  cotizacion_version: 0,
  total_propuesto: null,
  diferencia_propuesta: null,
  total_aceptado: null,
  total_base_cotizacion: null,
  respuesta_accion: null,
  componente_indice: 0,
  cantidad_combo: '1',
  stock_descontado: true,
  mesa_id: null,
  precio_linea: '30',
  costo_linea: '12',
  tipo_pedido: 'mesa',
  estado_pedido: 'en_cocina',
  numero_pedido: 'F-1',
  subtotal: '100',
  costo_domicilio: '0',
  descuento: '0',
  total: '100',
  monto_pagado: '50',
  promocion_id: null,
});

function crearServicio(fila = decisionBase()) {
  const query = jest.fn(async (sql: string) => {
    if (sql.includes('FOR UPDATE OF p, d')) {
      return {
        rows: [
          {
            ...fila,
            pedido_item_vigente_id:
              fila.estado_decision === 'aplicada' ? null : 'item-1',
            tarea_vigente_id:
              fila.estado_decision === 'aplicada' ? null : 'task-1',
          },
        ],
      };
    }
    if (sql.includes('SELECT to_jsonb(pi) AS linea')) {
      return {
        rows: [
          {
            linea: { precio_unitario: '30', cantidad: 1 },
            toppings: [],
            bebidas: [],
            combo: {},
            vinculos_pago: [],
            tareas: [],
          },
        ],
      };
    }
    if (sql.includes('SELECT componente_indice, componente_id')) {
      return {
        rows: [
          {
            componente_indice: 0,
            componente_id: 'producto-agotado',
            tipo_item: 'producto',
            cantidad: '2',
            estado: 'no_disponible',
            estado_antes_pausa: null,
          },
        ],
      };
    }
    if (sql.includes('SELECT COUNT(*)::text AS cantidad')) {
      return { rows: [{ cantidad: '1' }] };
    }
    if (sql.includes('FROM pedido_combo_selecciones')) {
      return {
        rows: [
          {
            precio_combo: '30',
            componentes_snapshot: [
              {
                tipo_item: 'producto',
                item_id: 'producto-agotado',
                nombre: 'Plato anterior',
                cantidad: 2,
                precio_unitario: 10,
                costo_unitario: 5,
                cocina_id: 'cocina-1',
              },
            ],
          },
        ],
      };
    }
    if (sql.includes('FROM productos') && sql.includes('WHERE id = $1')) {
      return {
        rows: [
          {
            id: 'producto-nuevo',
            nombre: 'Plato nuevo',
            precio: '14',
            costo_calculado: '6',
            cocina_id: 'cocina-2',
          },
        ],
      };
    }
    if (sql.includes('FROM estados_promociones')) return { rows: [] };
    return { rows: [] };
  });
  const database = {
    enTransaccion: jest.fn((fn) => fn({ query })),
  };
  const auditoria = { registrarEnTransaccion: jest.fn() };
  const realtime = { pedidoActualizado: jest.fn() };
  const inventario = { ajustarStockComponenteCombo: jest.fn() };
  const facturacion = {
    calcularIvaParaPedidoEnTransaccion: jest
      .fn()
      .mockResolvedValue({ iva_porcentaje: 0, iva_valor: 0 }),
    sincronizarBorradorDesdePedidoEnTransaccion: jest.fn(),
  };
  const caja = {
    obtenerCajaAbiertaId: jest.fn().mockResolvedValue(null),
    insertar: jest.fn(),
  };
  const estadoCommand = { aplicarEstadoEnTransaccion: jest.fn() };
  const cuentaMesa = { liberarMesaSiSinPedidosActivos: jest.fn() };
  const service = new PedidosComboDecisionesService(
    database as never,
    auditoria as never,
    realtime as never,
    inventario as never,
    facturacion as never,
    caja as never,
    estadoCommand as never,
    cuentaMesa as never,
  );
  return {
    service, query, database, auditoria, realtime, inventario,
    facturacion, caja, estadoCommand, cuentaMesa,
  };
}

describe('PedidosComboDecisionesService', () => {
  it('cotiza el diferencial con el precio vigente y guarda una versión explícita', async () => {
    const { service, query, auditoria } = crearServicio();

    const result = await service.cotizarReemplazo(
      'pedido-1',
      'decision-1',
      'sucursal-1',
      'producto-nuevo',
      'usuario-1',
    );

    expect(result).toMatchObject({
      diferencia_propuesta: 8,
      total_anterior: 100,
      total_propuesto: 108,
      cotizacion_version: 1,
      pago_adicional_estimado: 58,
      devolucion_estimada: 0,
      aplicado: false,
    });
    const update = query.mock.calls.find(([sql]) =>
      sql.includes('UPDATE pedido_combo_decisiones_cliente'),
    );
    expect(update?.[1]).toEqual(
      expect.arrayContaining([expect.any(String), 8, 108, 1, 'decision-1']),
    );
    expect(auditoria.registrarEnTransaccion).toHaveBeenCalledTimes(1);
  });

  it('no acepta la sustitución si no se registró una cotización', async () => {
    const { service } = crearServicio();

    await expect(
      service.responder('pedido-1', 'decision-1', 'sucursal-1', 'usuario-1', {
        accion: 'aceptar_sustitucion',
        cotizacion_version: 1,
        total_aceptado: 108,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rechaza aceptar un total que no coincide con el mostrado', async () => {
    const fila = decisionBase();
    fila.reemplazo = {
      ...fila.anterior,
      componente_id: 'producto-nuevo',
      nombre: 'Plato nuevo',
      precio_unitario: 14,
    };
    fila.cotizacion_version = 1;
    fila.total_propuesto = '108';
    fila.diferencia_propuesta = '8';
    fila.total_base_cotizacion = '100';
    const { service } = crearServicio(fila);

    await expect(
      service.responder('pedido-1', 'decision-1', 'sucursal-1', 'usuario-1', {
        accion: 'aceptar_sustitucion',
        cotizacion_version: 1,
        total_aceptado: 109,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('exige el motivo cuando el cliente rechaza el combo', async () => {
    const { service } = crearServicio();

    await expect(
      service.responder('pedido-1', 'decision-1', 'sucursal-1', 'usuario-1', {
        accion: 'cancelar_combo',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rechaza aceptar una cotización si el total base del pedido cambió', async () => {
    const fila = decisionBase();
    fila.reemplazo = {
      ...fila.anterior,
      componente_id: 'producto-nuevo',
      nombre: 'Plato nuevo',
      precio_unitario: 14,
    };
    fila.cotizacion_version = 1;
    fila.total_propuesto = '108';
    fila.total_base_cotizacion = '100';
    fila.total = '101';
    const { service } = crearServicio(fila);

    await expect(
      service.responder('pedido-1', 'decision-1', 'sucursal-1', 'usuario-1', {
        accion: 'aceptar_sustitucion',
        cotizacion_version: 1,
        total_aceptado: 108,
      }),
    ).rejects.toMatchObject({
      response: expect.objectContaining({
        error: 'COMBO_TOTAL_BASE_DESACTUALIZADO',
      }),
    });
  });

  it('aplica una sustitución aceptada, concilia stock y actualiza margen y total', async () => {
    const fila = decisionBase();
    fila.reemplazo = {
      ...fila.anterior,
      componente_id: 'producto-nuevo',
      nombre: 'Plato nuevo',
      precio_unitario: 14,
      costo_unitario: 6,
      cocina_id: 'cocina-2',
    };
    fila.cotizacion_version = 1;
    fila.total_propuesto = '108';
    fila.diferencia_propuesta = '8';
    fila.total_base_cotizacion = '100';
    const { service, query, inventario } = crearServicio(fila);

    const result = await service.responder(
      'pedido-1',
      'decision-1',
      'sucursal-1',
      'usuario-1',
      {
        accion: 'aceptar_sustitucion',
        cotizacion_version: 1,
        total_aceptado: 108,
      },
    );

    expect(result).toMatchObject({
      estado: 'aplicada',
      respuesta_accion: 'aceptar_sustitucion',
      total_aceptado: 108,
      aplicado: true,
    });
    expect(inventario.ajustarStockComponenteCombo).toHaveBeenCalledTimes(2);
    expect(inventario.ajustarStockComponenteCombo).toHaveBeenNthCalledWith(
      1,
      expect.anything(),
      expect.objectContaining({ evento: 'devolucion', cantidad: 2 }),
    );
    expect(inventario.ajustarStockComponenteCombo).toHaveBeenNthCalledWith(
      2,
      expect.anything(),
      expect.objectContaining({ evento: 'consumo', componenteId: 'producto-nuevo' }),
    );
    expect(
      query.mock.calls.some(
        ([sql, params]) =>
          sql.includes('UPDATE pedido_items') &&
          (params as unknown[])[0] === 38 &&
          (params as unknown[])[1] === 14,
      ),
    ).toBe(true);
    expect(
      query.mock.calls.some(
        ([sql, params]) =>
          sql.includes('UPDATE pedidos SET subtotal') &&
          (params as unknown[])[0] === 108 &&
          (params as unknown[])[3] === 108,
      ),
    ).toBe(true);
  });

  it('cancela solo el combo, compensa su stock y ajusta el total del pedido', async () => {
    const { service, query, auditoria, inventario, facturacion } = crearServicio();

    const result = await service.responder(
      'pedido-1',
      'decision-1',
      'sucursal-1',
      'usuario-1',
      { accion: 'cancelar_combo', motivo: 'El cliente no acepta reemplazo' },
    );

    expect(result).toMatchObject({ estado: 'aplicada', aplicado: true });
    const update = query.mock.calls.find(([sql]) =>
      sql.includes('respuesta_accion = $1'),
    );
    expect(update?.[1]).toContain('cancelar_combo');
    expect(inventario.ajustarStockComponenteCombo).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ evento: 'devolucion', componenteIndice: 0 }),
    );
    expect(
      query.mock.calls.some(([sql]) => sql.includes('UPDATE pedidos SET subtotal')),
    ).toBe(true);
    expect(facturacion.sincronizarBorradorDesdePedidoEnTransaccion)
      .toHaveBeenCalledTimes(1);
    expect(auditoria.registrarEnTransaccion).toHaveBeenCalledTimes(1);
  });

  it('devuelve el mismo resultado si se repite una decisión ya aplicada', async () => {
    const fila = decisionBase();
    fila.estado_decision = 'aplicada';
    fila.respuesta_accion = 'cancelar_combo';
    const { service, query, inventario } = crearServicio(fila);

    const result = await service.responder(
      'pedido-1',
      'decision-1',
      'sucursal-1',
      'usuario-1',
      { accion: 'cancelar_combo', motivo: 'reintento de respuesta' },
    );

    expect(result).toMatchObject({ estado: 'aplicada', idempotente: true });
    expect(inventario.ajustarStockComponenteCombo).not.toHaveBeenCalled();
    expect(query).toHaveBeenCalledTimes(1);
  });
});
