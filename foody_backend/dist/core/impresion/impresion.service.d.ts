import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../database/database.service';
export declare class ImpresionService implements OnModuleInit {
    private readonly database;
    private readonly config;
    private readonly logger;
    private procesando;
    constructor(database: DatabaseService, config: ConfigService);
    onModuleInit(): void;
    encolarPorPedido(pedidoId: string, sucursalId: string): Promise<void>;
    private encolarPorPedidoInterno;
    private procesarCola;
    private enviarTicket;
}
