import { createHash } from 'node:crypto';
import { DatabaseService } from '../../core/database/database.service';
import { SupabaseAuthService } from '../../core/auth/supabase-auth.service';
import { DispositivosService } from './dispositivos.service';

describe('DispositivosService capability de cliente', () => {
  const capability = 'a'.repeat(64);
  let database: jest.Mocked<
    Pick<DatabaseService, 'consultarUno' | 'consultar'>
  >;
  let supabaseAuth: { usuarioDesdeAccessToken: jest.Mock };
  let service: DispositivosService;

  beforeEach(() => {
    database = {
      consultarUno: jest.fn(),
      consultar: jest.fn(),
    };
    supabaseAuth = { usuarioDesdeAccessToken: jest.fn() };
    service = new DispositivosService(
      database as unknown as DatabaseService,
      supabaseAuth as unknown as SupabaseAuthService,
    );
  });

  it('persiste un hash, nunca el secreto original', async () => {
    database.consultarUno.mockResolvedValue({ device_id: 'device-1' });

    await expect(
      service.registrar({
        device_id: 'device-1',
        device_capability: capability,
        plataforma: 'web',
      }),
    ).resolves.toEqual({ device_id: 'device-1', registrado: true });

    const [sql, params] = database.consultarUno.mock.calls[0];
    expect(sql).toContain('capability_hash');
    expect(params).toContain(
      createHash('sha256').update(capability).digest('hex'),
    );
    expect(params).not.toContain(capability);
  });

  it('acepta solo la capability registrada y rechaza devices anonimizados', async () => {
    database.consultarUno.mockResolvedValue({
      capability_hash: createHash('sha256').update(capability).digest('hex'),
      anonimizado: false,
    });
    await expect(
      service.verificarCapability('device-1', capability),
    ).resolves.toBe(true);
    await expect(
      service.verificarCapability('device-1', 'b'.repeat(64)),
    ).resolves.toBe(false);

    database.consultarUno.mockResolvedValueOnce({
      capability_hash: createHash('sha256').update(capability).digest('hex'),
      anonimizado: true,
    });
    await expect(
      service.verificarCapability('device-1', capability),
    ).resolves.toBe(false);
  });

  it('no considera válido un identificador antiguo sin hash de capability', async () => {
    database.consultarUno.mockResolvedValue({
      capability_hash: null,
      anonimizado: false,
    });
    await expect(
      service.verificarCapability('device-legacy', capability),
    ).resolves.toBe(false);
  });

  it('no permite anonimizar por conocer el device_id', async () => {
    database.consultarUno.mockResolvedValue({
      fcm_token: 'fcm-secreto-del-dispositivo',
      auth_uid: null,
      anonimizado: false,
    });

    await expect(
      service.verificarPosesionParaAnonimizar('device-1', {}),
    ).resolves.toBe(false);
    await expect(
      service.verificarPosesionParaAnonimizar('device-1', {
        fcm_token: 'token-de-otro-device',
      }),
    ).resolves.toBe(false);
  });

  it('acepta solo el FCM guardado o la sesión del auth_uid vinculado', async () => {
    database.consultarUno.mockResolvedValue({
      fcm_token: 'fcm-secreto-del-dispositivo',
      auth_uid: 'usuario-vinculado',
      anonimizado: false,
    });
    await expect(
      service.verificarPosesionParaAnonimizar('device-1', {
        fcm_token: 'fcm-secreto-del-dispositivo',
      }),
    ).resolves.toBe(true);

    supabaseAuth.usuarioDesdeAccessToken = jest.fn().mockResolvedValue({
      id: 'usuario-vinculado',
    });
    await expect(
      service.verificarPosesionParaAnonimizar('device-1', {
        access_token: 'jwt-supabase-valido',
      }),
    ).resolves.toBe(true);
    expect(supabaseAuth.usuarioDesdeAccessToken).toHaveBeenCalledWith(
      'jwt-supabase-valido',
    );

    supabaseAuth.usuarioDesdeAccessToken = jest.fn().mockResolvedValue({
      id: 'otro-usuario',
    });
    await expect(
      service.verificarPosesionParaAnonimizar('device-1', {
        access_token: 'jwt-de-otro-usuario',
      }),
    ).resolves.toBe(false);
  });
});
