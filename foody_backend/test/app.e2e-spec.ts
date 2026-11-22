/**
 * Smoke: API viva (reemplaza stub Nest "Hello World").
 */
import { api, assertApiViva } from './helpers/foody-e2e';

describe('App salud (e2e)', () => {
  it('GET /api/v1/salud → exito', async () => {
    await assertApiViva();
    const r = await api().get('/api/v1/salud');
    expect(r.status).toBe(200);
    expect(r.body.exito).toBe(true);
    expect(r.body.datos?.base_datos).toBe(true);
  });
});
