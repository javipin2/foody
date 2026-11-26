import { AuditoriaController } from './auditoria.controller';
import { AuditoriaService } from './auditoria.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';

describe('AuditoriaController fecha predeterminada del timeline', () => {
  afterEach(() => jest.useRealTimers());

  it('usa el día de Bogotá cuando se omiten los límites', async () => {
    jest.useFakeTimers().setSystemTime(new Date('2026-03-01T02:30:00.000Z'));
    const timelineTurno = jest.fn().mockResolvedValue({});
    const controller = new AuditoriaController(
      { timelineTurno } as unknown as AuditoriaService,
      {
        resolverLecturaOperativa: jest.fn().mockResolvedValue('sucursal-1'),
      } as unknown as SucursalScopeService,
    );

    await controller.timeline({} as unknown as JwtPayload, {});

    expect(timelineTurno).toHaveBeenCalledWith({
      sucursal_id: 'sucursal-1',
      desde: '2026-02-28',
      hasta: '2026-02-28',
    });
  });

  it('conserva las fechas explícitas del consumidor', async () => {
    const timelineTurno = jest.fn().mockResolvedValue({});
    const controller = new AuditoriaController(
      { timelineTurno } as unknown as AuditoriaService,
      {
        resolverLecturaOperativa: jest.fn().mockResolvedValue('sucursal-1'),
      } as unknown as SucursalScopeService,
    );

    await controller.timeline({} as unknown as JwtPayload, {
      desde: '2026-11-01',
      hasta: '2026-11-30',
    });

    expect(timelineTurno).toHaveBeenCalledWith({
      sucursal_id: 'sucursal-1',
      desde: '2026-11-01',
      hasta: '2026-11-30',
    });
  });
});
