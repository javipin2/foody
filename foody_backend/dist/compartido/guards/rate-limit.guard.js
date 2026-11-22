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
var RateLimitGuard_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.RateLimitGuard = exports.RateLimitPublico = exports.RATE_LIMIT_META = void 0;
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const validar_config_produccion_1 = require("../../core/config/validar-config-produccion");
const database_service_1 = require("../../core/database/database.service");
exports.RATE_LIMIT_META = 'rate_limit';
const RateLimitPublico = (maximo = 60, ventanaMs = 60_000) => (0, common_1.SetMetadata)(exports.RATE_LIMIT_META, { maximo, ventanaMs });
exports.RateLimitPublico = RateLimitPublico;
let RateLimitGuard = class RateLimitGuard {
    static { RateLimitGuard_1 = this; }
    reflector;
    database;
    static store = new Map();
    constructor(reflector, database) {
        this.reflector = reflector;
        this.database = database;
    }
    async canActivate(context) {
        const opts = this.reflector.get(exports.RATE_LIMIT_META, context.getHandler());
        if (!opts)
            return true;
        const forzar = process.env.RATE_LIMIT_FORZAR === '1';
        if (!(0, validar_config_produccion_1.esProduccion)() && !forzar)
            return true;
        const req = context.switchToHttp().getRequest();
        const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
            req.ip ||
            'unknown';
        const clave = `${ip}:${req.method}:${req.path}`;
        const ahora = Date.now();
        if ((0, validar_config_produccion_1.esProduccion)() || forzar) {
            try {
                const r = await this.database.consultarUno(`INSERT INTO rate_limit_entries (clave, ventana_ms, reinicio_at, cuenta)
           VALUES (
             $1,
             $2,
             now() + ($2::text || ' milliseconds')::interval,
             1
           )
           ON CONFLICT (clave) DO UPDATE
             SET ventana_ms = EXCLUDED.ventana_ms,
                 reinicio_at = CASE
                   WHEN now() >= rate_limit_entries.reinicio_at
                     THEN now() + (EXCLUDED.ventana_ms::text || ' milliseconds')::interval
                   ELSE rate_limit_entries.reinicio_at
                 END,
                 cuenta = CASE
                   WHEN now() >= rate_limit_entries.reinicio_at
                     THEN 1
                   ELSE rate_limit_entries.cuenta + 1
                 END
           RETURNING cuenta`, [clave, opts.ventanaMs]);
                const cuenta = Number(r?.cuenta ?? 1);
                if (cuenta > opts.maximo) {
                    throw new common_1.HttpException({
                        error: 'RATE_LIMIT',
                        message: 'Demasiadas peticiones. Intenta de nuevo en un momento.',
                    }, common_1.HttpStatus.TOO_MANY_REQUESTS);
                }
                return true;
            }
            catch {
            }
        }
        let entrada = RateLimitGuard_1.store.get(clave);
        if (!entrada || ahora >= entrada.reinicio) {
            entrada = { cuenta: 0, reinicio: ahora + opts.ventanaMs };
            RateLimitGuard_1.store.set(clave, entrada);
        }
        entrada.cuenta += 1;
        if (entrada.cuenta > opts.maximo) {
            throw new common_1.HttpException({
                error: 'RATE_LIMIT',
                message: 'Demasiadas peticiones. Intenta de nuevo en un momento.',
            }, common_1.HttpStatus.TOO_MANY_REQUESTS);
        }
        return true;
    }
};
exports.RateLimitGuard = RateLimitGuard;
exports.RateLimitGuard = RateLimitGuard = RateLimitGuard_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [core_1.Reflector,
        database_service_1.DatabaseService])
], RateLimitGuard);
//# sourceMappingURL=rate-limit.guard.js.map