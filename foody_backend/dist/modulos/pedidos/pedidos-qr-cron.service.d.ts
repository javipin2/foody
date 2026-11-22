import { OnModuleInit } from '@nestjs/common';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
export declare class PedidosQrCronService implements OnModuleInit {
    private readonly database;
    private readonly notificaciones;
    private readonly realtime;
    private readonly auditoria;
    private readonly logger;
    private ejecutando;
    private readonly LOCK_PEDIDOS_QR_CRON;
    constructor(database: DatabaseService, notificaciones: NotificacionesService, realtime: RealtimeBroadcastService, auditoria: AuditoriaService);
    onModuleInit(): void;
    ejecutar(): Promise<number>;
}
