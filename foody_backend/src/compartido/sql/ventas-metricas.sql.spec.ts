import {
  SQL_FECHA_CAJA_COALESCED_P2_P3,
  SQL_FECHA_PEDIDOS_P2_P3,
  SQL_FECHA_PEDIDOS_P_P2_P3,
  sqlFechaRango,
} from './ventas-metricas.sql';

describe('rangos de fecha por día local', () => {
  it('convierte fechas de entrada a límites explícitos America/Bogota', () => {
    expect(sqlFechaRango('p.created_at', '$2', '$3')).toBe(
      "p.created_at >= ($2::date::timestamp AT TIME ZONE 'America/Bogota') AND p.created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE 'America/Bogota')",
    );
  });

  it('usa los mismos límites locales en consultas de pedidos', () => {
    expect(SQL_FECHA_PEDIDOS_P2_P3).toContain(
      "created_at >= ($2::date::timestamp AT TIME ZONE 'America/Bogota')",
    );
    expect(SQL_FECHA_PEDIDOS_P_P2_P3).toContain(
      "p.created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE 'America/Bogota')",
    );
  });

  it('usa límites locales para cobros ligados a pedido y movimientos huérfanos', () => {
    expect(SQL_FECHA_CAJA_COALESCED_P2_P3).toContain(
      "p.created_at >= ($2::date::timestamp AT TIME ZONE 'America/Bogota')",
    );
    expect(SQL_FECHA_CAJA_COALESCED_P2_P3).toContain(
      "m.created_at < (($3::date + interval '1 day')::timestamp AT TIME ZONE 'America/Bogota')",
    );
  });
});
