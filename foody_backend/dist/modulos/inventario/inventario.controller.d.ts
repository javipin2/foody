import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarIngredienteDto } from './dto/actualizar-ingrediente.dto';
import { ConfigurarRecetaProductoDto } from './dto/configurar-receta-producto.dto';
import { CrearIngredienteDto } from './dto/crear-ingrediente.dto';
import { CerrarConteoDto } from './dto/cerrar-conteo.dto';
import { RegistrarCompraDto } from './dto/registrar-compra.dto';
import { CrearTrasladoDto } from './dto/crear-traslado.dto';
import { InventarioService } from './inventario.service';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';
export declare class InventarioController {
    private readonly inventario;
    private readonly sucursalScope;
    constructor(inventario: InventarioService, sucursalScope: SucursalScopeService);
    traslados(usuario: JwtPayload, sucursalId?: string): Promise<import("pg").QueryResultRow[]>;
    crearTraslado(dto: CrearTrasladoDto, usuario: JwtPayload): Promise<{
        traslado_id: string;
        ingrediente_destino_id: string;
        estado: string;
    }>;
    recibirTraslado(id: string, usuario: JwtPayload): Promise<{
        traslado_id: string;
        estado: string;
    }>;
    cancelarTraslado(id: string, usuario: JwtPayload): Promise<{
        traslado_id: string;
        estado: string;
    }>;
    resumenHermanas(usuario: JwtPayload): Promise<{
        sucursal_propia: string | null;
        puede_ver_hermanas: boolean;
        sucursales: never[];
    } | {
        sucursal_propia: string;
        puede_ver_hermanas: boolean;
        sucursales: {
            sucursal_id: string;
            nombre: string;
            es_propia: boolean;
            solo_lectura: boolean;
            total_insumos: number;
            bajo_stock: number;
            agotados: number;
            alertas: {
                id: string;
                nombre: string;
                stock_actual: number;
                stock_minimo: number;
                unidad_base: string;
                bajo_minimo: boolean;
            }[];
        }[];
    }>;
    iniciarConteo(sucursalId: string, usuario: JwtPayload): Promise<{
        conteo_id: string;
        reutilizado: boolean;
    }>;
    cerrarConteo(conteoId: string, dto: CerrarConteoDto, usuario: JwtPayload): Promise<{
        conteo_id: string;
        items: number;
        ajustes: number;
    }>;
    movimientos(sucursalId: string, usuario: JwtPayload, page?: string, limit?: string): Promise<import("pg").QueryResultRow[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow>>;
    costos(sucursalId: string, usuario: JwtPayload): Promise<{
        tipo_entidad: string;
        costo_canal_llevar: number;
        precio_sugerido_llevar: number | null;
        margen_llevar_porcentaje: number | null;
    }[]>;
    recetaProducto(productoId: string, tipoEntidad: string | undefined, usuario: JwtPayload): Promise<{
        producto_id: string;
        tipo_entidad: "bebida" | "topping";
        receta_id: null;
        items: never[];
        margen_error: number;
        costo_calculado: string | null;
    } | {
        producto_id: string;
        tipo_entidad: "bebida" | "topping";
        receta_id: string;
        margen_error: number;
        costo_calculado: string | null;
        items: import("pg").QueryResultRow[];
    } | {
        producto_id: string;
        tipo_entidad: string;
        receta_id: null;
        items: never[];
        margen_error: number;
        costo_calculado: string | null;
        costo_domicilio: string | null;
    } | {
        producto_id: string;
        tipo_entidad: string;
        receta_id: string;
        margen_error: number;
        costo_calculado: string | null;
        costo_domicilio: string | null;
        items: import("pg").QueryResultRow[];
    }>;
    configurarReceta(dto: ConfigurarRecetaProductoDto, usuario: JwtPayload): Promise<{
        producto_id: string;
        tipo_entidad: string;
        receta_id: string;
        costo_calculado: number;
        items: number;
    }>;
    compras(dto: RegistrarCompraDto, usuario: JwtPayload): Promise<{
        compra_id: string;
        total_compra: number;
    }>;
    listar(sucursalId: string, usuario: JwtPayload, pag: PaginacionQueryDto): Promise<(import("pg").QueryResultRow & {
        costo_real: number;
        factor_correccion: number | null;
    })[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow & {
        costo_real: number;
        factor_correccion: number | null;
    }>>;
    crear(dto: CrearIngredienteDto, usuario: JwtPayload): Promise<Record<string, unknown> & {
        costo_real: number;
        factor_correccion: number | null;
    }>;
    actualizar(id: string, dto: ActualizarIngredienteDto, usuario: JwtPayload): Promise<any>;
}
