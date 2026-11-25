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
exports.CatalogoService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const costeo_service_1 = require("../costeo/costeo.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const plan_features_service_1 = require("../../core/auth/plan-features.service");
const menu_cache_service_1 = require("../../core/cache/menu-cache.service");
const paginacion_dto_1 = require("../../compartido/dto/paginacion.dto");
let CatalogoService = class CatalogoService {
    database;
    costeo;
    realtime;
    planFeatures;
    menuCache;
    constructor(database, costeo, realtime, planFeatures, menuCache) {
        this.database = database;
        this.costeo = costeo;
        this.realtime = realtime;
        this.planFeatures = planFeatures;
        this.menuCache = menuCache;
    }
    invalidarMenu(sucursalId) {
        void this.menuCache.invalidar(sucursalId);
    }
    async listarCategorias(sucursalId) {
        return this.database.consultar(`SELECT id, nombre, orden, activa, imagen_url, created_at
       FROM categorias
       WHERE sucursal_id = $1
       ORDER BY orden ASC, nombre ASC`, [sucursalId]);
    }
    async crearCategoria(dto) {
        const fila = await this.database.consultarUno(`INSERT INTO categorias (sucursal_id, nombre, orden, activa)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, orden, activa`, [dto.sucursal_id, dto.nombre, dto.orden ?? 0]);
        this.invalidarMenu(dto.sucursal_id);
        return fila;
    }
    async actualizarCategoria(id, sucursalId, dto) {
        await this.exigirCategoria(id, sucursalId);
        const campos = [];
        const valores = [];
        let i = 1;
        if (dto.nombre !== undefined) {
            campos.push(`nombre = $${i++}`);
            valores.push(dto.nombre);
        }
        if (dto.orden !== undefined) {
            campos.push(`orden = $${i++}`);
            valores.push(dto.orden);
        }
        if (dto.activa !== undefined) {
            campos.push(`activa = $${i++}`);
            valores.push(dto.activa);
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        await this.database.consultarUno(`UPDATE categorias SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
        this.invalidarMenu(sucursalId);
        return { id };
    }
    async eliminarCategoria(id, sucursalId) {
        await this.exigirCategoria(id, sucursalId);
        await this.database.consultarUno(`UPDATE categorias SET activa = false WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        this.invalidarMenu(sucursalId);
        return { id, activa: false };
    }
    async listarProductos(sucursalId, query = {}) {
        const opts = (0, paginacion_dto_1.opcionesListado)(query, 50);
        const select = `SELECT p.id, p.nombre, p.descripcion, p.precio, p.precio_para_llevar,
              p.disponible, p.orden, p.categoria_id, p.imagen_url,
              c.nombre AS categoria_nombre, p.cocina_id
       FROM productos p
       LEFT JOIN categorias c ON c.id = p.categoria_id
       WHERE p.sucursal_id = $1`;
        if (!opts.paginar) {
            return this.database.consultar(`${select}
       ORDER BY c.orden ASC, p.orden ASC, p.nombre ASC
       LIMIT $2`, [sucursalId, opts.limite]);
        }
        const { page, limit, offset } = (0, paginacion_dto_1.resolverPaginacion)(opts.page, opts.limite, 50);
        const [items, totalRow] = await Promise.all([
            this.database.consultar(`${select}
       ORDER BY c.orden ASC, p.orden ASC, p.nombre ASC
       LIMIT $2 OFFSET $3`, [sucursalId, limit, offset]),
            this.database.consultarUno(`SELECT COUNT(*)::int AS count FROM productos WHERE sucursal_id = $1`, [sucursalId]),
        ]);
        return (0, paginacion_dto_1.envolverPaginado)(items, totalRow?.count ?? 0, page, limit);
    }
    async crearProducto(dto, restauranteId) {
        if (restauranteId) {
            await this.planFeatures.assertLimiteProductos(restauranteId, dto.sucursal_id);
        }
        await this.exigirCategoriaActiva(dto.categoria_id, dto.sucursal_id);
        const cocinaId = await this.resolverCocinaActiva(dto.sucursal_id, dto.cocina_id);
        if ((dto.disponible ?? true) && !cocinaId) {
            throw this.errorCocinaRequerida();
        }
        const fila = await this.database.consultarUno(`INSERT INTO productos (
         sucursal_id, categoria_id, cocina_id, nombre, descripcion,
         precio, precio_para_llevar, imagen_url, disponible, orden
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING id, nombre, precio, precio_para_llevar, disponible, categoria_id, imagen_url`, [
            dto.sucursal_id,
            dto.categoria_id,
            cocinaId,
            dto.nombre,
            dto.descripcion ?? null,
            dto.precio,
            dto.precio_para_llevar ?? null,
            dto.imagen_url ?? null,
            dto.disponible ?? true,
            dto.orden ?? 0,
        ]);
        this.invalidarMenu(dto.sucursal_id);
        return fila;
    }
    async actualizarProducto(id, sucursalId, dto) {
        const producto = await this.exigirProducto(id, sucursalId);
        if (dto.categoria_id !== undefined) {
            if (!dto.categoria_id) {
                throw new common_1.BadRequestException('La categoría no es válida para esta sede');
            }
            await this.exigirCategoriaActiva(dto.categoria_id, sucursalId);
        }
        let cocinaFinal = producto.cocina_id;
        if (dto.cocina_id !== undefined) {
            cocinaFinal = dto.cocina_id
                ? await this.resolverCocinaActiva(sucursalId, dto.cocina_id)
                : null;
        }
        else if (dto.disponible === true && cocinaFinal) {
            cocinaFinal = await this.resolverCocinaActiva(sucursalId, cocinaFinal);
        }
        const disponibleFinal = dto.disponible ?? producto.disponible;
        if (disponibleFinal && !cocinaFinal) {
            throw this.errorCocinaRequerida();
        }
        const campos = [];
        const valores = [];
        let i = 1;
        const mapa = [
            ['categoria_id', 'categoria_id'],
            ['cocina_id', 'cocina_id'],
            ['nombre', 'nombre'],
            ['descripcion', 'descripcion'],
            ['precio', 'precio'],
            ['disponible', 'disponible'],
            ['orden', 'orden'],
            ['margen_objetivo', 'margen_objetivo'],
            ['precio_para_llevar', 'precio_para_llevar'],
            ['imagen_url', 'imagen_url'],
        ];
        for (const [key, col] of mapa) {
            const v = dto[key];
            if (v !== undefined) {
                campos.push(`${col} = $${i++}`);
                valores.push(v);
            }
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        await this.database.consultarUno(`UPDATE productos SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
        if (dto.margen_objetivo !== undefined || dto.precio !== undefined) {
            await this.costeo.recalcularProductoPorId(id, sucursalId);
        }
        this.invalidarMenu(sucursalId);
        return { id };
    }
    async cambiarDisponibilidad(id, sucursalId, disponible) {
        const producto = await this.exigirProducto(id, sucursalId);
        if (disponible) {
            if (!producto.cocina_id)
                throw this.errorCocinaRequerida();
            await this.resolverCocinaActiva(sucursalId, producto.cocina_id);
        }
        await this.database.consultarUno(`UPDATE productos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`, [disponible, id, sucursalId]);
        void this.realtime.catalogoDisponibilidad(sucursalId, {
            producto_ids: [id],
            disponible,
        });
        this.invalidarMenu(sucursalId);
        return { id, disponible };
    }
    listarToppings(sucursalId) {
        return this.database.consultar(`SELECT id, nombre, precio, disponible, receta_id, costo_calculado,
              precio_sugerido, created_at
       FROM toppings WHERE sucursal_id = $1 ORDER BY nombre ASC
       LIMIT $2`, [sucursalId, paginacion_dto_1.LIMITE_LISTADO_SIN_PAGINA]);
    }
    async crearTopping(dto) {
        const fila = await this.database.consultarUno(`INSERT INTO toppings (sucursal_id, nombre, precio, disponible)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, precio, disponible`, [dto.sucursal_id, dto.nombre, dto.precio]);
        this.invalidarMenu(dto.sucursal_id);
        return fila;
    }
    async actualizarTopping(id, sucursalId, datos) {
        await this.exigirTopping(id, sucursalId);
        const campos = [];
        const valores = [];
        let i = 1;
        if (datos.nombre !== undefined) {
            campos.push(`nombre = $${i++}`);
            valores.push(datos.nombre);
        }
        if (datos.precio !== undefined) {
            campos.push(`precio = $${i++}`);
            valores.push(datos.precio);
        }
        if (datos.disponible !== undefined) {
            campos.push(`disponible = $${i++}`);
            valores.push(datos.disponible);
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        await this.database.consultarUno(`UPDATE toppings SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
        if (datos.disponible !== undefined) {
            void this.realtime.catalogoDisponibilidad(sucursalId, {
                topping_ids: [id],
                disponible: datos.disponible,
            });
        }
        this.invalidarMenu(sucursalId);
        return { id, ...datos };
    }
    listarBebidas(sucursalId) {
        return this.database.consultar(`SELECT id, nombre, precio, disponible, receta_id, costo_calculado,
              precio_sugerido, created_at
       FROM bebidas WHERE sucursal_id = $1 ORDER BY nombre ASC
       LIMIT $2`, [sucursalId, paginacion_dto_1.LIMITE_LISTADO_SIN_PAGINA]);
    }
    async crearBebida(dto) {
        const cocinaId = await this.resolverCocinaActiva(dto.sucursal_id);
        if (!cocinaId)
            throw this.errorCocinaRequerida();
        const fila = await this.database.consultarUno(`INSERT INTO bebidas (sucursal_id, nombre, precio, disponible)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, precio, disponible`, [dto.sucursal_id, dto.nombre, dto.precio]);
        if (fila) {
            await this.asegurarProductoEspejoBebida(dto.sucursal_id, fila, cocinaId);
        }
        this.invalidarMenu(dto.sucursal_id);
        return fila;
    }
    async actualizarBebida(id, sucursalId, datos) {
        await this.exigirBebida(id, sucursalId);
        const bebidaActual = await this.database.consultarUno(`SELECT disponible FROM bebidas WHERE id = $1 AND sucursal_id = $2`, [
            id,
            sucursalId,
        ]);
        const disponibleFinal = datos.disponible ?? bebidaActual?.disponible ?? false;
        if (disponibleFinal) {
            const espejo = await this.database.consultarUno(`SELECT id, cocina_id FROM productos
         WHERE sucursal_id = $1 AND bebida_origen_id = $2`, [sucursalId, id]);
            if (espejo) {
                if (!espejo.cocina_id)
                    throw this.errorCocinaRequerida();
                await this.resolverCocinaActiva(sucursalId, espejo.cocina_id);
            }
            else {
                const cocinaId = await this.resolverCocinaActiva(sucursalId);
                if (!cocinaId)
                    throw this.errorCocinaRequerida();
            }
        }
        const campos = [];
        const valores = [];
        let i = 1;
        if (datos.nombre !== undefined) {
            campos.push(`nombre = $${i++}`);
            valores.push(datos.nombre);
        }
        if (datos.precio !== undefined) {
            campos.push(`precio = $${i++}`);
            valores.push(datos.precio);
        }
        if (datos.disponible !== undefined) {
            campos.push(`disponible = $${i++}`);
            valores.push(datos.disponible);
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        await this.database.consultarUno(`UPDATE bebidas SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
        if (datos.disponible !== undefined) {
            void this.realtime.catalogoDisponibilidad(sucursalId, {
                bebida_ids: [id],
                disponible: datos.disponible,
            });
        }
        this.invalidarMenu(sucursalId);
        await this.sincronizarProductoEspejoBebida(sucursalId, id, datos);
        return { id, ...datos };
    }
    async vincularToppingProducto(productoId, toppingId, sucursalId) {
        await this.exigirProducto(productoId, sucursalId);
        await this.exigirTopping(toppingId, sucursalId);
        await this.database.consultarUno(`INSERT INTO producto_toppings (producto_id, topping_id)
       VALUES ($1,$2)
       ON CONFLICT (producto_id, topping_id) DO NOTHING`, [productoId, toppingId]);
        this.invalidarMenu(sucursalId);
        return { producto_id: productoId, topping_id: toppingId };
    }
    async listarToppingsProducto(productoId, sucursalId) {
        await this.exigirProducto(productoId, sucursalId);
        return this.database.consultar(`SELECT t.id, t.nombre, t.precio, t.disponible
       FROM producto_toppings pt
       INNER JOIN toppings t ON t.id = pt.topping_id
       WHERE pt.producto_id = $1 AND t.sucursal_id = $2
       ORDER BY t.nombre ASC`, [productoId, sucursalId]);
    }
    async configurarToppingsProducto(productoId, sucursalId, toppingIds) {
        await this.exigirProducto(productoId, sucursalId);
        const unicos = [...new Set(toppingIds.filter(Boolean))];
        for (const tid of unicos) {
            await this.exigirTopping(tid, sucursalId);
        }
        await this.database.consultar(`DELETE FROM producto_toppings WHERE producto_id = $1`, [productoId]);
        for (const tid of unicos) {
            await this.database.consultar(`INSERT INTO producto_toppings (producto_id, topping_id) VALUES ($1,$2)`, [productoId, tid]);
        }
        this.invalidarMenu(sucursalId);
        return { producto_id: productoId, topping_ids: unicos };
    }
    async vincularBebidaProducto(productoId, bebidaId, sucursalId) {
        await this.exigirProducto(productoId, sucursalId);
        await this.exigirBebida(bebidaId, sucursalId);
        await this.database.consultarUno(`INSERT INTO producto_bebidas (producto_id, bebida_id)
       VALUES ($1,$2)
       ON CONFLICT (producto_id, bebida_id) DO NOTHING`, [productoId, bebidaId]);
        this.invalidarMenu(sucursalId);
        return { producto_id: productoId, bebida_id: bebidaId };
    }
    listarCombos(sucursalId) {
        return this.database.consultar(`SELECT c.id, c.nombre, c.descripcion, c.precio_fijo, c.disponible, c.imagen_url,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', ci.id,
                    'tipo_item', ci.tipo_item,
                    'item_id', ci.item_id,
                    'cantidad', ci.cantidad
                  )
                ) FILTER (WHERE ci.id IS NOT NULL),
                '[]'
              ) AS items
       FROM combos c
       LEFT JOIN combo_items ci ON ci.combo_id = c.id
       WHERE c.sucursal_id = $1
       GROUP BY c.id
       ORDER BY c.nombre ASC
       LIMIT $2`, [sucursalId, paginacion_dto_1.LIMITE_LISTADO_SIN_PAGINA]);
    }
    async crearCombo(dto) {
        const tieneProducto = dto.items.some((i) => i.tipo_item === 'producto');
        if (!tieneProducto) {
            throw new common_1.BadRequestException('El combo debe incluir al menos un producto');
        }
        if (dto.items.length < 2) {
            throw new common_1.BadRequestException('El combo debe incluir al menos 2 ítems (producto, bebida o topping)');
        }
        const resultado = await this.database.enTransaccion(async (client) => {
            const combo = await client.query(`INSERT INTO combos (sucursal_id, nombre, descripcion, precio_fijo, disponible)
         VALUES ($1,$2,$3,$4,true)
         RETURNING id`, [dto.sucursal_id, dto.nombre, dto.descripcion ?? null, dto.precio_fijo]);
            const comboId = combo.rows[0].id;
            for (const item of dto.items) {
                await this.validarComboItem(client, dto.sucursal_id, item);
                await client.query(`INSERT INTO combo_items (combo_id, tipo_item, item_id, cantidad)
           VALUES ($1,$2,$3,$4)`, [comboId, item.tipo_item, item.item_id, item.cantidad ?? 1]);
            }
            return { id: comboId, nombre: dto.nombre, precio_fijo: dto.precio_fijo };
        });
        this.invalidarMenu(dto.sucursal_id);
        return resultado;
    }
    async cambiarDisponibilidadCombo(id, sucursalId, disponible) {
        await this.exigirCombo(id, sucursalId);
        await this.database.consultarUno(`UPDATE combos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`, [disponible, id, sucursalId]);
        this.invalidarMenu(sucursalId);
        return { id, disponible };
    }
    async validarComboItem(client, sucursalId, item) {
        if (item.tipo_item === 'producto') {
            await this.exigirProductoEnClient(client, item.item_id, sucursalId);
        }
        else if (item.tipo_item === 'bebida') {
            const b = await client.query(`SELECT id FROM bebidas WHERE id = $1 AND sucursal_id = $2`, [item.item_id, sucursalId]);
            if (!b.rows[0])
                throw new common_1.NotFoundException('Bebida no encontrada');
        }
        else {
            const t = await client.query(`SELECT id FROM toppings WHERE id = $1 AND sucursal_id = $2`, [item.item_id, sucursalId]);
            if (!t.rows[0])
                throw new common_1.NotFoundException('Topping no encontrado');
        }
    }
    async exigirCombo(id, sucursalId) {
        const c = await this.database.consultarUno(`SELECT id FROM combos WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!c)
            throw new common_1.NotFoundException('Combo no encontrado');
    }
    async exigirProductoEnClient(client, id, sucursalId) {
        const p = await client.query(`SELECT id FROM productos WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!p.rows[0])
            throw new common_1.NotFoundException('Producto no encontrado');
    }
    async exigirTopping(id, sucursalId) {
        const t = await this.database.consultarUno(`SELECT id FROM toppings WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!t)
            throw new common_1.NotFoundException('Topping no encontrado');
    }
    async exigirBebida(id, sucursalId) {
        const b = await this.database.consultarUno(`SELECT id FROM bebidas WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!b)
            throw new common_1.NotFoundException('Bebida no encontrada');
    }
    async exigirCategoria(id, sucursalId) {
        const c = await this.database.consultarUno(`SELECT id FROM categorias WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!c)
            throw new common_1.NotFoundException('Categoría no encontrada');
    }
    async listarItemsIncluidos(productoId, sucursalId) {
        await this.exigirProducto(productoId, sucursalId);
        return this.costeo.listarItemsIncluidosProducto(productoId, sucursalId);
    }
    async configurarItemsIncluidos(productoId, sucursalId, dto) {
        await this.exigirProducto(productoId, sucursalId);
        const items = dto.items ?? [];
        for (const item of items) {
            if (item.producto_incluido_id === productoId) {
                throw new common_1.BadRequestException('Un producto no puede incluirse a sí mismo');
            }
            await this.exigirProducto(item.producto_incluido_id, sucursalId);
        }
        await this.database.enTransaccion(async (client) => {
            await this.validarSinCicloIncluidos(client, productoId, items);
            await client.query(`DELETE FROM producto_items_incluidos
         WHERE producto_id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
            for (const item of items) {
                await client.query(`INSERT INTO producto_items_incluidos (
             sucursal_id, producto_id, producto_incluido_id, cantidad
           ) VALUES ($1,$2,$3,$4)`, [sucursalId, productoId, item.producto_incluido_id, item.cantidad]);
            }
        });
        await this.costeo.recalcularProductoPorId(productoId, sucursalId);
        return this.listarItemsIncluidos(productoId, sucursalId);
    }
    async copiarMenuDesde(restauranteId, sucursalDestinoId, sucursalOrigenId, usuarioId) {
        if (sucursalDestinoId === sucursalOrigenId) {
            throw new common_1.BadRequestException('ORIGEN_IGUAL_DESTINO');
        }
        const resultado = await this.database.enTransaccion(async (client) => {
            const suc = await client.query(`SELECT id FROM sucursales
         WHERE restaurante_id = $1 AND activa = true AND id = ANY($2::uuid[])`, [restauranteId, [sucursalDestinoId, sucursalOrigenId]]);
            if (suc.rows.length < 2) {
                throw new common_1.BadRequestException('SUCURSALES_INVALIDAS');
            }
            const mapCat = new Map();
            const cats = await client.query(`SELECT id, nombre, orden, imagen_url
         FROM categorias WHERE sucursal_id = $1 AND activa = true`, [sucursalOrigenId]);
            for (const c of cats.rows) {
                const exist = await client.query(`SELECT id FROM categorias
           WHERE sucursal_id = $1 AND LOWER(nombre) = LOWER($2) LIMIT 1`, [sucursalDestinoId, c.nombre]);
                if (exist.rows[0]) {
                    mapCat.set(c.id, exist.rows[0].id);
                }
                else {
                    const ins = await client.query(`INSERT INTO categorias (sucursal_id, nombre, orden, activa, imagen_url)
             VALUES ($1,$2,$3,true,$4) RETURNING id`, [sucursalDestinoId, c.nombre, c.orden, c.imagen_url]);
                    mapCat.set(c.id, ins.rows[0].id);
                }
            }
            const mapTop = new Map();
            const tops = await client.query(`SELECT id, nombre, precio FROM toppings WHERE sucursal_id = $1`, [
                sucursalOrigenId,
            ]);
            for (const t of tops.rows) {
                const exist = await client.query(`SELECT id FROM toppings
           WHERE sucursal_id = $1 AND LOWER(nombre) = LOWER($2) LIMIT 1`, [sucursalDestinoId, t.nombre]);
                if (exist.rows[0]) {
                    mapTop.set(t.id, exist.rows[0].id);
                }
                else {
                    const ins = await client.query(`INSERT INTO toppings (sucursal_id, nombre, precio, disponible)
             VALUES ($1,$2,$3,true) RETURNING id`, [sucursalDestinoId, t.nombre, t.precio]);
                    mapTop.set(t.id, ins.rows[0].id);
                }
            }
            const mapBeb = new Map();
            const bebs = await client.query(`SELECT id, nombre, precio FROM bebidas WHERE sucursal_id = $1`, [
                sucursalOrigenId,
            ]);
            for (const b of bebs.rows) {
                const exist = await client.query(`SELECT id FROM bebidas
           WHERE sucursal_id = $1 AND LOWER(nombre) = LOWER($2) LIMIT 1`, [sucursalDestinoId, b.nombre]);
                if (exist.rows[0]) {
                    mapBeb.set(b.id, exist.rows[0].id);
                }
                else {
                    const ins = await client.query(`INSERT INTO bebidas (sucursal_id, nombre, precio, disponible)
             VALUES ($1,$2,$3,true) RETURNING id`, [sucursalDestinoId, b.nombre, b.precio]);
                    mapBeb.set(b.id, ins.rows[0].id);
                }
            }
            const mapCocina = new Map();
            const cocinasOrig = await client.query(`SELECT id, nombre FROM cocinas WHERE sucursal_id = $1 AND activa = true`, [sucursalOrigenId]);
            for (const co of cocinasOrig.rows) {
                const dest = await client.query(`SELECT id FROM cocinas
           WHERE sucursal_id = $1 AND activa = true
             AND LOWER(nombre) = LOWER($2) LIMIT 1`, [sucursalDestinoId, co.nombre]);
                if (dest.rows[0])
                    mapCocina.set(co.id, dest.rows[0].id);
            }
            const cocinaDefault = await client.query(`SELECT id FROM cocinas WHERE sucursal_id = $1 AND activa = true LIMIT 1`, [sucursalDestinoId]);
            const cocinaFallback = cocinaDefault.rows[0]?.id ?? null;
            let productosNuevos = 0;
            const mapProd = new Map();
            const prods = await client.query(`SELECT id, categoria_id, cocina_id, nombre, descripcion, precio,
                precio_para_llevar, imagen_url, disponible, orden
         FROM productos WHERE sucursal_id = $1`, [sucursalOrigenId]);
            for (const p of prods.rows) {
                const nuevaCat = mapCat.get(p.categoria_id);
                if (!nuevaCat)
                    continue;
                const exist = await client.query(`SELECT id FROM productos
           WHERE sucursal_id = $1 AND LOWER(nombre) = LOWER($2) LIMIT 1`, [sucursalDestinoId, p.nombre]);
                if (exist.rows[0]) {
                    mapProd.set(p.id, exist.rows[0].id);
                    continue;
                }
                const cocinaId = p.cocina_id
                    ? (mapCocina.get(p.cocina_id) ?? cocinaFallback)
                    : cocinaFallback;
                if (p.disponible && !cocinaId) {
                    throw new common_1.BadRequestException({
                        error: 'COCINA_DESTINO_NO_CONFIGURADA',
                        message: 'Configura una cocina activa en la sede destino antes de copiar productos disponibles.',
                    });
                }
                const ins = await client.query(`INSERT INTO productos (
             sucursal_id, categoria_id, cocina_id, nombre, descripcion,
             precio, precio_para_llevar, imagen_url, disponible, orden
           ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
           RETURNING id`, [
                    sucursalDestinoId,
                    nuevaCat,
                    cocinaId,
                    p.nombre,
                    p.descripcion,
                    p.precio,
                    p.precio_para_llevar,
                    p.imagen_url,
                    p.disponible,
                    p.orden,
                ]);
                mapProd.set(p.id, ins.rows[0].id);
                productosNuevos++;
            }
            const linksTop = await client.query(`SELECT pt.producto_id, pt.topping_id
         FROM producto_toppings pt
         INNER JOIN productos p ON p.id = pt.producto_id
         WHERE p.sucursal_id = $1`, [sucursalOrigenId]);
            for (const l of linksTop.rows) {
                const np = mapProd.get(l.producto_id);
                const nt = mapTop.get(l.topping_id);
                if (!np || !nt)
                    continue;
                await client.query(`INSERT INTO producto_toppings (producto_id, topping_id)
           VALUES ($1,$2) ON CONFLICT (producto_id, topping_id) DO NOTHING`, [np, nt]);
            }
            const linksBeb = await client.query(`SELECT pb.producto_id, pb.bebida_id
         FROM producto_bebidas pb
         INNER JOIN productos p ON p.id = pb.producto_id
         WHERE p.sucursal_id = $1`, [sucursalOrigenId]);
            for (const l of linksBeb.rows) {
                const np = mapProd.get(l.producto_id);
                const nb = mapBeb.get(l.bebida_id);
                if (!np || !nb)
                    continue;
                await client.query(`INSERT INTO producto_bebidas (producto_id, bebida_id)
           VALUES ($1,$2) ON CONFLICT (producto_id, bebida_id) DO NOTHING`, [np, nb]);
            }
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, datos_despues
         ) VALUES ($1,$2,'COPIAR_MENU','productos',$3::jsonb)`, [
                sucursalDestinoId,
                usuarioId,
                JSON.stringify({
                    origen: sucursalOrigenId,
                    categorias: mapCat.size,
                    productos_nuevos: productosNuevos,
                    toppings: mapTop.size,
                    bebidas: mapBeb.size,
                }),
            ]);
            return {
                categorias: mapCat.size,
                productos_nuevos: productosNuevos,
                toppings: mapTop.size,
                bebidas: mapBeb.size,
            };
        });
        this.invalidarMenu(sucursalDestinoId);
        return resultado;
    }
    async validarSinCicloIncluidos(client, productoId, items) {
        for (const item of items) {
            const visitados = new Set();
            const cola = [item.producto_incluido_id];
            while (cola.length) {
                const actual = cola.shift();
                if (actual === productoId) {
                    throw new common_1.BadRequestException('Configuración circular de ítems incluidos');
                }
                if (visitados.has(actual))
                    continue;
                visitados.add(actual);
                const hijos = await client.query(`SELECT producto_incluido_id FROM producto_items_incluidos
           WHERE producto_id = $1`, [actual]);
                for (const h of hijos.rows) {
                    cola.push(h.producto_incluido_id);
                }
            }
        }
    }
    async asegurarProductoEspejoBebida(sucursalId, bebida, cocinaAsignada) {
        const existente = await this.database.consultarUno(`SELECT id, cocina_id, disponible FROM productos
       WHERE sucursal_id = $1 AND bebida_origen_id = $2`, [sucursalId, bebida.id]);
        if (existente) {
            if (existente.disponible && !existente.cocina_id) {
                throw this.errorCocinaRequerida();
            }
            if (existente.disponible && existente.cocina_id) {
                await this.resolverCocinaActiva(sucursalId, existente.cocina_id);
            }
            return existente;
        }
        const catId = await this.asegurarCategoriaPorNombres(sucursalId, ['Bebidas'], null, 80, '(bebida|jugo)');
        const cocinaId = cocinaAsignada ?? (await this.resolverCocinaActiva(sucursalId));
        if (bebida.disponible && !cocinaId)
            throw this.errorCocinaRequerida();
        return this.database.consultarUno(`INSERT INTO productos (
         sucursal_id, categoria_id, cocina_id, nombre, descripcion, precio,
         disponible, orden, bebida_origen_id
       ) VALUES ($1,$2,$3,$4,'Bebida vendible',$5,$6,0,$7)
       RETURNING id`, [
            sucursalId,
            catId,
            cocinaId ?? null,
            bebida.nombre,
            Number(bebida.precio),
            bebida.disponible,
            bebida.id,
        ]);
    }
    async sincronizarProductoEspejoBebida(sucursalId, bebidaId, datos) {
        const campos = [];
        const valores = [];
        let i = 1;
        if (datos.nombre !== undefined) {
            campos.push(`nombre = $${i++}`);
            valores.push(datos.nombre);
        }
        if (datos.precio !== undefined) {
            campos.push(`precio = $${i++}`);
            valores.push(datos.precio);
        }
        if (datos.disponible !== undefined) {
            campos.push(`disponible = $${i++}`);
            valores.push(datos.disponible);
        }
        if (!campos.length) {
            const b = await this.database.consultarUno(`SELECT id, nombre, precio, disponible FROM bebidas
         WHERE id = $1 AND sucursal_id = $2`, [bebidaId, sucursalId]);
            if (b)
                await this.asegurarProductoEspejoBebida(sucursalId, b);
            return;
        }
        valores.push(sucursalId, bebidaId);
        const actualizado = await this.database.consultarUno(`UPDATE productos SET ${campos.join(', ')}
       WHERE sucursal_id = $${i++} AND bebida_origen_id = $${i}
       RETURNING id`, valores);
        if (!actualizado) {
            const b = await this.database.consultarUno(`SELECT id, nombre, precio, disponible FROM bebidas
         WHERE id = $1 AND sucursal_id = $2`, [bebidaId, sucursalId]);
            if (b)
                await this.asegurarProductoEspejoBebida(sucursalId, b);
        }
    }
    async asegurarCategoriaPorNombres(sucursalId, crearComo, nombresExactos, orden, regexNombre) {
        let existente = null;
        if (regexNombre) {
            existente = await this.database.consultarUno(`SELECT id FROM categorias
         WHERE sucursal_id = $1 AND activa = true
           AND LOWER(TRIM(nombre)) ~ $2
         ORDER BY orden ASC LIMIT 1`, [sucursalId, regexNombre]);
        }
        else if (nombresExactos) {
            existente = await this.database.consultarUno(`SELECT id FROM categorias
         WHERE sucursal_id = $1 AND activa = true
           AND LOWER(TRIM(nombre)) = ANY($2::text[])
         ORDER BY orden ASC LIMIT 1`, [sucursalId, nombresExactos]);
        }
        if (existente)
            return existente.id;
        const creada = await this.database.consultarUno(`INSERT INTO categorias (sucursal_id, nombre, orden, activa)
       VALUES ($1, $2, $3, true)
       RETURNING id`, [sucursalId, crearComo[0], orden]);
        if (!creada)
            throw new common_1.BadRequestException('No se pudo crear categoría');
        return creada.id;
    }
    async exigirCategoriaActiva(categoriaId, sucursalId) {
        const categoria = await this.database.consultarUno(`SELECT id FROM categorias
       WHERE id = $1 AND sucursal_id = $2 AND activa = true`, [categoriaId, sucursalId]);
        if (!categoria) {
            throw new common_1.BadRequestException({
                error: 'CATEGORIA_NO_DISPONIBLE',
                message: 'Selecciona una categoría activa de esta sede.',
            });
        }
    }
    async resolverCocinaActiva(sucursalId, cocinaId) {
        const cocina = cocinaId
            ? await this.database.consultarUno(`SELECT id FROM cocinas
           WHERE id = $1 AND sucursal_id = $2 AND activa = true`, [cocinaId, sucursalId])
            : await this.database.consultarUno(`SELECT id FROM cocinas
           WHERE sucursal_id = $1 AND activa = true
           ORDER BY nombre ASC LIMIT 1`, [sucursalId]);
        if (cocinaId && !cocina) {
            throw new common_1.BadRequestException({
                error: 'COCINA_NO_DISPONIBLE',
                message: 'Selecciona una cocina activa de esta sede.',
            });
        }
        return cocina?.id ?? null;
    }
    errorCocinaRequerida() {
        return new common_1.BadRequestException({
            error: 'COCINA_REQUERIDA',
            message: 'Asigna una cocina activa de esta sede antes de ofrecer el producto a los clientes.',
        });
    }
    async exigirProducto(id, sucursalId) {
        const p = await this.database.consultarUno(`SELECT id, disponible, cocina_id FROM productos
       WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!p)
            throw new common_1.NotFoundException('Producto no encontrado');
        return p;
    }
};
exports.CatalogoService = CatalogoService;
exports.CatalogoService = CatalogoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        costeo_service_1.CosteoService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        plan_features_service_1.PlanFeaturesService,
        menu_cache_service_1.MenuCacheService])
], CatalogoService);
//# sourceMappingURL=catalogo.service.js.map