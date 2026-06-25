import { OnModuleDestroy } from '@nestjs/common';
import { QueryResultRow } from 'pg';
export declare class DatabaseService implements OnModuleDestroy {
    private readonly pool;
    constructor();
    consultar<T extends QueryResultRow = QueryResultRow>(sql: string, parametros?: unknown[]): Promise<T[]>;
    consultarUno<T extends QueryResultRow = QueryResultRow>(sql: string, parametros?: unknown[]): Promise<T | null>;
    enTransaccion<T>(fn: (client: import('pg').PoolClient) => Promise<T>): Promise<T>;
    onModuleDestroy(): Promise<void>;
}
