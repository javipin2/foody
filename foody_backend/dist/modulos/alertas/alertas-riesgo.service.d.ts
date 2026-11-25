import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { TransactionHooksService } from '../../core/database/transaction-hooks.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
export type NivelAlerta = 'bajo' | 'medio' | 'alto' | 'critico';
export interface RegistrarAlertaParams {
    sucursalId: string;
    tipo: string;
    nivel: NivelAlerta;
    descripcion: string;
    referenciaId?: string;
    referenciaTipo?: string;
    deduplicar?: boolean;
}
export declare const UMBRALES_ALERTA: {
    descuentoPorcentajeAlto: number;
    cancelacionesPorDia: number;
    meseroCancelacionVsPromedioFactor: number;
    productoSinVentaDias: number;
    transferenciasMesa: number;
    cuadreCajaCOP: number;
    subidaCostoIngredientePct: number;
    margenBajoPct: number;
    margenDias: number;
    caidaVentasPct: number;
    prepCocinaSubidaPct: number;
    prepCocinaMuestrasMin: number;
    intentosDomiciliario: number;
    demoraEntregaMultiplo: number;
    qrPendienteAprobacionMinutos: number;
    qrRecordatorioAprobacionMinutos: number;
    qrUrgenteAprobacionMinutos: number;
    cajaTurnoHoras: number;
};
export declare class AlertasRiesgoService {
    private readonly database;
    private readonly realtime;
    private readonly notificaciones;
    private readonly transactionHooks;
    private readonly log;
    constructor(database: DatabaseService, realtime: RealtimeBroadcastService, notificaciones: NotificacionesService, transactionHooks: TransactionHooksService);
    registrarEnTransaccion(client: PoolClient, params: RegistrarAlertaParams): Promise<boolean>;
    registrar(params: RegistrarAlertaParams): Promise<void>;
    registrarVariasEnTransaccion(alertas: RegistrarAlertaParams[]): Promise<number>;
    private despuesDeInsertar;
    private enviarPushSiCritica;
    evaluarCancelacionesFrecuentes(client: PoolClient, sucursalId: string, usuarioId: string, pedidoId: string): Promise<void>;
    evaluarDemoraEntrega(client: PoolClient, pedidoId: string, sucursalId: string): Promise<void>;
    evaluarSubidaCostoIngrediente(client: PoolClient, sucursalId: string, ingredienteId: string, nombreIngrediente: string, costoAnterior: number, costoNuevo: number): Promise<void>;
    evaluarAlertasProgramadas(sucursalId: string): Promise<{
        generadas: number;
    }>;
}
