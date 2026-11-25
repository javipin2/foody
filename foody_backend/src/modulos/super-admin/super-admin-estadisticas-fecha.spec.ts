import { SuperAdminService } from './super-admin.service';

describe('SuperAdminService métricas del día', () => {
  it('usa el día calendario de Bogotá para pedidos e ingreso estimado de comisión', async () => {
    const consultarUno = jest.fn().mockResolvedValue({ total: '0' });
    const service = Object.create(SuperAdminService.prototype) as SuperAdminService;
    (service as any).database = { consultarUno };
    jest.spyOn(service, 'resumenGlobal').mockResolvedValue({} as any);
    jest.spyOn(service, 'metricasSelfService').mockResolvedValue({} as any);

    await service.estadisticas();

    expect(consultarUno).toHaveBeenCalledTimes(2);
    for (const [sql] of consultarUno.mock.calls) {
      expect(sql).toContain("AT TIME ZONE 'America/Bogota'");
      expect(sql).toContain('created_at >=');
      expect(sql).toContain('created_at <');
      expect(sql).not.toContain('CURRENT_DATE');
    }
  });
});
