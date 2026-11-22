import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AuditoriaService } from './auditoria.service';
import { TimelineAuditoriaDto } from './dto/timeline-auditoria.dto';
export declare class AuditoriaController {
    private readonly auditoria;
    private readonly sucursalScope;
    constructor(auditoria: AuditoriaService, sucursalScope: SucursalScopeService);
    timeline(usuario: JwtPayload, query: TimelineAuditoriaDto): Promise<{
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
