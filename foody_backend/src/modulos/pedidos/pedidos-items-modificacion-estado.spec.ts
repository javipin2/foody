import { PoolClient } from 'pg';
import { ConflictException } from '@nestjs/common';
import { PedidosItemsService } from './pedidos-items.service';

describe('PedidosItemsService — edición que devuelve trabajo a Cocina', () => {
  it.each(['listo', 'pagando'])(
    'reabre el pedido desde %s al cambiar observaciones de preparación',
    async (estadoPedido) => {
      const client = {
        query: jest.fn(async (sql: string) => {
          if (sql.includes('SUM(t.costo_calculado)')) {
            return { rows: [{ s: '0' }] };
          }
          if (sql.includes('SELECT (')) {
            return { rows: [{ precio: '1000' }] };
          }
          if (sql.includes('AS subtotal')) {
            return { rows: [{ subtotal: '1000' }] };
          }
          return { rows: [] };
        }),
      };
      const pedido = {
        id: 'pedido-1',
        estado: estadoPedido,
        tipo: 'mesa',
        mesa_id: 'mesa-1',
        stock_descontado: false,
        total: '1000',
        monto_pagado: '0',
        costo_domicilio: '0',
        descuento: '0',
        numero_pedido: 'M-12',
        promocion_id: null,
      };
      const item = {
        id: 'item-1',
        producto_id: 'producto-1',
        cantidad: 1,
        precio_unitario: '1000',
        costo_unitario: '300',
        estado_cocina: 'listo',
        cocina_id: 'cocina-1',
        observaciones: 'Sin cebolla',
        nombre_producto: 'Arepa',
      };
      const soporte = {
        consultarUnoCliente: jest
          .fn()
          .mockResolvedValueOnce(pedido)
          .mockResolvedValueOnce(item)
          .mockResolvedValueOnce({ costo_calculado: '300' }),
        notificarPedidoRealtime: jest.fn(),
        notificarCocinasPorPedido: jest.fn(),
      };
      const estadoCommand = {
        aplicarEstadoEnTransaccion: jest.fn().mockResolvedValue({
          aplicado: true,
          anterior: estadoPedido,
          nuevo: 'en_cocina',
          tipo: 'mesa',
        }),
      };
      const baseDatos = {
        enTransaccion: jest.fn(async (operacion) =>
          operacion(client as unknown as PoolClient),
        ),
      };
      const facturacion = {
        calcularIvaParaPedidoEnTransaccion: jest
          .fn()
          .mockResolvedValue({ iva_porcentaje: 0, iva_valor: 0 }),
        sincronizarBorradorDesdePedidoEnTransaccion: jest.fn(),
      };
      const realtime = {
        cocinaActualizada: jest.fn(),
        mesasActualizadas: jest.fn(),
      };
      const auditoria = { registrarEnTransaccion: jest.fn() };
      const servicio = new PedidosItemsService(
        baseDatos as never,
        facturacion as never,
        realtime as never,
        {} as never,
        {} as never,
        soporte as never,
        {} as never,
        auditoria as never,
        estadoCommand as never,
      );

      const resultado = await servicio.actualizarItemPedido(
        'pedido-1',
        'item-1',
        'sucursal-1',
        'usuario-1',
        { observaciones: 'Sin tomate' },
      );

      expect(estadoCommand.aplicarEstadoEnTransaccion).toHaveBeenCalledWith(
        client,
        expect.objectContaining({
          pedidoId: 'pedido-1',
          nuevoEstado: 'en_cocina',
          origen: 'sistema',
          estadoAnterior: estadoPedido,
          motivo: 'Ítem modificado — vuelve a cocina',
        }),
      );
      expect(client.query).toHaveBeenCalledWith(
        expect.stringContaining('estado_cocina = $3'),
        [1, 'Sin tomate', 'pendiente', 'item-1'],
      );
      expect(resultado.estado).toBe('en_cocina');
      expect(soporte.notificarPedidoRealtime).toHaveBeenCalledWith(
        'sucursal-1',
        'pedido-1',
        'en_cocina',
        'M-12',
      );
      expect(soporte.notificarCocinasPorPedido).toHaveBeenCalledWith(
        'pedido-1',
        'sucursal-1',
      );
    },
  );
});

describe('validación de saldo al reducir un pedido', () => {
  const servicio = Object.create(
    PedidosItemsService.prototype,
  ) as PedidosItemsService;
  const validar = (
    servicio as unknown as {
      validarReduccionTotalConSaldo: (
        anterior: number,
        nuevo: number,
        pagado: number,
      ) => void;
    }
  ).validarReduccionTotalConSaldo.bind(servicio);

  it('bloquea una reducción por debajo de lo ya recibido', () => {
    try {
      validar(1000, 800, 900);
      fail('Se esperaba exigir devolución antes de reducir el total');
    } catch (error) {
      expect(error).toBeInstanceOf(ConflictException);
      expect((error as ConflictException).getResponse()).toMatchObject({
        error: 'PEDIDO_EDIT_REQUIERE_REEMBOLSO',
      });
    }
  });

  it('permite bajar el total si el saldo recibido no lo supera', () => {
    expect(() => validar(1000, 800, 700)).not.toThrow();
  });

  it('no bloquea una corrección que no reduce el total', () => {
    expect(() => validar(800, 800, 900)).not.toThrow();
  });
});
