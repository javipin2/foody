import { OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { NotificacionesService } from '../../modulos/notificaciones/notificaciones.service';
export declare class SuscripcionesCronService implements OnModuleInit {
    private readonly database;
    private readonly notificaciones;
    private readonly logger;
    constructor(database: DatabaseService, notificaciones: NotificacionesService);
    onModuleInit(): void;
    ejecutar(): Promise<{
        vencidas: number;
        bloqueadas: number;
        avisos3d: number;
        avisosHoy: number;
    }>;
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
