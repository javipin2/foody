import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CatalogoService } from './catalogo.service';
import { ActualizarCategoriaDto } from './dto/actualizar-categoria.dto';
import { CrearCategoriaDto } from './dto/crear-categoria.dto';
export declare class CategoriasController {
    private readonly catalogo;
    private readonly sucursalScope;
    constructor(catalogo: CatalogoService, sucursalScope: SucursalScopeService);
    listar(sucursalId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearCategoriaDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, dto: ActualizarCategoriaDto, usuario: JwtPayload): Promise<{
        id: string;
    }>;
    eliminar(id: string, usuario: JwtPayload): Promise<{
        id: string;
        activa: boolean;
    }>;
    copiarDesde(destinoId: string, origenId: string, usuario: JwtPayload): Promise<{
        categorias: number;
        productos_nuevos: number;
        toppings: number;
        bebidas: number;
    }>;
}
