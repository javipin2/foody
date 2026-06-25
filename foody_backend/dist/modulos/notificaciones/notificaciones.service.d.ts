import { DatabaseService } from '../../core/database/database.service';
import { FcmService } from './fcm.service';
export type EncolarNotificacionDto = {
    sucursal_id?: string;
    tipo: string;
    destinatario_rol?: string;
    destinatario_usuario_id?: string;
    payload?: Record<string, unknown>;
};
export type EnviarPushDto = {
    sucursal_id?: string;
    tipo: string;
    titulo: string;
    cuerpo: string;
    roles?: string[];
    destinatario_usuario_id?: string;
    destinatario_domiciliario_id?: string;
    device_id?: string;
    datos?: Record<string, unknown>;
};
export declare class NotificacionesService {
    private readonly database;
    private readonly fcm;
    private readonly log;
    constructor(database: DatabaseService, fcm: FcmService);
    enviar(dto: EnviarPushDto): Promise<{
        procesadas: number;
        enviados: number;
        modo: string;
    }>;
    encolar(dto: EncolarNotificacionDto): Promise<{
        id: string;
        encolada: boolean;
    }>;
    procesarPendientes(limite?: number): Promise<{
        procesadas: number;
        enviados: number;
        modo: string;
    }>;
    diagnostico(): Promise<{
        firebase_admin: boolean;
        pendientes: number;
        tokens_web_staff: number;
        tokens_web_cliente: number;
        tokens_web_domiciliario: number;
    }>;
    enviarPruebaWeb(opciones?: {
        usuario_id?: string;
        rol?: string;
        todos_web?: boolean;
    }): Promise<{
        enviados: number;
        tokens_web: number;
        mensaje: string;
        fallos?: undefined;
        modo?: undefined;
    } | {
        enviados: number;
        fallos: number;
        tokens_web: number;
        modo: string;
        mensaje?: undefined;
    }>;
    private _resolverTokens;
}
