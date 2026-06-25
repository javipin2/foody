import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
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
    readonly descuentoPorcentajeAlto: 30;
    readonly cancelacionesPorDia: 3;
    readonly transferenciasMesa: 2;
    readonly cuadreCajaCOP: 5000;
    readonly subidaCostoIngredientePct: 15;
    readonly margenBajoPct: 20;
    readonly margenDias: 7;
    readonly caidaVentasPct: 40;
    readonly intentosDomiciliario: 3;
    readonly demoraEntregaMultiplo: 2;
};
export declare class AlertasRiesgoService {
    private readonly database;
    private readonly realtime;
    constructor(database: DatabaseService, realtime: RealtimeBroadcastService);
    registrarEnTransaccion(client: PoolClient, params: RegistrarAlertaParams): Promise<void>;
    registrar(params: RegistrarAlertaParams): Promise<void>;
    evaluarCancelacionesFrecuentes(client: PoolClient, sucursalId: string, usuarioId: string, pedidoId: string): Promise<void>;
    evaluarDemoraEntrega(client: PoolClient, pedidoId: string, sucursalId: string): Promise<void>;
    evaluarSubidaCostoIngrediente(client: PoolClient, sucursalId: string, ingredienteId: string, nombreIngrediente: string, costoAnterior: number, costoNuevo: number): Promise<void>;
    evaluarAlertasProgramadas(sucursalId: string): Promise<{
        generadas: number;
    }>;
}
