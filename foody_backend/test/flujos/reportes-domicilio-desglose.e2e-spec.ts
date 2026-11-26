import { api, assertApiViva, login, SID } from '../helpers/foody-e2e';

describe('E2E Reportes — desglose de domicilio', () => {
  it('mantiene valor total de pedidos y expone domicilio incluido por tipo y día', async () => {
    await assertApiViva();
    const admin = await login('admin@foody.demo');
    const hoy = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Bogota',
    }).format(new Date());
    const query = { sucursal_id: SID, desde: hoy, hasta: hoy };

    const financiero = await api()
      .get('/api/v1/reportes/financiero')
      .query(query)
      .set(admin.auth);
    expect(financiero.status).toBe(200);
    expect(financiero.body.datos.cuadre_caja.nota_universos).toContain(
      'incluye el cargo de domicilio',
    );
    for (const fila of financiero.body.datos.por_tipo) {
      expect(typeof fila.ventas).toBe('number');
      expect(typeof fila.costo_domicilio).toBe('number');
    }

    const pedidos = await api()
      .get('/api/v1/reportes/pedidos')
      .query(query)
      .set(admin.auth);
    expect(pedidos.status).toBe(200);
    for (const fila of pedidos.body.datos.por_dia) {
      expect(typeof fila.ventas).toBe('number');
      expect(typeof fila.costo_domicilio).toBe('number');
    }
  });
});
