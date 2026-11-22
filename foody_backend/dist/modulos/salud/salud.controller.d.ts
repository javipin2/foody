import { SaludService } from './salud.service';
export declare class SaludController {
    private readonly saludService;
    constructor(saludService: SaludService);
    verificar(): Promise<{
        api: string;
        version: string;
        base_datos: boolean;
        entorno: string;
        timestamp: string;
    } | {
        modulos: {
            mesas: string[];
            menu_mesa_qr: string;
            cocinas: string[];
            impresoras: string[];
            kds: string[];
            zonas: string[];
            geografia: string[];
            pedidos_dinero: string[];
            super_admin: string[];
            sucursales_staff: string[];
        };
        api: string;
        version: string;
        base_datos: boolean;
        entorno: string;
        timestamp: string;
    }>;
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
}
