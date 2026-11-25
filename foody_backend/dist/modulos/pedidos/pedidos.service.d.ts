import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { ReemplazarItemPedidoDto } from './dto/reemplazar-item-pedido.dto';
import { ActualizarItemPedidoDto } from './dto/actualizar-item-pedido.dto';
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosCrearService } from './pedidos-crear.service';
import { PedidosDescuentoService } from './pedidos-descuento.service';
import { PedidosEstadoService } from './pedidos-estado.service';
import { PedidosItemsService } from './pedidos-items.service';
import { PedidosPagosService } from './pedidos-pagos.service';
import { ResultadoPaginado } from '../../compartido/dto/paginacion.dto';
import { OpcionesStaffPedido } from './pedidos-soporte.service';
export declare class PedidosService {
    private readonly database;
    private readonly sucursalScope;
    private readonly cuentaMesa;
    private readonly estado;
    private readonly crearPedido;
    private readonly items;
    private readonly descuento;
    private readonly pagos;
    constructor(database: DatabaseService, sucursalScope: SucursalScopeService, cuentaMesa: PedidosCuentaMesaService, estado: PedidosEstadoService, crearPedido: PedidosCrearService, items: PedidosItemsService, descuento: PedidosDescuentoService, pagos: PedidosPagosService);
    listarPorSucursal(sucursalId: string, opciones?: {
        soloActivos?: boolean;
        limite?: number;
        page?: number;
        paginar?: boolean;
        meseraId?: string;
        busqueda?: string;
    }): Promise<(Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    })[] | ResultadoPaginado<Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    }>>;
    listarCerradosHoy(sucursalId: string, opciones?: {
        limite?: number;
        page?: number;
        paginar?: boolean;
        meseraId?: string;
    }): Promise<(Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    })[] | ResultadoPaginado<Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    }>>;
    obtenerDetalleAdmin(pedidoId: string, sucursalId: string): Promise<Record<string, unknown> & {
        id: string;
        items_resumen: unknown[];
    }>;
    private adjuntarItemsResumen;
    listarActivosPorMesa(sucursalId: string, mesaId: string): Promise<{
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
            numero_pedido: string | null;
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
    cambiarEstado(pedidoId: string, sucursalId: string, usuarioId: string, nuevoEstado: string, motivo?: string, contexto?: {
        rol: string;
        permisos: string[];
    }): Promise<{
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
    cancelarPorCliente(pedidoId: string, deviceId: string, motivo: string): Promise<{
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
    llamarMesera(pedidoId: string, deviceId: string, mensaje?: string): Promise<{
        pedido_id: string;
        mesa_id: string | null;
        mensaje: string;
    }>;
    calificarDomicilio(pedidoId: string, deviceId: string, calificacion: number, comentario?: string): Promise<{
        pedido_id: string;
        calificacion: number;
        mensaje: string;
    }>;
    crear(dto: CrearPedidoDto, opciones?: OpcionesStaffPedido): Promise<{
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
    crearStaff(usuario: JwtPayload, dto: CrearPedidoDto): Promise<{
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
    estimar(dto: CrearPedidoDto): Promise<{
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
    agregarItems(pedidoId: string, sucursalId: string, dto: AgregarItemsPedidoDto, opciones?: OpcionesStaffPedido): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        delta_subtotal: number;
        total: number;
        estado: string;
        mesa_id: string | null;
        catalogo_cambios?: {
            producto_id: string;
            disponible: boolean;
        }[];
        idempotente?: boolean;
    }>;
    reemplazarItemPedido(pedidoId: string, itemId: string, sucursalId: string, usuarioId: string, dto: ReemplazarItemPedidoDto, opciones?: OpcionesStaffPedido): Promise<{
        pedido_id: string;
        numero_pedido: string;
        subtotal: number;
        delta_subtotal: number;
        total: number;
        estado: string;
        mesa_id: string | null;
        catalogo_cambios?: {
            producto_id: string;
            disponible: boolean;
        }[];
        idempotente?: boolean;
    }>;
    actualizarItemPedido(pedidoId: string, itemId: string, sucursalId: string, usuarioId: string, dto: ActualizarItemPedidoDto): Promise<{
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
    cobrarCuentaMesa(sucursalId: string, mesaId: string, usuarioId: string, dto?: CobrarMesaDto, rol?: string | null): Promise<Record<string, unknown> | {
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
    cobrarPedidoCaja(pedidoId: string, sucursalId: string, usuarioId: string, dto?: CobrarMesaDto, rol?: string | null): Promise<Record<string, unknown> | {
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
    listarPorDevice(deviceId: string, authUid?: string | null): Promise<import("pg").QueryResultRow[]>;
    obtenerEstadoPublico(pedidoId: string, opts?: {
        deviceId?: string;
        seguimientoToken?: string;
    }): Promise<{
        pedido_id: string;
        numero_pedido: string;
        estado_actual: string;
        seguimiento_token: string;
        tipo: string;
        mesa_id: string | null;
        mesa_nombre: string | null;
        total: number;
        lat: number | null;
        lng: number | null;
        repartidor_lat: number | null;
        repartidor_lng: number | null;
        direccion_entrega: string | null;
        tiempo_estimado_minutos: number | null;
        created_at: Date;
        items_no_disponibles: {
            nombre: string;
            cantidad: number;
        }[];
        historial: {
            estado: string;
            fecha: Date;
        }[];
    }>;
    aprobarMesa(pedidoId: string, sucursalId: string, usuarioId: string, opciones?: {
        meseraId?: string;
        rolLlamador?: string;
    }): Promise<{
        id: string;
        estado: string;
        mesera_id: string;
    }>;
    rechazarMesa(pedidoId: string, sucursalId: string, usuarioId: string, motivo: string): Promise<{
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
    aplicarDescuento(pedidoId: string, sucursalId: string, usuarioId: string, dto: AplicarDescuentoDto, contexto: {
        rol: string;
        permisos: string[];
    }): Promise<{
        id: string;
        estado: string;
        mesa_id: string | null;
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
