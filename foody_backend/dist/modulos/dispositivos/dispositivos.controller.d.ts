import { DispositivosService } from './dispositivos.service';
export declare class DispositivosController {
    private readonly dispositivosService;
    constructor(dispositivosService: DispositivosService);
    registrar(body: {
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
