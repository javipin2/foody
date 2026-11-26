import { randomUUID } from 'crypto';
import {
  api,
  assertApiViva,
  login,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E permisos de liquidación de domiciliarios de planta', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    cajero = await login('cajero.test@foody.demo');
  });

  it('permite consultar resumen al cajero, pero exige también gestión de domiciliarios para liquidar', async () => {
    const lectura = await api()
      .get(`/api/v1/domiciliarios-planta/liquidacion/${SID}`)
      .set(cajero.auth);
    expect(lectura.status).toBe(200);

    // ID aleatorio sin registro: un usuario autorizado no produciría una liquidación.
    const escritura = await api()
      .post(
        `/api/v1/domiciliarios-planta/liquidar/${randomUUID()}?sucursal_id=${SID}`,
      )
      .set(cajero.auth)
      .send({});
    expect(escritura.status).toBe(403);
    expect(escritura.body.mensaje).toMatch(/permiso/i);
  });

  it('deja pasar a Admin el guard conjunto y termina sin movimiento al no existir el domiciliario', async () => {
    const escritura = await api()
      .post(
        `/api/v1/domiciliarios-planta/liquidar/${randomUUID()}?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({});
    expect(escritura.status).toBe(400);
    expect(escritura.body.mensaje).toMatch(/no tiene domicilios por liquidar/i);
  });
});
