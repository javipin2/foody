import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { DispatchService } from './dispatch.service';
import { IniciarSesionDto, ResponderOfertaDto, UbicacionDto } from './dto/independiente.dto';
export declare class DomiciliariosIndependientesService {
    private readonly database;
    private readonly dispatch;
    private readonly alertasRiesgo;
    constructor(database: DatabaseService, dispatch: DispatchService, alertasRiesgo: AlertasRiesgoService);
    iniciarSesion(domiciliarioId: string, dto: IniciarSesionDto): Promise<{
        sesion_id: string | undefined;
        disponible: boolean;
    }>;
    actualizarUbicacion(domiciliarioId: string, dto: UbicacionDto): Promise<{
        ok: boolean;
    }>;
    cerrarSesion(domiciliarioId: string): Promise<{
        ok: boolean;
    }>;
    ofertasActivas(domiciliarioId: string): Promise<QueryResultRow[]>;
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
    pedidosActivos(domiciliarioId: string): Promise<QueryResultRow[]>;
    marcarEnCamino(pedidoId: string, domiciliarioId: string): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    confirmarEntrega(pedidoId: string, domiciliarioId: string): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    ganancias(domiciliarioId: string): Promise<QueryResultRow[]>;
    private obtenerActivo;
    private obtenerSesionActiva;
    private consultarUnoCliente;
}
