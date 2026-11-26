import { DatabaseService } from '../../core/database/database.service'
import { DomiciliariosService } from './domiciliarios.service'

describe('comisiones independientes estimadas', () => {
  it('conserva el histórico y excluye asignaciones canceladas de por pagar', async () => {
    const consultar = jest.fn().mockResolvedValue([])
    const database = { consultar } as unknown as DatabaseService
    const service = new DomiciliariosService(
      database,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    )

    await service.resumenComisionesIndependientes('sucursal-1')

    const sql = consultar.mock.calls[0][0] as string
    expect(sql).toContain('SUM(gd.ganancia_domiciliario), 0) AS ganancia_total')
    expect(sql).toContain(
      "AND ad.estado IS DISTINCT FROM 'cancelado'",
    )
    expect(sql).toContain('JOIN asignaciones_domicilio ad ON ad.id = gd.asignacion_id')
    expect(consultar.mock.calls[0][1]).toEqual(['sucursal-1'])
  })
})
