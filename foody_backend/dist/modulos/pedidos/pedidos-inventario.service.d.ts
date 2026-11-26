import { PoolClient } from 'pg';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CatalogoDisponibilidadService } from '../catalogo/catalogo-disponibilidad.service';
import { CosteoService } from '../costeo/costeo.service';
import { StockMovimientoService } from '../inventario/stock-movimiento.service';
export interface LineaStockExtra {
    tipo: 'bebida' | 'topping';
    id: string;
    cantidad: number;
    comboComponenteIndice?: number;
    comboComponenteId?: string;
}
export interface LineaStock {
    pedidoItemId?: string;
    productoId: string;
    cantidad: number;
    precioVentaLinea: number;
    nombreProducto?: string;
    extras?: LineaStockExtra[];
    comboComponenteIndice?: number;
    comboComponenteId?: string;
}
export type EventoStockCombo = 'consumo' | 'devolucion' | 'merma';
export interface ComponenteComboTarea {
    tipo_item: 'producto' | 'bebida' | 'topping';
    item_id: string;
    nombre: string;
    cantidad: number;
    costo_unitario: number;
    precio_unitario: number | null;
    cocina_id: string | null;
    producto_padre_id?: string | null;
    producto_padre_nombre_snapshot?: string | null;
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
    crearTareasCombo(client: PoolClient, sucursalId: string, pedidoId: string, pedidoItemId: string, componentes: ComponenteComboTarea[]): Promise<void>;
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
    private expandirLineaConComponentes;
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
    private registrarSnapshotStockItemNormal;
    ajustarStockItemNormalDesdeSnapshot(client: PoolClient, params: {
        sucursalId: string;
        pedidoId: string;
        pedidoItemId: string;
        unidades: number;
        evento: 'devolucion' | 'merma';
        motivo: string;
        usuarioId?: string;
        tipoComponente?: 'producto' | 'bebida' | 'topping';
        componenteId?: string;
    }): Promise<void>;
    private registrarSnapshotStockCombo;
    restaurarStockPedido(client: PoolClient, sucursalId: string, pedidoId: string): Promise<CambioDisponibilidadProducto[]>;
    ajustarStockComponenteCombo(client: PoolClient, params: {
        sucursalId: string;
        pedidoId: string;
        pedidoItemIdOriginal: string;
        decisionId: string | null;
        componenteIndice: number;
        componenteId: string;
        tipoItem: 'producto' | 'bebida' | 'topping';
        cantidad: number;
        evento: EventoStockCombo;
        motivo: string;
        usuarioId: string;
    }): Promise<void>;
    private insertarMovimientoLedgerCombo;
    private sincronizarDisponibilidadIngredientes;
    registrarMermaLineaProducto(client: PoolClient, sucursalId: string, pedidoId: string, productoId: string, cantidad: number, motivo: string, pedidoItemId?: string): Promise<void>;
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
