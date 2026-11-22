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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MenuCacheService = void 0;
const cache_manager_1 = require("@nestjs/cache-manager");
const common_1 = require("@nestjs/common");
const PREFIJO = 'menu:';
const TTL_MS = 15 * 60 * 1000;
let MenuCacheService = class MenuCacheService {
    cache;
    constructor(cache) {
        this.cache = cache;
    }
    clave(sucursalId) {
        return `${PREFIJO}${sucursalId}`;
    }
    async obtener(sucursalId) {
        return this.cache.get(this.clave(sucursalId));
    }
    async guardar(sucursalId, datos) {
        await this.cache.set(this.clave(sucursalId), datos, TTL_MS);
    }
    async invalidar(sucursalId) {
        await this.cache.del(this.clave(sucursalId));
    }
};
exports.MenuCacheService = MenuCacheService;
exports.MenuCacheService = MenuCacheService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, common_1.Inject)(cache_manager_1.CACHE_MANAGER)),
    __metadata("design:paramtypes", [Object])
], MenuCacheService);
//# sourceMappingURL=menu-cache.service.js.map