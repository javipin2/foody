import { DatabaseService } from '../../core/database/database.service';
import { SupabaseAuthService } from '../../core/auth/supabase-auth.service';
export declare class DispositivosService {
    private readonly database;
    private readonly supabaseAuth;
    constructor(database: DatabaseService, supabaseAuth: SupabaseAuthService);
    registrar(datos: {
        device_id: string;
        fcm_token?: string;
        ciudad_id?: string;
        plataforma?: string;
    }): Promise<{
        device_id: string;
        registrado: boolean;
    }>;
    vincularAuth(datos: {
        device_id: string;
        access_token: string;
    }): Promise<{
        device_id: string;
        auth_uid: string;
        email: string | null;
        nombre: string | null;
        pedidos_vinculados: number;
    }>;
    verificarPosesionParaAnonimizar(deviceId: string, prueba: {
        fcm_token?: string;
        access_token?: string;
    }): Promise<boolean>;
    anonimizar(deviceId: string): Promise<{
        device_id: string;
        anonimizado: boolean;
        motivo: string;
    } | {
        device_id: string;
        anonimizado: boolean;
        motivo?: undefined;
    }>;
}
