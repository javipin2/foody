import { DatabaseService } from '../../core/database/database.service';
import { CosteoService } from '../costeo/costeo.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { ActualizarCategoriaDto } from './dto/actualizar-categoria.dto';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearCategoriaDto } from './dto/crear-categoria.dto';
import { CrearComboDto } from './dto/crear-combo.dto';
import { CrearExtraDto } from './dto/crear-extra.dto';
import { CrearToppingDto } from './dto/crear-topping.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ConfigurarItemsIncluidosDto } from './dto/configurar-items-incluidos.dto';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';
export declare class CatalogoService {
    private readonly database;
    private readonly costeo;
    private readonly realtime;
    private readonly planFeatures;
    private readonly menuCache;
    constructor(database: DatabaseService, costeo: CosteoService, realtime: RealtimeBroadcastService, planFeatures: PlanFeaturesService, menuCache: MenuCacheService);
    private invalidarMenu;
    listarCategorias(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crearCategoria(dto: CrearCategoriaDto): Promise<import("pg").QueryResultRow | null>;
    actualizarCategoria(id: string, sucursalId: string, dto: ActualizarCategoriaDto): Promise<{
        id: string;
    }>;
    eliminarCategoria(id: string, sucursalId: string): Promise<{
        id: string;
        activa: boolean;
    }>;
    listarProductos(sucursalId: string, query?: PaginacionQueryDto): Promise<import("pg").QueryResultRow[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow>>;
    crearProducto(dto: CrearProductoDto, restauranteId?: string): Promise<import("pg").QueryResultRow | null>;
    actualizarProducto(id: string, sucursalId: string, dto: ActualizarProductoDto): Promise<{
        id: string;
    }>;
    cambiarDisponibilidad(id: string, sucursalId: string, disponible: boolean): Promise<{
        id: string;
        disponible: boolean;
    }>;
    listarToppings(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crearTopping(dto: CrearToppingDto): Promise<{
        producto_ids: string[];
        id: string;
        nombre: string;
        precio: string;
        disponible: boolean;
    }>;
    actualizarTopping(id: string, sucursalId: string, datos: {
        nombre?: string;
        precio?: number;
        disponible?: boolean;
    }): Promise<{
        nombre?: string;
        precio?: number;
        disponible?: boolean;
        id: string;
    }>;
    listarBebidas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crearBebida(dto: CrearExtraDto): Promise<{
        id: string;
        nombre: string;
        precio: string;
        disponible: boolean;
    } | null>;
    actualizarBebida(id: string, sucursalId: string, datos: {
        nombre?: string;
        precio?: number;
        disponible?: boolean;
    }): Promise<{
        nombre?: string;
        precio?: number;
        disponible?: boolean;
        id: string;
    }>;
    vincularToppingProducto(productoId: string, toppingId: string, sucursalId: string): Promise<{
        producto_id: string;
        topping_id: string;
    }>;
    listarToppingsProducto(productoId: string, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    configurarToppingsProducto(productoId: string, sucursalId: string, toppingIds: string[]): Promise<{
        producto_id: string;
        topping_ids: string[];
    }>;
    vincularBebidaProducto(productoId: string, bebidaId: string, sucursalId: string): Promise<{
        producto_id: string;
        bebida_id: string;
    }>;
    listarCombos(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crearCombo(dto: CrearComboDto): Promise<{
        id: string;
        nombre: string;
        precio_fijo: number;
    }>;
    cambiarDisponibilidadCombo(id: string, sucursalId: string, disponible: boolean): Promise<{
        id: string;
        disponible: boolean;
    }>;
    private validarComboItem;
    private exigirCombo;
    private exigirProductoEnClient;
    private exigirTopping;
    private exigirBebida;
    private exigirCategoria;
    listarItemsIncluidos(productoId: string, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    configurarItemsIncluidos(productoId: string, sucursalId: string, dto: ConfigurarItemsIncluidosDto): Promise<import("pg").QueryResultRow[]>;
    copiarMenuDesde(restauranteId: string, sucursalDestinoId: string, sucursalOrigenId: string, usuarioId: string): Promise<{
        categorias: number;
        productos_nuevos: number;
        toppings: number;
        bebidas: number;
    }>;
    private validarSinCicloIncluidos;
    private asegurarProductoEspejoBebida;
    private sincronizarProductoEspejoBebida;
    private asegurarCategoriaPorNombres;
    private exigirCategoriaActiva;
    private resolverCocinaActiva;
    private errorCocinaRequerida;
    private exigirProductoPlato;
    private exigirProducto;
}
