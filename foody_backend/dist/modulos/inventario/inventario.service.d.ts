import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { CatalogoDisponibilidadService } from '../catalogo/catalogo-disponibilidad.service';
import { ActualizarIngredienteDto } from './dto/actualizar-ingrediente.dto';
import { ConfigurarRecetaProductoDto } from './dto/configurar-receta-producto.dto';
import { CrearIngredienteDto } from './dto/crear-ingrediente.dto';
import { CerrarConteoDto } from './dto/cerrar-conteo.dto';
import { RegistrarCompraDto } from './dto/registrar-compra.dto';
import { CrearTrasladoDto } from './dto/crear-traslado.dto';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';
import { StockMovimientoService } from './stock-movimiento.service';
export declare class InventarioService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly costeo;
    private readonly catalogoDisponibilidad;
    private readonly planFeatures;
    private readonly stockMovimiento;
    private readonly sucursalScope;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, costeo: CosteoService, catalogoDisponibilidad: CatalogoDisponibilidadService, planFeatures: PlanFeaturesService, stockMovimiento: StockMovimientoService, sucursalScope: SucursalScopeService);
    private assertPuedeTrasladosMultiSucursal;
    resumenInventarioHermanas(actor: JwtPayload): Promise<{
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
    listarIngredientes(sucursalId: string, query?: PaginacionQueryDto): Promise<(import("pg").QueryResultRow & {
        costo_real: number;
        factor_correccion: number | null;
    })[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow & {
        costo_real: number;
        factor_correccion: number | null;
    }>>;
    crearIngrediente(dto: CrearIngredienteDto, restauranteId?: string): Promise<Record<string, unknown> & {
        costo_real: number;
        factor_correccion: number | null;
    }>;
    actualizarIngrediente(id: string, sucursalId: string, usuarioId: string, dto: ActualizarIngredienteDto): Promise<any>;
    listarMovimientos(sucursalId: string, opciones?: {
        limite?: number;
        page?: number;
        paginar?: boolean;
    }): Promise<import("pg").QueryResultRow[]> | Promise<import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow>>;
    registrarCompra(dto: RegistrarCompraDto, usuarioId: string): Promise<{
        compra_id: string;
        total_compra: number;
    }>;
    recetaDeProducto(productoId: string, sucursalId: string, tipoEntidad?: 'producto' | 'bebida' | 'topping'): Promise<{
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
    private recetaDeExtra;
    configurarRecetaProducto(dto: ConfigurarRecetaProductoDto, sucursalId: string): Promise<{
        producto_id: string;
        tipo_entidad: string;
        receta_id: string;
        costo_calculado: number;
        items: number;
    }>;
    private configurarRecetaExtra;
    iniciarConteo(sucursalId: string, usuarioId: string): Promise<{
        conteo_id: string;
        reutilizado: boolean;
    }>;
    cerrarConteo(conteoId: string, sucursalId: string, usuarioId: string, dto: CerrarConteoDto): Promise<{
        conteo_id: string;
        items: number;
        ajustes: number;
    }>;
    private sincronizarCatalogoPorIngredientes;
    listarCostosProductos(sucursalId: string): Promise<{
        tipo_entidad: string;
        costo_canal_llevar: number;
        precio_sugerido_llevar: number | null;
        margen_llevar_porcentaje: number | null;
    }[]>;
    listarTraslados(restauranteId: string, sucursalId?: string): Promise<import("pg").QueryResultRow[]>;
    crearTraslado(actor: JwtPayload, dto: CrearTrasladoDto): Promise<{
        traslado_id: string;
        ingrediente_destino_id: string;
        estado: string;
    }>;
    recibirTraslado(trasladoId: string, restauranteId: string, sucursalDestinoId: string, usuarioId: string): Promise<{
        traslado_id: string;
        estado: string;
    }>;
    cancelarTraslado(trasladoId: string, actor: JwtPayload, sucursalOrigenId: string): Promise<{
        traslado_id: string;
        estado: string;
    }>;
    private exigirIngrediente;
    private exigirSubreceta;
    private obtenerIngrediente;
}
