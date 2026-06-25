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
exports.RATE_LIMIT_META = 'rate_limit';
const RateLimitPublico = (maximo = 60, ventanaMs = 60_000) => (0, common_1.SetMetadata)(exports.RATE_LIMIT_META, { maximo, ventanaMs });
exports.RateLimitPublico = RateLimitPublico;
let RateLimitGuard = class RateLimitGuard {
    static { RateLimitGuard_1 = this; }
    reflector;
    static store = new Map();
    constructor(reflector) {
        this.reflector = reflector;
    }
    canActivate(context) {
        const opts = this.reflector.get(exports.RATE_LIMIT_META, context.getHandler());
        if (!opts)
            return true;
        const req = context.switchToHttp().getRequest();
        const ip = req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
            req.ip ||
            'unknown';
        const clave = `${ip}:${req.method}:${req.path}`;
        const ahora = Date.now();
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
    __metadata("design:paramtypes", [core_1.Reflector])
], RateLimitGuard);
//# sourceMappingURL=rate-limit.guard.js.map