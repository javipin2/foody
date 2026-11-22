import { OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { NotificacionesService } from '../../modulos/notificaciones/notificaciones.service';
import { PagosRecurrentesService } from '../../modulos/pagos/pagos-recurrentes.service';
export declare class SuscripcionesCronService implements OnModuleInit {
    private readonly database;
    private readonly notificaciones;
    private readonly pagosRecurrentes;
    private readonly logger;
    private readonly LOCK_SUSCRIPCIONES_CRON;
    constructor(database: DatabaseService, notificaciones: NotificacionesService, pagosRecurrentes: PagosRecurrentesService);
    onModuleInit(): void;
    ejecutar(): Promise<{
        vencidas: number;
        bloqueadas: number;
        avisos3d: number;
        avisosHoy: number;
        renovaciones: number;
        renovaciones_fallos: number;
    }>;
    private procesarRenovacionesAutomaticas;
    private marcarVencidas;
    private bloquearTrasGracia;
    private enviarAvisosVencimiento;
    private enviarAviso3Dias;
    private enviarAvisoVenceHoy;
    private listarParaAviso3Dias;
    private listarParaAvisoHoy;
    private pushAviso;
    private diasGraciaBloqueo;
}
