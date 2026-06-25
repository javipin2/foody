import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
export declare class DispatchService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly realtime;
    private readonly notificaciones;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, realtime: RealtimeBroadcastService, notificaciones: NotificacionesService);
    contarPlantaLibres(sucursalId: string): Promise<number>;
    intentarDispatchAutomatico(pedidoId: string, sucursalId: string): Promise<{
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
    } | {
        iniciado: boolean;
        motivo: string;
    }>;
    iniciarBusquedaIndependientes(pedidoId: string, sucursalId: string): Promise<{
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
    private buscarIndependientesCercanos;
    private expirarOfertasVencidas;
    private crearAlertaSinDomiciliario;
    distanciaKm(lat1: number, lng1: number, lat2: number, lng2: number): number;
    consultarUnoCliente<T extends QueryResultRow>(client: PoolClient, sql: string, params: unknown[]): Promise<T | null>;
    calcularGanancias(costoDomicilio: number): {
        comision: number;
        ganancia: number;
    };
}
