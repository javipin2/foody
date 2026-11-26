/**
 * RBAC-CAJA-WRITE-01: requiere el fixture aislado `cajero.sololectura.test`
 * con override completo que contiene solo `ver_caja` en la base QA desechable.
 */
import {
  api,
  assertApiViva,
  login,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';
import { randomUUID } from 'crypto';

describe('E2E permisos de lectura/escritura de Caja', () => {
  let admin: TokenBundle;
  let cajeroSoloLectura: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    cajeroSoloLectura = await login('cajero.sololectura.test@foody.demo');
  });

  it('conserva lectura de Caja y niega mutaciones a override ver_caja', async () => {
    const lectura = await api()
      .get(`/api/v1/caja/activa/${SID}`)
      .set(cajeroSoloLectura.auth);
    expect(lectura.status).not.toBe(401);
    expect(lectura.status).not.toBe(403);

    const escritura = await api()
      .post('/api/v1/caja/gastos')
      .set(cajeroSoloLectura.auth)
      .send({});
    expect(escritura.status).toBe(403);
    expect(escritura.body.mensaje).toMatch(/permiso/i);
  });

  it('niega todas las mutaciones de Caja al perfil de solo lectura', async () => {
    const id = randomUUID();
    const mutaciones = [
      api().post('/api/v1/caja/abrir'),
      api().post('/api/v1/caja/cerrar'),
      api().post('/api/v1/caja/cuentas-por-cobrar'),
      api().patch(`/api/v1/caja/cuentas-por-cobrar/${id}/pagar`),
      api().post('/api/v1/caja/retiro-parcial'),
      api().post('/api/v1/caja/devolucion'),
      api().post('/api/v1/caja/gastos'),
    ];
    const respuestas = await Promise.all(
      mutaciones.map((peticion) =>
        peticion.set(cajeroSoloLectura.auth).send({}),
      ),
    );

    expect(respuestas.map((respuesta) => respuesta.status)).toEqual(
      Array(mutaciones.length).fill(403),
    );
    expect(
      respuestas.every((respuesta) => /permiso/i.test(respuesta.body.mensaje)),
    ).toBe(true);
  });

  it('el rol admin obtiene permiso de escritura con migración 094 aplicada', async () => {
    // Un body vacío falla en validación antes de entrar al servicio. Un 400
    // confirma que el guard permitió llegar al contrato DTO sin mutar Caja.
    const escritura = await api()
      .post('/api/v1/caja/gastos')
      .set(admin.auth)
      .send({});
    expect(escritura.status).toBe(400);
    expect(escritura.status).not.toBe(403);
  });
});
