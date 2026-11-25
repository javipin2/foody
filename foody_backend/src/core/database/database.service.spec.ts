import { DatabaseService } from './database.service';

describe('DatabaseService pool connection timeout', () => {
  const databaseUrlOriginal = process.env.DATABASE_URL;
  const connectTimeoutOriginal = process.env.DB_POOL_CONNECT_TIMEOUT_MS;

  afterEach(() => {
    if (databaseUrlOriginal === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = databaseUrlOriginal;
    if (connectTimeoutOriginal === undefined) {
      delete process.env.DB_POOL_CONNECT_TIMEOUT_MS;
    } else {
      process.env.DB_POOL_CONNECT_TIMEOUT_MS = connectTimeoutOriginal;
    }
  });

  it('uses a five-second default without opening a database connection', async () => {
    process.env.DATABASE_URL = 'postgres://qa:qa@127.0.0.1:1/qa';
    delete process.env.DB_POOL_CONNECT_TIMEOUT_MS;
    const database = new DatabaseService({} as never);
    const options = (
      database as unknown as {
        pool: { options: { connectionTimeoutMillis: number } };
      }
    ).pool.options;

    expect(options.connectionTimeoutMillis).toBe(5000);
    await database.onModuleDestroy();
  });

  it('honors DB_POOL_CONNECT_TIMEOUT_MS when it is a positive number', async () => {
    process.env.DATABASE_URL = 'postgres://qa:qa@127.0.0.1:1/qa';
    process.env.DB_POOL_CONNECT_TIMEOUT_MS = '2300';
    const database = new DatabaseService({} as never);
    const options = (
      database as unknown as {
        pool: { options: { connectionTimeoutMillis: number } };
      }
    ).pool.options;

    expect(options.connectionTimeoutMillis).toBe(2300);
    await database.onModuleDestroy();
  });
});
