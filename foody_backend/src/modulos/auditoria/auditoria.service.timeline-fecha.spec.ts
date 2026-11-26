import { AuditoriaService } from './auditoria.service';
import { DatabaseService } from '../../core/database/database.service';

describe('AuditoriaService timeline rango America/Bogota', () => {
  it('usa límites locales inclusivos por fecha y conserva filtros indexables', async () => {
    const consultar = jest.fn().mockResolvedValue([]);
    const service = new AuditoriaService({
      consultar,
    } as unknown as DatabaseService);

    const result = await service.timelineTurno({
      sucursal_id: 'sucursal-1',
      desde: '2026-11-25',
      hasta: '2026-11-25',
    });

    expect(consultar).toHaveBeenCalledTimes(4);
    for (const [sql, params] of consultar.mock.calls) {
      expect(sql).toContain(
        "created_at >= ($2::date::timestamp AT TIME ZONE 'America/Bogota')",
      );
      expect(sql).toContain(
        "created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE 'America/Bogota')",
      );
      expect(sql).not.toContain('23:59:59');
      expect(params).toEqual(['sucursal-1', '2026-11-25', '2026-11-25']);
    }
    expect(result.total_eventos).toBe(0);
  });
});
