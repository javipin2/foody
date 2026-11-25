import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
export declare class CocinasDemorasCronService implements OnModuleInit, OnModuleDestroy {
    private readonly database;
    private readonly alertas;
    private readonly logger;
    private ejecutando;
    private intervalo?;
    private inicio?;
    constructor(database: DatabaseService, alertas: AlertasRiesgoService);
    onModuleInit(): void;
    onModuleDestroy(): void;
    private iniciarCiclo;
    ejecutar(): Promise<number>;
}
