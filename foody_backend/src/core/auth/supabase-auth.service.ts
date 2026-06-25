import {
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient, User } from '@supabase/supabase-js';

@Injectable()
export class SupabaseAuthService {
  private readonly client: SupabaseClient | null;

  constructor(config: ConfigService) {
    const url = config.get<string>('SUPABASE_URL');
    const key = config.get<string>('SUPABASE_SERVICE_KEY');
    this.client = url && key ? createClient(url, key) : null;
  }

  estaConfigurado(): boolean {
    return this.client != null;
  }

  async usuarioDesdeAccessToken(accessToken: string): Promise<User> {
    if (!this.client) {
      throw new ServiceUnavailableException(
        'Inicio con Google no disponible (falta configuración Supabase)',
      );
    }
    const token = accessToken?.trim();
    if (!token) {
      throw new UnauthorizedException('Token de acceso inválido');
    }

    const { data, error } = await this.client.auth.getUser(token);
    if (error || !data.user) {
      throw new UnauthorizedException('Token de Google inválido o expirado');
    }
    if (!data.user.email) {
      throw new UnauthorizedException('La cuenta de Google no tiene correo asociado');
    }
    return data.user;
  }
}
