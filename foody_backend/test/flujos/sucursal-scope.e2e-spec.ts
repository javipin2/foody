/**
 * Lecturas operativas no deben filtrar información de una sucursal hermana.
 * Solo hace GETs; la fixture QA debe incluir la segunda sede de la migración 062.
 */
import { api, assertApiViva, login, TokenBundle } from '../helpers/foody-e2e';

describe('E2E aislamiento de sucursal operativa', () => {
  const SID_CENTRO = 'c0000000-0000-4000-8000-000000000001';
  const SID_NORTE = 'c0000000-0000-4000-8000-000000000002';
  let gerente: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    gerente = await login('gerente@foody.demo');
  });

  it('rechaza listar pedidos de una sucursal hermana', async () => {
    const propio = await api()
      .get(`/api/v1/pedidos?sucursal_id=${SID_CENTRO}`)
      .set(gerente.auth);
    expect(propio.status).toBe(200);

    const hermana = await api()
      .get(`/api/v1/pedidos?sucursal_id=${SID_NORTE}`)
      .set(gerente.auth);
    expect(hermana.status).toBe(403);
  });

  it('rechaza listar cocinas de una sucursal hermana', async () => {
    const hermana = await api()
      .get(`/api/v1/cocinas/${SID_NORTE}`)
      .set(gerente.auth);
    expect(hermana.status).toBe(403);
  });
});
