import { JwtPayload } from '../../core/auth/jwt-payload';
import { DispatchService } from './dispatch.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import { DomiciliariosService } from './domiciliarios.service';
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import { IniciarSesionDto, ResponderOfertaDto, UbicacionDto } from './dto/independiente.dto';
export declare class DomiciliariosPlantaController {
    private readonly domiciliariosService;
    private readonly dispatchService;
    constructor(domiciliariosService: DomiciliariosService, dispatchService: DispatchService);
    listarDisponibles(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    asignar(dto: AsignarDomiciliarioDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    dispatchIndependiente(pedidoId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        iniciado: boolean;
        motivo: string;
        oferta_id: string;
        intento?: undefined;
        radio_km?: undefined;
        domiciliarios_notificados?: undefined;
        expira_en_seg?: undefined;
    } | {
        iniciado: boolean;
        motivo: string;
        intento: number;
        oferta_id?: undefined;
        radio_km?: undefined;
        domiciliarios_notificados?: undefined;
        expira_en_seg?: undefined;
    } | {
        iniciado: boolean;
        motivo: string;
        intento: number;
        radio_km: number;
        oferta_id?: undefined;
        domiciliarios_notificados?: undefined;
        expira_en_seg?: undefined;
    } | {
        iniciado: boolean;
        oferta_id: string;
        intento: number;
        radio_km: number;
        domiciliarios_notificados: number;
        expira_en_seg: number;
        motivo?: undefined;
    }>;
}
export declare class DomiciliarioPlantaController {
    private readonly domiciliariosService;
    constructor(domiciliariosService: DomiciliariosService);
    pedidosAsignados(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    enCamino(pedidoId: string, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    confirmarEntrega(pedidoId: string, dto: ConfirmarEntregaDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    historial(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    estadisticas(usuario: JwtPayload): Promise<{
        entregas_hoy: number;
        entregas_semana: number;
        entregas_mes: number;
        tiempo_promedio_min: number | null;
    }>;
}
export declare class DomiciliariosIndependientesController {
    private readonly independientesService;
    constructor(independientesService: DomiciliariosIndependientesService);
    iniciarSesion(dto: IniciarSesionDto, usuario: JwtPayload): Promise<{
        sesion_id: string | undefined;
        disponible: boolean;
    }>;
    ubicacion(dto: UbicacionDto, usuario: JwtPayload): Promise<{
        ok: boolean;
    }>;
    cerrarSesion(usuario: JwtPayload): Promise<{
        ok: boolean;
    }>;
    ofertasActivas(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
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
    pedidosActivos(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    enCamino(pedidoId: string, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    confirmarEntrega(pedidoId: string, usuario: JwtPayload): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    ganancias(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
}
