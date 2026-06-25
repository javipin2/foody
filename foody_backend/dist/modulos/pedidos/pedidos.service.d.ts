import { DatabaseService } from '../../core/database/database.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosCrearService } from './pedidos-crear.service';
import { PedidosDescuentoService } from './pedidos-descuento.service';
import { PedidosEstadoService } from './pedidos-estado.service';
import { PedidosItemsService } from './pedidos-items.service';
import { PedidosPagosService } from './pedidos-pagos.service';
import { OpcionesStaffPedido } from './pedidos-soporte.service';
export declare class PedidosService {
    private readonly database;
    private readonly cuentaMesa;
    private readonly estado;
    private readonly crearPedido;
    private readonly items;
    private readonly descuento;
    private readonly pagos;
    constructor(database: DatabaseService, cuentaMesa: PedidosCuentaMesaService, estado: PedidosEstadoService, crearPedido: PedidosCrearService, items: PedidosItemsService, descuento: PedidosDescuentoService, pagos: PedidosPagosService);
    listarPorSucursal(sucursalId: string, opciones?: {
        soloActivos?: boolean;
        limite?: number;
    }): Promise<import("pg").QueryResultRow[]>;
    listarActivosPorMesa(sucursalId: string, mesaId: string): Promise<{
        mesa_id: string;
        mesa_nombre: string;
        total_acumulado: number;
        pagos_abonos: {
            id: string;
            monto: number;
            propina: number;
            metodo_pago: string;
            created_at: Date;
            referencia: string | null;
        }[];
        pedidos: {
            id: string;
            numero_pedido: string;
            tipo: string;
            estado: string;
            total: number;
            monto_pagado: number;
            saldo_pendiente: number;
            created_at: Date;
            items: any[];
        }[];
    }>;
    cambiarEstado(pedidoId: string, sucursalId: string, usuarioId: string, nuevoEstado: string, motivo?: string, contexto?: {
        rol: string;
        permisos: string[];
    }): Promise<{
        id: string;
        estado: string;
        mesa_id: string | null;
        estado_anterior?: undefined;
    } | {
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
    }>;
    crear(dto: CrearPedidoDto, opciones?: OpcionesStaffPedido): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        costo_domicilio: number;
        total: number;
        estado: string;
        tiempo_estimado_minutos: number;
        factura_id: string | null;
    } | {
        idempotente: boolean;
    }>;
    agregarItems(pedidoId: string, sucursalId: string, dto: AgregarItemsPedidoDto, opciones?: OpcionesStaffPedido): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        delta_subtotal: number;
        total: number;
        estado: string;
        mesa_id: string | null;
        catalogo_cambios: {
            producto_id: string;
            disponible: boolean;
        }[];
    }>;
    cobrarCuentaMesa(sucursalId: string, mesaId: string, usuarioId: string, dto?: CobrarMesaDto): Promise<{
        mesa_id: string;
        mesa_nombre: string;
        total_cobrado: number;
        propina: number;
        pagos: import("./dto/cobrar-mesa.dto").PagoLineaDto[];
        saldo_restante: number;
        pedidos_cobrados: {
            id: string;
            numero_pedido: string;
            total: number;
        }[];
        parcial: boolean;
    }>;
    cobrarPedidoCaja(pedidoId: string, sucursalId: string, usuarioId: string, dto?: CobrarMesaDto): Promise<{
        pedido_id: string;
        numero_pedido: string;
        total_cobrado: number;
        propina: number;
        pagos: import("./dto/cobrar-mesa.dto").PagoLineaDto[];
        saldo_restante: number;
        parcial: boolean;
        pagado: boolean;
        mesa_id: string | null;
    }>;
    actualizarComensalItem(pedidoId: string, itemId: string, sucursalId: string, comensalEtiqueta: string | null): Promise<{
        item_id: string;
        comensal_etiqueta: string | null;
    }>;
    listarPorDevice(deviceId: string): Promise<import("pg").QueryResultRow[]>;
    obtenerEstadoPublico(pedidoId: string): Promise<{
        pedido_id: string;
        numero_pedido: string;
        estado_actual: string;
        tipo: string;
        total: number;
        lat: number | null;
        lng: number | null;
        direccion_entrega: string | null;
        tiempo_estimado_minutos: number | null;
        historial: {
            estado: string;
            fecha: Date;
        }[];
    }>;
    aprobarMesa(pedidoId: string, sucursalId: string, usuarioId: string): Promise<{
        id: string;
        estado: string;
    }>;
    rechazarMesa(pedidoId: string, sucursalId: string, usuarioId: string, motivo: string): Promise<{
        id: string;
        estado: string;
    }>;
    aplicarDescuento(pedidoId: string, sucursalId: string, usuarioId: string, dto: AplicarDescuentoDto, contexto: {
        rol: string;
        permisos: string[];
    }): Promise<{
        id: string;
        estado: string;
        descuento: number;
        porcentaje: number;
        total: number;
        iva_valor: number;
    }>;
    eliminarItemPedido(pedidoId: string, itemId: string, sucursalId: string, usuarioId: string, motivo?: string): Promise<{
        pedido_id: string;
        item_id: string;
        estado: string;
        numero_pedido: string;
        subtotal: number;
        total: number;
        cocina_id: string | null;
        mesa_id: string | null;
    }>;
}
