import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CambiarEstadoPedidoDto } from './dto/cambiar-estado-pedido.dto';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { ActualizarComensalDto } from './dto/actualizar-comensal.dto';
import { PedidosService } from './pedidos.service';
export declare class PedidosController {
    private readonly pedidosService;
    private readonly sucursalScope;
    constructor(pedidosService: PedidosService, sucursalScope: SucursalScopeService);
    listar(usuario: JwtPayload, sucursalId?: string, soloActivos?: string): Promise<import("pg").QueryResultRow[]>;
    listarPorMesa(mesaId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
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
    cobrarMesa(mesaId: string, usuario: JwtPayload, dto: CobrarMesaDto, sucursalId?: string): Promise<{
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
    crearStaff(dto: CrearPedidoDto, usuario: JwtPayload): Promise<{
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
    eliminarItem(pedidoId: string, itemId: string, usuario: JwtPayload, body: {
        motivo?: string;
    }, sucursalId?: string): Promise<{
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
        mesa_id: string | null;
        estado_anterior?: undefined;
    } | {
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
    }>;
    aplicarDescuento(pedidoId: string, usuario: JwtPayload, dto: AplicarDescuentoDto, sucursalId?: string): Promise<{
        id: string;
        estado: string;
        descuento: number;
        porcentaje: number;
        total: number;
        iva_valor: number;
    }>;
    cobrarPedido(pedidoId: string, usuario: JwtPayload, dto: CobrarMesaDto, sucursalId?: string): Promise<{
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
    aprobar(pedidoId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        id: string;
        estado: string;
    }>;
    rechazar(pedidoId: string, usuario: JwtPayload, body: {
        motivo: string;
    }, sucursalId?: string): Promise<{
        id: string;
        estado: string;
    }>;
}
