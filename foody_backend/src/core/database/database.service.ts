import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Pool, QueryResultRow } from 'pg';

@Injectable()
export class DatabaseService implements OnModuleDestroy {
  private readonly pool: Pool;

  constructor() {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
      throw new Error('DATABASE_URL no está definida en .env');
    }
    this.pool = new Pool({ connectionString });
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
      return resultado;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async onModuleDestroy() {
    await this.pool.end();
  }
}
