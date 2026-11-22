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
exports.CiudadesService = void 0;
const cache_manager_1 = require("@nestjs/cache-manager");
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const TTL_CIUDADES_MS = 3 * 60 * 1000;
const CLAVE_ACTIVAS = 'ciudades:activas';
let CiudadesService = class CiudadesService {
    database;
    cache;
    constructor(database, cache) {
        this.database = database;
        this.cache = cache;
    }
    async listarActivas() {
        const hit = await this.cache.get(CLAVE_ACTIVAS);
        if (hit)
            return hit;
        const data = await this.database.consultar(`SELECT id, nombre, slug, activa
       FROM ciudades
       WHERE activa = true
       ORDER BY nombre ASC`);
        await this.cache.set(CLAVE_ACTIVAS, data, TTL_CIUDADES_MS);
        return data;
    }
    async listarRestaurantesPorSlug(slug) {
        const clave = `ciudades:rest:${slug}`;
        const hit = await this.cache.get(clave);
        if (hit)
            return hit;
        const data = await this.database.consultar(`SELECT r.id, r.nombre, r.descripcion, r.logo_url, r.banner_url, r.activo
       FROM restaurantes r
       INNER JOIN ciudades c ON c.id = r.ciudad_id
       WHERE c.slug = $1 AND c.activa = true AND r.activo = true
       ORDER BY r.nombre ASC`, [slug]);
        await this.cache.set(clave, data, TTL_CIUDADES_MS);
        return data;
    }
    async invalidarCache() {
        await this.cache.del(CLAVE_ACTIVAS);
    }
};
exports.CiudadesService = CiudadesService;
exports.CiudadesService = CiudadesService = __decorate([
    (0, common_1.Injectable)(),
    __param(1, (0, common_1.Inject)(cache_manager_1.CACHE_MANAGER)),
    __metadata("design:paramtypes", [database_service_1.DatabaseService, Object])
], CiudadesService);
//# sourceMappingURL=ciudades.service.js.map