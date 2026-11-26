/**
 * Lecturas operativas no deben filtrar información de una sucursal hermana.
 * La fixture QA debe incluir la segunda sede de la migración 062. Los POST/PATCH
 * de alcance usan UUID inexistentes y deben ser rechazados antes del servicio.
 */
import { api, assertApiViva, login, TokenBundle } from '../helpers/foody-e2e';
import { randomUUID } from 'crypto';

describe('E2E aislamiento de sucursal operativa', () => {
  const SID_CENTRO = 'c0000000-0000-4000-8000-000000000001';
  const SID_NORTE = 'c0000000-0000-4000-8000-000000000002';
  let gerente: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    gerente = await login('gerente@foody.demo');
  });

  it('permite listar pedidos propios y rechaza listar una sucursal hermana', async () => {
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

  it('limita caja, resumen y cuentas por cobrar a la sucursal del usuario', async () => {
    const rutas = [
      `/api/v1/caja/activa/${SID_CENTRO}`,
      `/api/v1/caja/cuentas-por-cobrar/${SID_CENTRO}`,
      `/api/v1/caja/cuentas-por-cobrar/${SID_CENTRO}/resumen`,
    ];
    const propios = await Promise.all(
      rutas.map((ruta) => api().get(ruta).set(gerente.auth)),
    );
    expect(propios.map((respuesta) => respuesta.status)).toEqual([
      200, 200, 200,
    ]);

    const rutasHermana = [
      `/api/v1/caja/activa/${SID_NORTE}`,
      `/api/v1/caja/cuentas-por-cobrar/${SID_NORTE}`,
      `/api/v1/caja/cuentas-por-cobrar/${SID_NORTE}/resumen`,
    ];
    const hermanas = await Promise.all(
      rutasHermana.map((ruta) => api().get(ruta).set(gerente.auth)),
    );
    expect(hermanas.map((respuesta) => respuesta.status)).toEqual([
      403, 403, 403,
    ]);
  });

  it('rechaza mutar pedidos de una sucursal hermana antes de buscar el pedido', async () => {
    const hermana = await api()
      .patch(`/api/v1/pedidos/${randomUUID()}/estado?sucursal_id=${SID_NORTE}`)
      .set(gerente.auth)
      .send({ estado: 'cancelado', motivo: 'QA scope de escritura' });

    expect(hermana.status).toBe(403);
  });
});
