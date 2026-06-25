import { DatabaseService } from '../../core/database/database.service';
export declare class DispositivosService {
    private readonly database;
    constructor(database: DatabaseService);
    registrar(datos: {
        device_id: string;
        fcm_token?: string;
        ciudad_id?: string;
        plataforma?: string;
    }): Promise<{
        device_id: string;
        registrado: boolean;
    }>;
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
