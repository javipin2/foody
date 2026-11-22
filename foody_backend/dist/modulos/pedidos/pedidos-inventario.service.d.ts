import { PoolClient } from 'pg';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CatalogoDisponibilidadService } from '../catalogo/catalogo-disponibilidad.service';
import { CosteoService } from '../costeo/costeo.service';
import { StockMovimientoService } from '../inventario/stock-movimiento.service';
export interface LineaStockExtra {
    tipo: 'bebida' | 'topping';
    id: string;
    cantidad: number;
}
export interface LineaStock {
    productoId: string;
    cantidad: number;
    precioVentaLinea: number;
    nombreProducto?: string;
    extras?: LineaStockExtra[];
}
export type CambioDisponibilidadProducto = {
    producto_id: string;
    disponible: boolean;
};
export type ResultadoDescontarStock = {
    costos: Map<string, number>;
    catalogo: CambioDisponibilidadProducto[];
};
export interface ContextoAlertaStock {
    origen: 'mesa' | 'domicilio' | 'para_llevar' | 'staff';
    clienteNombre?: string | null;
    mesaNombre?: string | null;
}
export declare class PedidosInventarioService {
    private readonly costeo;
    private readonly catalogoDisponibilidad;
    private readonly stockMovimiento;
    private readonly alertas?;
    constructor(costeo: CosteoService, catalogoDisponibilidad: CatalogoDisponibilidadService, stockMovimiento: StockMovimientoService, alertas?: AlertasRiesgoService | undefined);
    validarStockDisponible(client: PoolClient, sucursalId: string, lineas: LineaStock[], opciones?: {
        incluirEmpaques?: boolean;
        considerarReservaQrPendiente?: boolean;
        excluirPedidoIdReservaQr?: string;
    }, contextoAlerta?: ContextoAlertaStock): Promise<void>;
    private registrarAlertasIntentoPedido;
    private textoOrigenPedido;
    private explicarFaltaEnProducto;
    private nombreProducto;
    private fmtCantidad;
    private expandirLineaCompleta;
    detectarFaltasStock(client: PoolClient, sucursalId: string, lineas: LineaStock[], opciones?: {
        incluirEmpaques?: boolean;
        considerarReservaQrPendiente?: boolean;
        excluirPedidoIdReservaQr?: string;
    }): Promise<{
        ingrediente_id: string;
        nombre: string;
        necesita: number;
        disponible: number;
        unidad: string;
    }[]>;
    private ingredientesComprometidosQrPendiente;
    private lanzarStockInsuficiente;
    descontarStockPedido(client: PoolClient, sucursalId: string, pedidoId: string, lineas: LineaStock[], opciones?: {
        incluirEmpaques?: boolean;
    }): Promise<ResultadoDescontarStock>;
    restaurarStockPedido(client: PoolClient, sucursalId: string, pedidoId: string): Promise<CambioDisponibilidadProducto[]>;
    registrarMermaLineaProducto(client: PoolClient, sucursalId: string, pedidoId: string, productoId: string, cantidad: number, motivo: string): Promise<void>;
    pedidoRequiereMermaAlCancelar(client: PoolClient, pedidoId: string, estadoAnterior: string): Promise<boolean>;
    registrarMermaPedidoCompleto(client: PoolClient, sucursalId: string, pedidoId: string, motivo: string): Promise<void>;
    restaurarStockLineaProducto(client: PoolClient, sucursalId: string, pedidoId: string, productoId: string, cantidad: number, opciones?: {
        incluirEmpaques?: boolean;
    }): Promise<void>;
    lineasDesdePedido(client: PoolClient, pedidoId: string, sucursalId: string): Promise<LineaStock[]>;
    validarYDescontarStock(client: PoolClient, sucursalId: string, pedidoId: string, lineas: LineaStock[], opciones?: {
        incluirEmpaques?: boolean;
    }): Promise<ResultadoDescontarStock>;
    private alertarStockBajo;
    private cargarStockIngredientes;
    private costoCalculadoProducto;
}
