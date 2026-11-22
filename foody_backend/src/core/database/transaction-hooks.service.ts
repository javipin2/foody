import { Injectable, Logger } from '@nestjs/common';
import type { PoolClient } from 'pg';

type HookPostCommit = () => void;

@Injectable()
export class TransactionHooksService {
  private readonly log = new Logger(TransactionHooksService.name);
  private readonly pendientes = new WeakMap<PoolClient, HookPostCommit[]>();

  programarDespuesCommit(client: PoolClient, hook: HookPostCommit): void {
    const lista = this.pendientes.get(client) ?? [];
    lista.push(hook);
    this.pendientes.set(client, lista);
  }

  ejecutarTrasCommit(client: PoolClient): void {
    const lista = this.pendientes.get(client);
    this.pendientes.delete(client);
    if (!lista?.length) return;
    for (const hook of lista) {
      try {
        hook();
      } catch (e) {
        this.log.warn(
          `Hook post-commit falló: ${e instanceof Error ? e.message : e}`,
        );
      }
    }
  }

  descartar(client: PoolClient): void {
    this.pendientes.delete(client);
  }
}
