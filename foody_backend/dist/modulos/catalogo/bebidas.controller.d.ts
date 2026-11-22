import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CatalogoService } from './catalogo.service';
import { CrearExtraDto } from './dto/crear-extra.dto';
import { ActualizarExtraDto } from './dto/extras-mutacion.dto';
export declare class BebidasController {
    private readonly catalogo;
    private readonly sucursalScope;
    constructor(catalogo: CatalogoService, sucursalScope: SucursalScopeService);
    listar(sucursalId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearExtraDto, usuario: JwtPayload): Promise<{
        id: string;
        nombre: string;
        precio: string;
        disponible: boolean;
    } | null>;
    actualizar(id: string, body: ActualizarExtraDto, usuario: JwtPayload): Promise<{
        nombre?: string;
        precio?: number;
        disponible?: boolean;
        id: string;
    }>;
}
