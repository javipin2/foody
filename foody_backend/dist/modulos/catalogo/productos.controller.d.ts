import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CatalogoService } from './catalogo.service';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ConfigurarItemsIncluidosDto } from './dto/configurar-items-incluidos.dto';
export declare class ProductosController {
    private readonly catalogo;
    private readonly sucursalScope;
    constructor(catalogo: CatalogoService, sucursalScope: SucursalScopeService);
    listar(sucursalId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearProductoDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    disponibilidad(id: string, body: {
        disponible: boolean;
    }, usuario: JwtPayload): Promise<{
        id: string;
        disponible: boolean;
    }>;
    vincularTopping(productoId: string, body: {
        topping_id: string;
    }, usuario: JwtPayload): Promise<{
        producto_id: string;
        topping_id: string;
    }>;
    vincularBebida(productoId: string, body: {
        bebida_id: string;
    }, usuario: JwtPayload): Promise<{
        producto_id: string;
        bebida_id: string;
    }>;
    listarItemsIncluidos(id: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    configurarItemsIncluidos(id: string, dto: ConfigurarItemsIncluidosDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    actualizar(id: string, dto: ActualizarProductoDto, usuario: JwtPayload): Promise<{
        id: string;
    }>;
}
