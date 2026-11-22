import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CocinasService } from './cocinas.service';
import { ActualizarCocinaDto, CrearCocinaDto } from './dto/cocina.dto';
export declare class CocinasController {
    private readonly cocinas;
    private readonly sucursalScope;
    constructor(cocinas: CocinasService, sucursalScope: SucursalScopeService);
    listar(usuario: JwtPayload, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crear(usuario: JwtPayload, dto: CrearCocinaDto): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, dto: ActualizarCocinaDto, usuario: JwtPayload): Promise<{
        id: string;
    }>;
    eliminar(id: string, usuario: JwtPayload): Promise<{
        id: string;
        activa: boolean;
    }>;
}
