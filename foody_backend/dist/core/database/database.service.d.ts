import { OnModuleDestroy } from '@nestjs/common';
import { QueryResultRow } from 'pg';
import { TransactionHooksService } from './transaction-hooks.service';
export declare class DatabaseService implements OnModuleDestroy {
    private readonly transactionHooks;
    private static readonly connectTimeoutMsDefault;
    private readonly pool;
    constructor(transactionHooks: TransactionHooksService);
    consultar<T extends QueryResultRow = QueryResultRow>(sql: string, parametros?: unknown[]): Promise<T[]>;
    consultarUno<T extends QueryResultRow = QueryResultRow>(sql: string, parametros?: unknown[]): Promise<T | null>;
    enTransaccion<T>(fn: (client: import('pg').PoolClient) => Promise<T>): Promise<T>;
    onModuleDestroy(): Promise<void>;
    intentarAdvisoryLock<T>(lockKey: number, fn: () => Promise<T>): Promise<T | null>;
}
