"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var DatabaseService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.DatabaseService = void 0;
const common_1 = require("@nestjs/common");
const pg_1 = require("pg");
const transaction_hooks_service_1 = require("./transaction-hooks.service");
let DatabaseService = class DatabaseService {
    static { DatabaseService_1 = this; }
    transactionHooks;
    static connectTimeoutMsDefault = 5000;
    pool;
    constructor(transactionHooks) {
        this.transactionHooks = transactionHooks;
        const connectionString = process.env.DATABASE_URL;
        if (!connectionString) {
            throw new Error('DATABASE_URL no está definida en .env');
        }
        const connectTimeoutMs = Number(process.env.DB_POOL_CONNECT_TIMEOUT_MS);
        this.pool = new pg_1.Pool({
            connectionString,
            max: Number(process.env.DB_POOL_MAX) || 10,
            connectionTimeoutMillis: Number.isFinite(connectTimeoutMs) && connectTimeoutMs > 0
                ? connectTimeoutMs
                : DatabaseService_1.connectTimeoutMsDefault,
        });
        this.pool.on('error', (err) => {
            console.error('[DatabaseService] Error en cliente idle del pool:', err.message);
        });
    }
    async consultar(sql, parametros = []) {
        const resultado = await this.pool.query(sql, parametros);
        return resultado.rows;
    }
    async consultarUno(sql, parametros = []) {
        const filas = await this.consultar(sql, parametros);
        return filas[0] ?? null;
    }
    async enTransaccion(fn) {
        const client = await this.pool.connect();
        try {
            await client.query('BEGIN');
            const resultado = await fn(client);
            await client.query('COMMIT');
            this.transactionHooks.ejecutarTrasCommit(client);
            return resultado;
        }
        catch (error) {
            await client.query('ROLLBACK');
            this.transactionHooks.descartar(client);
            throw error;
        }
        finally {
            client.release();
        }
    }
    async onModuleDestroy() {
        await this.pool.end();
    }
    async intentarAdvisoryLock(lockKey, fn) {
        const client = await this.pool.connect();
        let adquirio = false;
        try {
            const r = await client.query(`SELECT pg_try_advisory_lock($1::bigint) AS ok`, [lockKey]);
            adquirio = !!r.rows[0]?.ok;
            if (!adquirio)
                return null;
            return await fn();
        }
        finally {
            if (adquirio) {
                try {
                    await client.query(`SELECT pg_advisory_unlock($1::bigint)`, [
                        lockKey,
                    ]);
                }
                catch {
                }
            }
            client.release();
        }
    }
};
exports.DatabaseService = DatabaseService;
exports.DatabaseService = DatabaseService = DatabaseService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [transaction_hooks_service_1.TransactionHooksService])
], DatabaseService);
//# sourceMappingURL=database.service.js.map