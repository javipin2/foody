import { ImpresionService } from '../../core/impresion/impresion.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { SaludService } from './salud.service';
export declare class HealthController {
    private readonly saludService;
    private readonly realtimeService;
    private readonly impresion;
    constructor(saludService: SaludService, realtimeService: RealtimeBroadcastService, impresion: ImpresionService);
    verificarCompleto(): Promise<{
        estado: string;
        api: string;
        version: string;
        entorno: string;
        timestamp: string;
        base_datos: boolean;
        realtime: import("../../core/realtime/realtime-broadcast.service").SaludRealtime;
        impresion: {
            agente: {
                conectado: boolean;
                url: string;
                mensaje: string;
            };
            cola: {
                pendientes: number;
                error: number;
                enviados_24h: number;
            };
        };
        alertas: string[];
    }>;
    verificarRealtime(): Promise<import("../../core/realtime/realtime-broadcast.service").SaludRealtime>;
    verificarImpresion(): Promise<{
        cola: {
            pendientes: number;
            error: number;
            enviados_24h: number;
        };
        modo_sin_hardware: string;
        conectado: boolean;
        url: string;
        mensaje: string;
    }>;
}
