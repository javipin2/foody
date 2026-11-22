import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CambiarEstadoPedidoDto } from './dto/cambiar-estado-pedido.dto';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { EliminarItemPedidoDto, RechazarPedidoMesaDto } from './dto/motivo-pedido.dto';
import { ActualizarItemPedidoDto } from './dto/actualizar-item-pedido.dto';
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { ActualizarComensalDto } from './dto/actualizar-comensal.dto';
import { AprobarPedidoMesaDto } from './dto/aprobar-pedido-mesa.dto';
import { ListarCerradosHoyQueryDto, ListarPedidosQueryDto } from './dto/listar-pedidos-query.dto';
import { PedidosService } from './pedidos.service';
export declare class PedidosController {
    private readonly pedidosService;
    private readonly sucursalScope;
    constructor(pedidosService: PedidosService, sucursalScope: SucursalScopeService);
    listar(usuario: JwtPayload, query: ListarPedidosQueryDto): Promise<(Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    })[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    }>>;
    listarCerradosHoy(usuario: JwtPayload, query: ListarCerradosHoyQueryDto): Promise<(Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    })[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    }>>;
    detalle(pedidoId: string, usuario: JwtPayload, sucursalId?: string): Promise<Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    }>;
    listarPorMesa(mesaId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        mesa_id: string;
        mesa_nombre: string;
        total_acumulado: number;
        cuenta: {
            modo: string;
            cantidad_tickets: number;
            mesa_grupo: {
                mesas: {
                    id: string;
                    nombre: string;
                    es_actual: boolean;
                }[];
            } | null;
        };
        pagos_abonos: {
            id: string;
            monto: number;
            propina: number;
            metodo_pago: string;
            created_at: Date;
            referencia: string | null;
            responsable_nombre: string | null;
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
            cliente_nombre: string | null;
            mesera_nombre: string | null;
            observaciones: string | null;
            items: any[];
        }[];
    }>;
    cobrarMesa(mesaId: string, usuario: JwtPayload, dto: CobrarMesaDto, sucursalId?: string): Promise<Record<string, unknown> | {
        mesa_id: string;
        mesa_nombre: string;
        total_cobrado: number;
        propina: number;
        pagos: import("./dto/cobrar-mesa.dto").PagoLineaDto[];
        saldo_restante: number;
        pedidos_cobrados: {
            id: string;
            numero_pedido: string;
        }[];
        parcial: boolean;
    }>;
    crearStaff(dto: CrearPedidoDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        costo_domicilio: number;
        total: number;
        estado: string;
        tiempo_estimado_minutos: number;
        factura_id: null;
        seguimiento_token: string;
        idempotente: boolean;
        descuento?: undefined;
        motivo_descuento?: undefined;
        promocion_id?: undefined;
        iva_porcentaje?: undefined;
        iva_valor?: undefined;
        lineas?: undefined;
        combos?: undefined;
        estimar?: undefined;
    } | {
        subtotal: number;
        costo_domicilio: number;
        descuento: number;
        motivo_descuento: string | null;
        promocion_id: string | null;
        total: number;
        iva_porcentaje: number;
        iva_valor: number;
        lineas: {
            producto_id: string;
            cantidad: number;
            precio_unitario: number;
            subtotal: number;
            nombre: string | null;
        }[];
        combos: {
            combo_id: string;
            nombre: string;
            cantidad: number;
            precio_unitario: number;
            subtotal: number;
        }[];
        estimar: true;
        pedido_id?: undefined;
        numero_pedido?: undefined;
        estado?: undefined;
        tiempo_estimado_minutos?: undefined;
        factura_id?: undefined;
        seguimiento_token?: undefined;
        idempotente?: undefined;
    } | {
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        costo_domicilio: number;
        total: number;
        estado: string;
        tiempo_estimado_minutos: number;
        factura_id: string | null;
        seguimiento_token: string;
        idempotente?: undefined;
        descuento?: undefined;
        motivo_descuento?: undefined;
        promocion_id?: undefined;
        iva_porcentaje?: undefined;
        iva_valor?: undefined;
        lineas?: undefined;
        combos?: undefined;
        estimar?: undefined;
    } | {
        pedido_id: string;
        numero_pedido: string;
        estado: string;
        total: number;
        seguimiento_token: string;
        idempotente: boolean;
    }>;
    agregarItems(pedidoId: string, dto: AgregarItemsPedidoDto, usuario: JwtPayload, sucursalId?: string): Promise<{
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
    actualizarItem(pedidoId: string, itemId: string, dto: ActualizarItemPedidoDto, usuario: JwtPayload, sucursalId?: string): Promise<{
        pedido_id: string;
        item_id: string;
        estado: string;
        numero_pedido: string;
        subtotal: number;
        total: number;
        cocina_id: string | null;
        mesa_id: string | null;
        reimprimir: boolean;
    }>;
    eliminarItem(pedidoId: string, itemId: string, usuario: JwtPayload, body: EliminarItemPedidoDto, sucursalId?: string): Promise<{
        pedido_id: string;
        item_id: string;
        estado: string;
        numero_pedido: string;
        subtotal: number;
        total: number;
        cocina_id: string | null;
        mesa_id: string | null;
    }>;
    cambiarEstado(pedidoId: string, usuario: JwtPayload, dto: CambiarEstadoPedidoDto, sucursalId?: string): Promise<{
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
        caja?: undefined;
    } | {
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
        caja: {
            devolucion_automatica: number;
            ventas_revertidas: number;
        };
    }>;
    aplicarDescuento(pedidoId: string, usuario: JwtPayload, dto: AplicarDescuentoDto, sucursalId?: string): Promise<{
        id: string;
        estado: string;
        descuento: number;
        porcentaje: number;
        total: number;
        iva_valor: number;
    }>;
    cobrarPedido(pedidoId: string, usuario: JwtPayload, dto: CobrarMesaDto, sucursalId?: string): Promise<Record<string, unknown> | {
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
    actualizarComensal(pedidoId: string, itemId: string, usuario: JwtPayload, dto: ActualizarComensalDto, sucursalId?: string): Promise<{
        item_id: string;
        comensal_etiqueta: string | null;
    }>;
    aprobar(pedidoId: string, usuario: JwtPayload, body: AprobarPedidoMesaDto, sucursalId?: string): Promise<{
        id: string;
        estado: string;
        mesera_id: string;
    }>;
    rechazar(pedidoId: string, usuario: JwtPayload, body: RechazarPedidoMesaDto, sucursalId?: string): Promise<{
        id: string;
        estado: string;
        caja: {
            devolucion_automatica: number;
            ventas_revertidas: number;
        };
    } | {
        id: string;
        estado: string;
        caja?: undefined;
    }>;
}
