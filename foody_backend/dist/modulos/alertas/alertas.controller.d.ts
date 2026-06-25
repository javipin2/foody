import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AlertasRiesgoService } from './alertas-riesgo.service';
import { AlertasService } from './alertas.service';
export declare class AlertasController {
    private readonly alertasService;
    private readonly alertasRiesgo;
    private readonly sucursalScope;
    constructor(alertasService: AlertasService, alertasRiesgo: AlertasRiesgoService, sucursalScope: SucursalScopeService);
    evaluar(sucursalId: string, usuario: JwtPayload): Promise<{
        generadas: number;
    }>;
    listar(sucursalId: string, soloPendientes: string | undefined, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    revisar(alertaId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        id: string;
        revisada: boolean;
    }>;
}
