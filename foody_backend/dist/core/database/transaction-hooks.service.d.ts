import type { PoolClient } from 'pg';
type HookPostCommit = () => void;
export declare class TransactionHooksService {
    private readonly log;
    private readonly pendientes;
    programarDespuesCommit(client: PoolClient, hook: HookPostCommit): void;
    ejecutarTrasCommit(client: PoolClient): void;
    descartar(client: PoolClient): void;
}
export {};
