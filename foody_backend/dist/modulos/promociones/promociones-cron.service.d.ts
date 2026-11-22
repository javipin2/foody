import { OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { PromocionesService } from './promociones.service';
export declare class PromocionesCronService implements OnModuleInit {
    private readonly promociones;
    private readonly database;
    private readonly logger;
    private readonly LOCK_PROMOCIONES_CRON;
    constructor(promociones: PromocionesService, database: DatabaseService);
    onModuleInit(): void;
    ejecutar(): Promise<void>;
}
