import { ConfigService } from '@nestjs/config';
import { User } from '@supabase/supabase-js';
export declare class SupabaseAuthService {
    private readonly client;
    constructor(config: ConfigService);
    estaConfigurado(): boolean;
    usuarioDesdeAccessToken(accessToken: string): Promise<User>;
}
