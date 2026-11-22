import { OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
export declare class MesasReservaCronService implements OnModuleInit {
    private readonly database;
    private readonly realtime;
    private readonly logger;
    private ejecutando;
    private readonly LOCK_MESAS_RESERVA_CRON;
    constructor(database: DatabaseService, realtime: RealtimeBroadcastService);
    onModuleInit(): void;
    expirarReservas(): Promise<number>;
}
