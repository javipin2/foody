import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { DispatchService } from './dispatch.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import { DomiciliariosService } from './domiciliarios.service';
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import { ConfigDomicilioCajaDto, ConfigFiadoDomiciliarioDto } from './dto/config-domicilio.dto';
import { IniciarSesionDto, ResponderOfertaDto, UbicacionEntregaDto } from './dto/independiente.dto';
export declare class DomiciliariosPlantaController {
    private readonly domiciliariosService;
    private readonly dispatchService;
    private readonly sucursalScope;
    constructor(domiciliariosService: DomiciliariosService, dispatchService: DispatchService, sucursalScope: SucursalScopeService);
    listarDisponibles(usuario: JwtPayload, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    resumenComisiones(usuario: JwtPayload, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    resumenLiquidacion(usuario: JwtPayload, sucursalId: string): Promise<{
        permite_fiado_domiciliario: boolean;
        domiciliarios: {
            domiciliario_planta_id: string;
            nombre: string;
            pedidos: number;
            total_pendiente: number;
        }[];
    }>;
    liquidar(domiciliarioPlantaId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        domiciliario_planta_id: string;
        liquidados: number;
        total: number;
    }>;
    configurarFiado(usuario: JwtPayload, sucursalId: string, body: ConfigFiadoDomiciliarioDto): Promise<{
        sucursal_id: string;
        permite_fiado_domiciliario: boolean;
    }>;
    resumenDomicilios(usuario: JwtPayload, sucursalId: string, desde?: string, hasta?: string): Promise<{
        domicilio_ingresa_a_caja: boolean;
        domiciliarios: {
            domiciliario_planta_id: string;
            nombre: string;
            pedidos_entregados: number;
            total_domicilios: number;
        }[];
    }>;
    configurarDomicilioCaja(usuario: JwtPayload, sucursalId: string, body: ConfigDomicilioCajaDto): Promise<{
        sucursal_id: string;
        domicilio_ingresa_a_caja: boolean;
    }>;
    asignar(dto: AsignarDomiciliarioDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    reasignar(dto: AsignarDomiciliarioDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
        reasignado: boolean;
    }>;
    dispatchIndependiente(pedidoId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        iniciado: boolean;
        motivo: string;
        mensaje: string;
    } | {
        iniciado: boolean;
        motivo: string;
        oferta_id: string;
        intento?: undefined;
        mensaje?: undefined;
        radio_km?: undefined;
        expira_en_seg?: undefined;
        domiciliarios_notificados?: undefined;
    } | {
        iniciado: boolean;
        motivo: string;
        intento: number;
        oferta_id?: undefined;
        mensaje?: undefined;
        radio_km?: undefined;
        expira_en_seg?: undefined;
        domiciliarios_notificados?: undefined;
    } | {
        iniciado: boolean;
        motivo: string;
        mensaje: string;
        intento: number;
        radio_km: number;
        expira_en_seg: number;
        oferta_id?: undefined;
        domiciliarios_notificados?: undefined;
    } | {
        iniciado: boolean;
        oferta_id: string;
        intento: number;
        radio_km: number;
        domiciliarios_notificados: number;
        expira_en_seg: number;
        motivo?: undefined;
        mensaje?: undefined;
    }>;
}
export declare class DomiciliarioPlantaController {
    private readonly domiciliariosService;
    constructor(domiciliariosService: DomiciliariosService);
    pedidosAsignados(usuario: JwtPayload): Promise<{
        saldo_pendiente: number;
        requiere_cobro: boolean;
        producto_total: number;
        producto_pendiente: number;
        domicilio_pendiente: number;
        id: string;
        numero_pedido: string;
        tipo: string;
        estado: string;
        cliente_nombre: string | null;
        cliente_telefono: string | null;
        direccion_entrega: string | null;
        lat: string | null;
        lng: string | null;
        subtotal: string;
        costo_domicilio: string;
        total: string;
        monto_pagado: string;
        metodo_pago: string | null;
        pagos_resumen: {
            metodo_pago: string;
            monto: string | number;
        }[];
        created_at: string;
        estado_asignacion: string;
        asignado_at: string;
        permite_fiado_domiciliario: boolean;
        domicilio_ingresa_a_caja: boolean;
    }[]>;
    enCamino(pedidoId: string, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    confirmarEntrega(pedidoId: string, dto: ConfirmarEntregaDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    ubicacion(dto: UbicacionEntregaDto, usuario: JwtPayload): Promise<{
        ok: boolean;
        registrado: boolean;
        pedido_id?: undefined;
    } | {
        ok: boolean;
        registrado: boolean;
        pedido_id: string;
    }>;
    historial(usuario: JwtPayload, desde?: string, hasta?: string): Promise<import("pg").QueryResultRow[]>;
    estadisticas(usuario: JwtPayload, desde?: string, hasta?: string): Promise<{
        entregas_hoy: number;
        entregas_semana: number;
        entregas_mes: number;
        entregas_rango: number;
        total_cobrado_rango: number;
        tiempo_promedio_min: number | null;
        saldo_por_liquidar: number;
    }>;
}
export declare class DomiciliariosIndependientesController {
    private readonly independientesService;
    constructor(independientesService: DomiciliariosIndependientesService);
    iniciarSesion(dto: IniciarSesionDto, usuario: JwtPayload): Promise<{
        sesion_id: string | undefined;
        disponible: boolean;
    }>;
    ubicacion(dto: UbicacionEntregaDto, usuario: JwtPayload): Promise<{
        ok: boolean;
        registrado: boolean;
    }>;
    cerrarSesion(usuario: JwtPayload): Promise<{
        ok: boolean;
    }>;
    estadoSesion(usuario: JwtPayload): Promise<{
        activa: boolean;
        disponible: boolean;
    }>;
    ofertasActivas(usuario: JwtPayload): Promise<{
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
    responderOferta(ofertaId: string, dto: ResponderOfertaDto, usuario: JwtPayload): Promise<{
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
    pedidosActivos(usuario: JwtPayload): Promise<{
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
        pagos_resumen: {
            metodo_pago: string;
            monto: string | number;
        }[];
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
    enCamino(pedidoId: string, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    confirmarEntrega(pedidoId: string, dto: ConfirmarEntregaDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    ganancias(usuario: JwtPayload, desde?: string, hasta?: string): Promise<{
        items: {
            id: string;
            valor_domicilio: string;
            comision_foody: string;
            ganancia_domiciliario: string;
            pagado: boolean;
            created_at: Date;
            pedido_id: string | null;
            numero_pedido: string | null;
        }[];
        resumen: {
            entregas: number;
            total_ganancia: number;
            total_comision: number;
        };
    }>;
}
