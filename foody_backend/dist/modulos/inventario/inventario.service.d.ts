import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { CatalogoDisponibilidadService } from '../catalogo/catalogo-disponibilidad.service';
import { ActualizarIngredienteDto } from './dto/actualizar-ingrediente.dto';
import { ConfigurarRecetaProductoDto } from './dto/configurar-receta-producto.dto';
import { CrearIngredienteDto } from './dto/crear-ingrediente.dto';
import { CerrarConteoDto } from './dto/cerrar-conteo.dto';
import { RegistrarCompraDto } from './dto/registrar-compra.dto';
import { CrearTrasladoDto } from './dto/crear-traslado.dto';
export declare class InventarioService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly costeo;
    private readonly catalogoDisponibilidad;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, costeo: CosteoService, catalogoDisponibilidad: CatalogoDisponibilidadService);
    resumenInventarioHermanas(restauranteId: string, sucursalPropiaId: string): Promise<{
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
    listarIngredientes(sucursalId: string): Promise<(import("pg").QueryResultRow & {
        costo_real: number;
        factor_correccion: number | null;
    })[]>;
    crearIngrediente(dto: CrearIngredienteDto): Promise<Record<string, unknown> & {
        costo_real: number;
        factor_correccion: number | null;
    }>;
    actualizarIngrediente(id: string, sucursalId: string, usuarioId: string, dto: ActualizarIngredienteDto): Promise<any>;
    listarMovimientos(sucursalId: string, limite?: number): Promise<import("pg").QueryResultRow[]>;
    registrarCompra(dto: RegistrarCompraDto, usuarioId: string): Promise<{
        compra_id: string;
        total_compra: number;
    }>;
    recetaDeProducto(productoId: string, sucursalId: string): Promise<{
        producto_id: string;
        receta_id: null;
        items: never[];
        margen_error: number;
        costo_calculado: string | null;
    } | {
        producto_id: string;
        receta_id: string;
        margen_error: number;
        costo_calculado: string | null;
        items: import("pg").QueryResultRow[];
    }>;
    configurarRecetaProducto(dto: ConfigurarRecetaProductoDto, sucursalId: string): Promise<{
        producto_id: string;
        receta_id: string;
        costo_calculado: number;
        items: number;
    }>;
    iniciarConteo(sucursalId: string, usuarioId: string): Promise<{
        conteo_id: string;
        reutilizado: boolean;
    }>;
    cerrarConteo(conteoId: string, sucursalId: string, usuarioId: string, dto: CerrarConteoDto): Promise<{
        conteo_id: string;
        items: number;
        ajustes: number;
    }>;
    listarCostosProductos(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    listarTraslados(restauranteId: string, sucursalId?: string): Promise<import("pg").QueryResultRow[]>;
    crearTraslado(restauranteId: string, usuarioId: string, dto: CrearTrasladoDto): Promise<{
        traslado_id: string;
        ingrediente_destino_id: string;
        estado: string;
    }>;
    recibirTraslado(trasladoId: string, restauranteId: string, sucursalDestinoId: string, usuarioId: string): Promise<{
        traslado_id: string;
        estado: string;
    }>;
    private exigirIngrediente;
    private exigirSubreceta;
    private obtenerIngrediente;
}
