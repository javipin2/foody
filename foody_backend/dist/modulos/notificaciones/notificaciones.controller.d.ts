import { JwtPayload } from '../../core/auth/jwt-payload';
import { NotificacionesService } from './notificaciones.service';
export declare class NotificacionesController {
    private readonly notificaciones;
    constructor(notificaciones: NotificacionesService);
    diagnostico(): Promise<{
        firebase_admin: boolean;
        pendientes: number;
        abandonadas_24h: number;
        max_intentos: number;
        tokens_web_staff: number;
        tokens_web_cliente: number;
        tokens_web_domiciliario: number;
    }>;
    procesarCola(): Promise<{
        procesadas: number;
        enviados: number;
        abandonadas: number;
        modo: string;
    }>;
    prueba(usuario: JwtPayload): Promise<{
        procesadas: number;
        enviados: number;
        abandonadas: number;
        modo: string;
    }>;
    pruebaWeb(usuario: JwtPayload): Promise<{
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
}
