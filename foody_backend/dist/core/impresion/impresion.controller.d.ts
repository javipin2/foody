import { JwtPayload } from '../auth/jwt-payload';
import { SucursalScopeService } from '../auth/sucursal-scope.service';
import { ImpresionService } from './impresion.service';
import { ReimprimirComandaDto } from './dto/reimprimir.dto';
export declare class ImpresionController {
    private readonly impresion;
    private readonly sucursalScope;
    constructor(impresion: ImpresionService, sucursalScope: SucursalScopeService);
    listarJobs(usuario: JwtPayload, sucursalId: string, limit?: string): Promise<import("pg").QueryResultRow[]>;
    reimprimir(usuario: JwtPayload, dto: ReimprimirComandaDto): Promise<{
        pedido_id: string;
        encolado: boolean;
    }>;
    procesarColaManual(): Promise<{
        procesado: boolean;
    }>;
}
