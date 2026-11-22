import { OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
export declare class ConfiguracionGlobalService implements OnModuleInit {
    private readonly database;
    private readonly log;
    private cache;
    constructor(database: DatabaseService);
    onModuleInit(): Promise<void>;
    recargar(): Promise<void>;
    valor(clave: string, defecto: string): string;
    numero(clave: string, defecto: number): number;
    ofertaExpiraSeg(): number;
    comisionFoodyPct(): number;
    radioInicialKm(): number;
    ampliacionRadioKm(): number;
    intentosMaxBusqueda(): number;
    private aplicarUmbralesAlerta;
}
export declare class ConfiguracionGlobalModule {
}
