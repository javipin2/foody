import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { PedidosDescuentoService } from './pedidos-descuento.service';

function crearCaso(pedido: Record<string, unknown>) {
  const client = { query: jest.fn().mockResolvedValue({ rows: [] }) };
  const database = {
    enTransaccion: jest.fn((fn: (tx: typeof client) => unknown) => fn(client)),
  };
  const soporte = {
    consultarUnoCliente: jest.fn().mockResolvedValue(pedido),
    notificarPedidoRealtime: jest.fn(),
  };
  const facturacion = {
    calcularIvaParaPedidoEnTransaccion: jest.fn().mockResolvedValue({
      iva_porcentaje: 0,
      iva_valor: 0,
    }),
    sincronizarBorradorDesdePedidoEnTransaccion: jest.fn(),
  };
  const alertasRiesgo = { registrarEnTransaccion: jest.fn() };
  const auditoria = { registrarEnTransaccion: jest.fn() };
  const cajaMovimientos = {
    obtenerCajaAbiertaId: jest.fn().mockResolvedValue('caja-1'),
    insertar: jest.fn(),
  };
  const estadoCommand = {
    aplicarEstadoEnTransaccion: jest.fn().mockResolvedValue({
      aplicado: true,
      anterior: pedido.estado,
      nuevo: 'pagado',
      tipo: pedido.tipo,
    }),
  };
  const cuentaMesa = { liberarMesaSiSinPedidosActivos: jest.fn() };
  const service = new PedidosDescuentoService(
    database as never,
    facturacion as never,
    alertasRiesgo as never,
    soporte as never,
    auditoria as never,
    cajaMovimientos as never,
    estadoCommand as never,
    cuentaMesa as never,
  );
  return {
    service,
    estadoCommand,
    cajaMovimientos,
    cuentaMesa,
    soporte,
    pedido,
  };
}

const descuento: AplicarDescuentoDto = {
  monto: 10,
  motivo: 'Ajuste autorizado',
};
const contexto = { rol: 'admin', permisos: ['aplicar_descuento'] };

describe('PedidosDescuentoService', () => {
  it('cierra caja cuando el descuento cubre el saldo de un pedido listo de salón', async () => {
    const caso = crearCaso({
      id: 'pedido-1',
      estado: 'listo',
      tipo: 'mesa',
      mesa_id: 'mesa-1',
      subtotal: '100',
      costo_domicilio: '0',
      descuento: '0',
      total: '100',
      monto_pagado: '95',
      numero_pedido: 'M-1',
    });

    const result = await caso.service.aplicarDescuento(
      'pedido-1',
      'sucursal-1',
      'usuario-1',
      descuento,
      contexto,
    );

    expect(result).toMatchObject({ estado: 'pagado', total: 90 });
    expect(caso.estadoCommand.aplicarEstadoEnTransaccion).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({
        nuevoEstado: 'pagado',
        origen: 'cobro',
        estadoAnterior: 'listo',
        tipo: 'mesa',
      }),
    );
    expect(caso.cajaMovimientos.insertar).toHaveBeenCalledWith(
      expect.anything(),
      expect.objectContaining({ tipo: 'devolucion', monto: 5 }),
    );
    expect(caso.cuentaMesa.liberarMesaSiSinPedidosActivos).toHaveBeenCalledWith(
      expect.anything(),
      'mesa-1',
      'sucursal-1',
    );
    expect(caso.soporte.notificarPedidoRealtime).toHaveBeenCalledWith(
      'sucursal-1',
      'pedido-1',
      'pagado',
      undefined,
      { mesaId: 'mesa-1' },
    );
  });

  it('no cierra antes de tiempo un pedido que sigue en cocina', async () => {
    const caso = crearCaso({
      id: 'pedido-1',
      estado: 'en_cocina',
      tipo: 'mesa',
      subtotal: '100',
      costo_domicilio: '0',
      descuento: '0',
      total: '100',
      monto_pagado: '95',
      numero_pedido: 'M-1',
    });

    const result = await caso.service.aplicarDescuento(
      'pedido-1',
      'sucursal-1',
      'usuario-1',
      descuento,
      contexto,
    );

    expect(result.estado).toBe('en_cocina');
    expect(
      caso.estadoCommand.aplicarEstadoEnTransaccion,
    ).not.toHaveBeenCalled();
  });

  it('mantiene el pedido domiciliario listo para que despacho lo asigne', async () => {
    const caso = crearCaso({
      id: 'pedido-1',
      estado: 'listo',
      tipo: 'domicilio',
      subtotal: '100',
      costo_domicilio: '0',
      descuento: '0',
      total: '100',
      monto_pagado: '95',
      numero_pedido: 'D-1',
    });

    const result = await caso.service.aplicarDescuento(
      'pedido-1',
      'sucursal-1',
      'usuario-1',
      descuento,
      contexto,
    );

    expect(result.estado).toBe('listo');
    expect(
      caso.estadoCommand.aplicarEstadoEnTransaccion,
    ).not.toHaveBeenCalled();
  });
});
