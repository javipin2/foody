import { DispositivosService } from './dispositivos.service';
import { AnonimizarDispositivoDto, RegistrarDispositivoDto, VincularAuthDispositivoDto } from './dto/dispositivos.dto';
export declare class DispositivosController {
    private readonly dispositivosService;
    constructor(dispositivosService: DispositivosService);
    registrar(body: RegistrarDispositivoDto): Promise<{
        device_id: string;
        registrado: boolean;
    }>;
    vincularAuth(body: VincularAuthDispositivoDto): Promise<{
        device_id: string;
        auth_uid: string;
        email: string | null;
        nombre: string | null;
        pedidos_vinculados: number;
    }>;
    anonimizar(deviceId: string, fcmTokenQuery?: string, body?: AnonimizarDispositivoDto, authorization?: string, fcmHeader?: string): Promise<{
        device_id: string;
        anonimizado: boolean;
        motivo: string;
    } | {
        device_id: string;
        anonimizado: boolean;
        motivo?: undefined;
    }>;
}
