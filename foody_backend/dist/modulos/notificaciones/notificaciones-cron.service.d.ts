import { OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { NotificacionesService } from './notificaciones.service';
export declare class NotificacionesCronService implements OnModuleInit {
    private readonly notificaciones;
    private readonly database;
    private readonly logger;
    private readonly LOCK_NOTIFICACIONES_CRON;
    private readonly LOCK_PURGA_CRECIMIENTO;
    private _ticks;
    constructor(notificaciones: NotificacionesService, database: DatabaseService);
    onModuleInit(): void;
    ejecutar(): Promise<void>;
}
