import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';
import { CatalogoService } from './catalogo.service';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ConfigurarItemsIncluidosDto } from './dto/configurar-items-incluidos.dto';
import { CambiarDisponibilidadDto, ConfigurarToppingsDto, VincularBebidaDto, VincularToppingDto } from './dto/extras-mutacion.dto';
export declare class ProductosController {
    private readonly catalogo;
    private readonly sucursalScope;
    constructor(catalogo: CatalogoService, sucursalScope: SucursalScopeService);
    listar(sucursalId: string, usuario: JwtPayload, pag: PaginacionQueryDto): Promise<import("pg").QueryResultRow[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow>>;
    crear(dto: CrearProductoDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    disponibilidad(id: string, body: CambiarDisponibilidadDto, usuario: JwtPayload): Promise<{
        id: string;
        disponible: boolean;
    }>;
    vincularTopping(productoId: string, body: VincularToppingDto, usuario: JwtPayload): Promise<{
        producto_id: string;
        topping_id: string;
    }>;
    listarToppings(productoId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    configurarToppings(productoId: string, body: ConfigurarToppingsDto, usuario: JwtPayload): Promise<{
        producto_id: string;
        topping_ids: string[];
    }>;
    vincularBebida(productoId: string, body: VincularBebidaDto, usuario: JwtPayload): Promise<{
        producto_id: string;
        bebida_id: string;
    }>;
    listarItemsIncluidos(id: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    configurarItemsIncluidos(id: string, dto: ConfigurarItemsIncluidosDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    actualizar(id: string, dto: ActualizarProductoDto, usuario: JwtPayload): Promise<{
        id: string;
    }>;
}
