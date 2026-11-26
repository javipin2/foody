import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { PedidosCajaAuditoriaService } from '../pedidos/pedidos-caja-auditoria.service';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { PedidosSoporteService } from '../pedidos/pedidos-soporte.service';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import { DispatchService } from './dispatch.service';
import { IniciarSesionDto, ResponderOfertaDto, UbicacionEntregaDto } from './dto/independiente.dto';
export declare class DomiciliariosIndependientesService {
    private readonly database;
    private readonly dispatch;
    private readonly alertasRiesgo;
    private readonly realtime;
    private readonly cajaAuditoria;
    private readonly pedidosEstadoCommand;
    private readonly pedidosSoporte;
    constructor(database: DatabaseService, dispatch: DispatchService, alertasRiesgo: AlertasRiesgoService, realtime: RealtimeBroadcastService, cajaAuditoria: PedidosCajaAuditoriaService, pedidosEstadoCommand: PedidosEstadoCommandService, pedidosSoporte: PedidosSoporteService);
    iniciarSesion(domiciliarioId: string, dto: IniciarSesionDto): Promise<{
        sesion_id: string | undefined;
        disponible: boolean;
    }>;
    actualizarUbicacion(domiciliarioId: string, dto: UbicacionEntregaDto): Promise<{
        ok: boolean;
        registrado: boolean;
    }>;
    cerrarSesion(domiciliarioId: string): Promise<{
        ok: boolean;
    }>;
    estadoSesion(domiciliarioId: string): Promise<{
        activa: boolean;
        disponible: boolean;
    }>;
    ofertasActivas(domiciliarioId: string): Promise<{
        comision_foody_pct: number;
        comision_foody: number;
        ganancia_estimada: number;
        valor_domicilio: number;
        oferta_id: string;
        pedido_id: string;
        radio_busqueda_km: string;
        intento_numero: number;
        expira_at: Date;
        numero_pedido: string;
        direccion_entrega: string | null;
        costo_domicilio: string;
        cliente_nombre: string | null;
        lat: string | null;
        lng: string | null;
        sucursal_nombre: string;
        sucursal_direccion: string | null;
        sucursal_lat: string | null;
        sucursal_lng: string | null;
        respuesta_id: string;
    }[]>;
    responderOferta(ofertaId: string, domiciliarioId: string, dto: ResponderOfertaDto): Promise<{
        oferta_id: string;
        respuesta: string;
        pedido_id?: undefined;
        asignacion_id?: undefined;
        estado?: undefined;
    } | {
        oferta_id: string;
        respuesta: string;
        pedido_id: string;
        asignacion_id: string;
        estado: string;
    }>;
    pedidosActivos(domiciliarioId: string): Promise<{
        saldo_pendiente: number;
        requiere_cobro: boolean;
        producto_total: number;
        producto_pendiente: number;
        domicilio_pendiente: number;
        id: string;
        numero_pedido: string;
        estado: string;
        cliente_nombre: string | null;
        cliente_telefono: string | null;
        direccion_entrega: string | null;
        subtotal: string;
        total: string;
        monto_pagado: string;
        metodo_pago: string | null;
        pagos_resumen: Array<{
            metodo_pago: string;
            monto: string | number;
        }>;
        costo_domicilio: string;
        lat: string | null;
        lng: string | null;
        estado_asignacion: string;
        asignado_at: string;
        sucursal_nombre: string;
        sucursal_direccion: string | null;
        sucursal_lat: string | null;
        sucursal_lng: string | null;
    }[]>;
    marcarEnCamino(pedidoId: string, domiciliarioId: string): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    confirmarEntrega(pedidoId: string, domiciliarioId: string, dto?: ConfirmarEntregaDto): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    ganancias(domiciliarioId: string, opts?: {
        desde?: string;
        hasta?: string;
    }): Promise<{
        items: {
            id: string;
            valor_domicilio: string;
            comision_foody: string;
            ganancia_domiciliario: string;
            pagado: boolean;
            created_at: Date;
            pedido_id: string | null;
            numero_pedido: string | null;
            entregas_periodo: string;
            total_ganancia_periodo: string;
            total_comision_periodo: string;
        }[];
        resumen: {
            entregas: number;
            total_ganancia: number;
            total_comision: number;
        };
    }>;
    private obtenerActivo;
    private obtenerSesionActiva;
    private consultarUnoCliente;
}
