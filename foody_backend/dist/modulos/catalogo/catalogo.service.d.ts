import { DatabaseService } from '../../core/database/database.service';
import { CosteoService } from '../costeo/costeo.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { ActualizarCategoriaDto } from './dto/actualizar-categoria.dto';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearCategoriaDto } from './dto/crear-categoria.dto';
import { CrearComboDto } from './dto/crear-combo.dto';
import { CrearExtraDto } from './dto/crear-extra.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ConfigurarItemsIncluidosDto } from './dto/configurar-items-incluidos.dto';
export declare class CatalogoService {
    private readonly database;
    private readonly costeo;
    private readonly realtime;
    constructor(database: DatabaseService, costeo: CosteoService, realtime: RealtimeBroadcastService);
    listarCategorias(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crearCategoria(dto: CrearCategoriaDto): Promise<import("pg").QueryResultRow | null>;
    actualizarCategoria(id: string, sucursalId: string, dto: ActualizarCategoriaDto): Promise<{
        id: string;
    }>;
    eliminarCategoria(id: string, sucursalId: string): Promise<{
        id: string;
        activa: boolean;
    }>;
    listarProductos(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crearProducto(dto: CrearProductoDto): Promise<import("pg").QueryResultRow | null>;
    actualizarProducto(id: string, sucursalId: string, dto: ActualizarProductoDto): Promise<{
        id: string;
    }>;
    cambiarDisponibilidad(id: string, sucursalId: string, disponible: boolean): Promise<{
        id: string;
        disponible: boolean;
    }>;
    listarToppings(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crearTopping(dto: CrearExtraDto): Promise<import("pg").QueryResultRow | null>;
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
    crearBebida(dto: CrearExtraDto): Promise<import("pg").QueryResultRow | null>;
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
    private validarSinCicloIncluidos;
    private exigirProducto;
}
