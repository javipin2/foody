import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool, QueryResultRow } from 'pg';
import { TransactionHooksService } from './transaction-hooks.service';

@Injectable()
export class DatabaseService implements OnModuleDestroy {
  private readonly pool: Pool;

  constructor(private readonly transactionHooks: TransactionHooksService) {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
      throw new Error('DATABASE_URL no está definida en .env');
    }
    this.pool = new Pool({
      connectionString,
      max: Number(process.env.DB_POOL_MAX) || 10,
    });
    // Sin esto, un cliente idle que muere (p. ej. tras SQL fatal) tumba todo Node.
    this.pool.on('error', (err) => {
      console.error('[DatabaseService] Error en cliente idle del pool:', err.message);
    });
  }

  async consultar<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    parametros: unknown[] = [],
  ): Promise<T[]> {
    const resultado = await this.pool.query<T>(sql, parametros);
    return resultado.rows;
  }

  async consultarUno<T extends QueryResultRow = QueryResultRow>(
    sql: string,
    parametros: unknown[] = [],
  ): Promise<T | null> {
    const filas = await this.consultar<T>(sql, parametros);
    return filas[0] ?? null;
  }

  async enTransaccion<T>(fn: (client: import('pg').PoolClient) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const resultado = await fn(client);
      await client.query('COMMIT');
      this.transactionHooks.ejecutarTrasCommit(client);
      return resultado;
    } catch (error) {
      await client.query('ROLLBACK');
      this.transactionHooks.descartar(client);
      throw error;
    } finally {
      client.release();
    }
  }

  async onModuleDestroy() {
    await this.pool.end();
  }

  /**
   * Líder único para tareas periódicas (multi-réplica).
   * ponytail: advisory lock evita que N réplicas ejecuten el mismo cron.
   */
  async intentarAdvisoryLock<T>(
    lockKey: number,
    fn: () => Promise<T>,
  ): Promise<T | null> {
    const client = await this.pool.connect();
    let adquirio = false;
    try {
      const r = await client.query<{ ok: boolean }>(
        `SELECT pg_try_advisory_lock($1::bigint) AS ok`,
        [lockKey],
      );
      adquirio = !!r.rows[0]?.ok;
      if (!adquirio) return null;
      return await fn();
    } finally {
      if (adquirio) {
        try {
          await client.query(
            `SELECT pg_advisory_unlock($1::bigint)`,
            [lockKey],
          );
        } catch {
          // Si unlock falla, el lock expira al terminar la sesión del client.
        }
      }
      client.release();
    }
  }
}
