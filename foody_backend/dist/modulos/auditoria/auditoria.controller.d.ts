import { JwtPayload } from '../../core/auth/jwt-payload';
import { AuditoriaService } from './auditoria.service';
export declare class AuditoriaController {
    private readonly auditoria;
    constructor(auditoria: AuditoriaService);
    timeline(usuario: JwtPayload, desde: string, hasta: string, sucursalId?: string): Promise<{
        sucursal_id: string;
        desde: string;
        hasta: string;
        total_eventos: number;
        resumen: {
            auditoria: number;
            alertas: number;
            caja: number;
            pedidos: number;
        };
        eventos: {
            ocurrido_at: string;
        }[];
    }>;
}
