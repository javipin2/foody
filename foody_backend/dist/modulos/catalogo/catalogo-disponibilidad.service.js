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
Object.defineProperty(exports, "__esModule", { value: true });
exports.CatalogoDisponibilidadService = void 0;
const common_1 = require("@nestjs/common");
const menu_cache_service_1 = require("../../core/cache/menu-cache.service");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const costeo_service_1 = require("../costeo/costeo.service");
let CatalogoDisponibilidadService = class CatalogoDisponibilidadService {
    database;
    costeo;
    realtime;
    menuCache;
    constructor(database, costeo, realtime, menuCache) {
        this.database = database;
        this.costeo = costeo;
        this.realtime = realtime;
        this.menuCache = menuCache;
    }
    async sincronizarPorIngrediente(sucursalId, ingredienteId) {
        return this.database.enTransaccion(async (client) => this.sincronizarPorIngredienteEnTransaccion(client, sucursalId, ingredienteId));
    }
    async sincronizarPorIngredienteEnTransaccion(client, sucursalId, ingredienteId) {
        const productos = await client.query(`WITH RECURSIVE recetas_relacionadas AS (
         -- Caso base: recetas que usan el ingrediente directamente
         SELECT DISTINCT receta_id
         FROM receta_items
         WHERE ingrediente_id = $2
         
         UNION
         
         -- Caso recursivo: recetas que usan una subreceta que usa el ingrediente
         SELECT ri.receta_id
         FROM receta_items ri
         INNER JOIN recetas_relacionadas rr ON rr.receta_id = ri.subreceta_id
         WHERE ri.tipo_item = 'subreceta'
       )
       SELECT DISTINCT p.id
       FROM productos p
       INNER JOIN recetas_relacionadas rr ON rr.receta_id = p.receta_id
       WHERE p.sucursal_id = $1
       UNION
       SELECT DISTINCT pii.producto_id AS id
       FROM producto_items_incluidos pii
       INNER JOIN productos pin ON pin.id = pii.producto_incluido_id
       INNER JOIN recetas_relacionadas rr ON rr.receta_id = pin.receta_id
       WHERE pii.sucursal_id = $1`, [sucursalId, ingredienteId]);
        const cambios = [];
        for (const row of productos.rows) {
            const cambio = await this.evaluarDisponibilidadProducto(client, sucursalId, row.id);
            if (cambio)
                cambios.push(cambio);
        }
        return cambios;
    }
    emitirCambios(sucursalId, cambios) {
        if (!cambios.length)
            return;
        void this.menuCache.invalidar(sucursalId);
        const agotados = cambios.filter((c) => !c.disponible).map((c) => c.producto_id);
        const reactivados = cambios.filter((c) => c.disponible).map((c) => c.producto_id);
        if (agotados.length) {
            void this.realtime.catalogoDisponibilidad(sucursalId, {
                producto_ids: agotados,
                disponible: false,
            });
        }
        if (reactivados.length) {
            void this.realtime.catalogoDisponibilidad(sucursalId, {
                producto_ids: reactivados,
                disponible: true,
            });
        }
    }
    async evaluarDisponibilidadProducto(client, sucursalId, productoId) {
        const actual = await client.query(`SELECT disponible FROM productos WHERE id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
        if (!actual.rows[0])
            return null;
        const expandidos = await this.costeo.expandirIngredientesProducto(client, productoId, sucursalId, 1, false);
        if (!expandidos.length)
            return null;
        let hayStock = true;
        for (const uso of expandidos) {
            const ing = await client.query(`SELECT stock_actual, descontar_stock FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2`, [uso.ingrediente_id, sucursalId]);
            const fila = ing.rows[0];
            if (!fila?.descontar_stock)
                continue;
            if (Number(fila.stock_actual) < uso.cantidad - 1e-9) {
                hayStock = false;
                break;
            }
        }
        const nuevoDisponible = hayStock;
        if (actual.rows[0].disponible === nuevoDisponible)
            return null;
        await client.query(`UPDATE productos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`, [nuevoDisponible, productoId, sucursalId]);
        return { producto_id: productoId, disponible: nuevoDisponible };
    }
};
exports.CatalogoDisponibilidadService = CatalogoDisponibilidadService;
exports.CatalogoDisponibilidadService = CatalogoDisponibilidadService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        costeo_service_1.CosteoService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        menu_cache_service_1.MenuCacheService])
], CatalogoDisponibilidadService);
//# sourceMappingURL=catalogo-disponibilidad.service.js.map