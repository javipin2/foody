import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../database/database.service';
export declare class ImpresionService implements OnModuleInit {
    private readonly database;
    private readonly config;
    private readonly logger;
    private procesando;
    private readonly LOCK_IMPRESION_COLA;
    constructor(database: DatabaseService, config: ConfigService);
    onModuleInit(): void;
    reimprimirPedido(pedidoId: string, sucursalId: string, cocinaId?: string): Promise<{
        pedido_id: string;
        encolado: boolean;
    }>;
    encolarPorPedido(pedidoId: string, sucursalId: string): Promise<void>;
    listarJobs(sucursalId: string, limit?: number): Promise<import("pg").QueryResultRow[]>;
    procesarColaManual(): Promise<void>;
    estadisticasCola(): Promise<{
        pendientes: number;
        error: number;
        enviados_24h: number;
    }>;
    verificarAgente(): Promise<{
        conectado: boolean;
        url: string;
        mensaje: string;
    }>;
    private encolarPorPedidoInterno;
    private listarCocinasPedido;
    private procesarCola;
    private procesarJob;
    private registrarFalloJob;
    private enviarTicket;
    private enviarWs;
}
