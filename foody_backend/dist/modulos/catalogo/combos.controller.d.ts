import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CatalogoService } from './catalogo.service';
import { CrearComboDto } from './dto/crear-combo.dto';
export declare class CombosController {
    private readonly catalogo;
    private readonly sucursalScope;
    constructor(catalogo: CatalogoService, sucursalScope: SucursalScopeService);
    listar(sucursalId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearComboDto, usuario: JwtPayload): Promise<{
        id: string;
        nombre: string;
        precio_fijo: number;
    }>;
    disponibilidad(id: string, body: {
        disponible: boolean;
    }, usuario: JwtPayload): Promise<{
        id: string;
        disponible: boolean;
    }>;
}
