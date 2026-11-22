import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CocinasService } from './cocinas.service';
import { ActualizarImpresoraDto, CrearImpresoraDto } from './dto/cocina.dto';
export declare class ImpresorasController {
    private readonly cocinas;
    private readonly sucursalScope;
    constructor(cocinas: CocinasService, sucursalScope: SucursalScopeService);
    listar(usuario: JwtPayload, sucursalId: string, cocinaId?: string): Promise<import("pg").QueryResultRow[]>;
    crear(usuario: JwtPayload, dto: CrearImpresoraDto): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, dto: ActualizarImpresoraDto, usuario: JwtPayload): Promise<{
        id: string;
    }>;
    eliminar(id: string, usuario: JwtPayload): Promise<{
        id: string;
        activa: boolean;
    }>;
}
