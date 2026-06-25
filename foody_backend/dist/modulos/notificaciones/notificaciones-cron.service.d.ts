import { OnModuleInit } from '@nestjs/common';
import { NotificacionesService } from './notificaciones.service';
export declare class NotificacionesCronService implements OnModuleInit {
    private readonly notificaciones;
    private readonly logger;
    constructor(notificaciones: NotificacionesService);
    onModuleInit(): void;
    ejecutar(): Promise<void>;
}
