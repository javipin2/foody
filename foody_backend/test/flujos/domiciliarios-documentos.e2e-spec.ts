import sharp from 'sharp';
import {
  api,
  assertApiViva,
  login,
  loginDomiciliarioIndependiente,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E documentos privados de domiciliario', () => {
  let independiente: TokenBundle;
  let administrador: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    independiente = await loginDomiciliarioIndependiente();
    administrador = await login('admin@foody.demo');
  });

  it('lista requisitos y resumen; rechaza MIME y tipo no permitidos sin subir archivos', async () => {
    const tipos = await api()
      .get('/api/v1/domiciliarios/documentos/tipos')
      .set(independiente.auth);
    expect(tipos.status).toBe(200);
    expect(tipos.body.datos.tipos).toEqual([
      'cedula_frente',
      'cedula_reverso',
      'foto_vehiculo',
    ]);

    const resumen = await api()
      .get('/api/v1/domiciliarios/documentos')
      .set(independiente.auth);
    expect(resumen.status).toBe(200);
    expect(resumen.body.datos).toMatchObject({
      documentos: [],
      faltantes: ['cedula_frente', 'cedula_reverso', 'foto_vehiculo'],
      completo: false,
      pendientes_revision: 0,
    });

    const texto = await api()
      .post('/api/v1/domiciliarios/documentos/cedula_frente')
      .set(independiente.auth)
      .attach('archivo', Buffer.from('no es imagen'), {
        filename: 'documento.pdf',
        contentType: 'application/pdf',
      });
    expect(texto.status).toBe(400);

    const png = await sharp({
      create: {
        width: 2,
        height: 2,
        channels: 3,
        background: '#ffffff',
      },
    })
      .png()
      .toBuffer();
    const tipoInvalido = await api()
      .post('/api/v1/domiciliarios/documentos/documento_desconocido')
      .set(independiente.auth)
      .attach('archivo', png, {
        filename: 'documento.png',
        contentType: 'image/png',
      });
    expect(tipoInvalido.status).toBe(400);
    expect(tipoInvalido.body.mensaje).toContain('Tipo de documento no válido');
  });

  it('deniega a personal administrativo el acceso a documentos de identidad courier', async () => {
    const tipos = await api()
      .get('/api/v1/domiciliarios/documentos/tipos')
      .set(administrador.auth);
    const resumen = await api()
      .get('/api/v1/domiciliarios/documentos')
      .set(administrador.auth);
    const carga = await api()
      .post('/api/v1/domiciliarios/documentos/cedula_frente')
      .set(administrador.auth);

    expect(tipos.status).toBe(403);
    expect(resumen.status).toBe(403);
    expect(carga.status).toBe(403);
  });
});
