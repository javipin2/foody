import { SupabaseAuthService } from '../../core/auth/supabase-auth.service';
import { CancelarPedidoClienteDto } from './dto/cancelar-pedido-cliente.dto';
import { CalificarDomicilioClienteDto } from './dto/calificar-domicilio-cliente.dto';
import { LlamarMeseraClienteDto } from './dto/llamar-mesera-cliente.dto';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosService } from './pedidos.service';
import { DispositivosService } from '../dispositivos/dispositivos.service';
export declare class PedidosPublicController {
    private readonly pedidosService;
    private readonly supabaseAuth;
    private readonly dispositivos;
    constructor(pedidosService: PedidosService, supabaseAuth: SupabaseAuthService, dispositivos: DispositivosService);
    private verificarDevice;
    crear(dto: CrearPedidoDto, capability?: string): Promise<{
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
    estimar(dto: CrearPedidoDto, capability?: string): Promise<{
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
    listarMios(deviceId?: string, authorization?: string, capability?: string): Promise<import("pg").QueryResultRow[]>;
    cancelar(id: string, dto: CancelarPedidoClienteDto, capability?: string): Promise<{
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
    llamarMesera(id: string, dto: LlamarMeseraClienteDto, capability?: string): Promise<{
        pedido_id: string;
        mesa_id: string | null;
        mensaje: string;
    }>;
    calificar(id: string, dto: CalificarDomicilioClienteDto, capability?: string): Promise<{
        pedido_id: string;
        calificacion: number;
        mensaje: string;
    }>;
    estado(id: string, deviceId?: string, seguimientoToken?: string, capability?: string): Promise<{
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
        historial: {
            estado: string;
            fecha: Date;
        }[];
    }>;
}
