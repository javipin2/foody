import { ConfigService } from '@nestjs/config';
import { SupabaseAuthService } from './supabase-auth.service';

describe('SupabaseAuthService en QA aislada', () => {
  const originalQa = process.env.FOODY_QA_SIN_EFECTOS;

  afterEach(() => {
    if (originalQa === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
    else process.env.FOODY_QA_SIN_EFECTOS = originalQa;
  });

  it('no crea cliente externo aunque exista configuración Supabase', async () => {
    process.env.FOODY_QA_SIN_EFECTOS = '1';
    const config = {
      get: jest.fn(() => 'configured-test-value'),
    } as unknown as ConfigService;
    const auth = new SupabaseAuthService(config);

    expect(auth.estaConfigurado()).toBe(false);
    await expect(auth.usuarioDesdeAccessToken('google-token')).rejects.toThrow(
      'Inicio con Google no disponible',
    );
    expect(config.get).not.toHaveBeenCalled();
  });
});
