import { DatabaseService } from '../../core/database/database.service'
import { DomiciliariosService } from './domiciliarios.service'
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service'

const pedidoParcial = {
  id: 'pedido-1',
  total: '110',
  costo_domicilio: '20',
  monto_pagado: '40',
  metodo_pago: 'transferencia',
  pagos_resumen: [
    { metodo_pago: 'transferencia', monto: '20' },
    { metodo_pago: 'efectivo', monto: '20' },
  ],
}

describe('saldo pendiente expuesto a las apps de domicilio', () => {
  it('historial de planta incluye el desglose real de pagos del pedido', async () => {
    const consultar = jest.fn().mockResolvedValue([pedidoParcial])
    const consultarUno = jest.fn().mockResolvedValue({ id: 'planta-1' })
    const database = { consultar, consultarUno } as unknown as DatabaseService
    const service = new DomiciliariosService(
      database,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    )

    const historial = await service.historialEntregas('usuario-1')

    expect(historial[0].pagos_resumen).toEqual(pedidoParcial.pagos_resumen)
    expect(consultar.mock.calls[0][0]).toContain(
      'pp.sucursal_id = p.sucursal_id',
    )
    expect(consultar.mock.calls[0][0]).toContain(
      'p.sucursal_id = ad.sucursal_id',
    )
  })

  it('planta recibe deuda real y reparto producto/domicilio', async () => {
    const consultar = jest.fn().mockResolvedValue([pedidoParcial])
    const consultarUno = jest.fn().mockResolvedValue({ id: 'planta-1' })
    const database = { consultar, consultarUno } as unknown as DatabaseService
    const service = new DomiciliariosService(
      database,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    )

    const pedidos = await service.pedidosAsignados('usuario-1')

    expect(pedidos[0]).toMatchObject({
      saldo_pendiente: 70,
      requiere_cobro: true,
      producto_total: 90,
      producto_pendiente: 50,
      domicilio_pendiente: 20,
    })
    expect(consultar.mock.calls[0][0]).toContain(
      'COALESCE(p.monto_pagado, 0) AS monto_pagado',
    )
    expect(pedidos[0].pagos_resumen).toEqual(pedidoParcial.pagos_resumen)
    expect(consultar.mock.calls[0][0]).toContain(
      'pp.sucursal_id = p.sucursal_id',
    )
  })

  it('independiente recibe el mismo cálculo para el mismo pedido', async () => {
    const consultar = jest.fn().mockResolvedValue([pedidoParcial])
    const database = { consultar } as unknown as DatabaseService
    const service = new DomiciliariosIndependientesService(
      database,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    )

    const pedidos = await service.pedidosActivos('independiente-1')

    expect(pedidos[0]).toMatchObject({
      saldo_pendiente: 70,
      requiere_cobro: true,
      producto_total: 90,
      producto_pendiente: 50,
      domicilio_pendiente: 20,
    })
    expect(consultar.mock.calls[0][0]).toContain(
      'COALESCE(p.monto_pagado, 0) AS monto_pagado',
    )
    expect(pedidos[0].pagos_resumen).toEqual(pedidoParcial.pagos_resumen)
    expect(consultar.mock.calls[0][0]).toContain(
      'pp.sucursal_id = p.sucursal_id',
    )
  })
})
