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
let CatalogoService = class CatalogoService {
    database;
    costeo;
    realtime;
    constructor(database, costeo, realtime) {
        this.database = database;
        this.costeo = costeo;
        this.realtime = realtime;
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
        return { id };
    }
    async eliminarCategoria(id, sucursalId) {
        await this.exigirCategoria(id, sucursalId);
        await this.database.consultarUno(`UPDATE categorias SET activa = false WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        return { id, activa: false };
    }
    async listarProductos(sucursalId) {
        return this.database.consultar(`SELECT p.id, p.nombre, p.descripcion, p.precio, p.precio_para_llevar,
              p.disponible, p.orden, p.categoria_id, c.nombre AS categoria_nombre, p.cocina_id
       FROM productos p
       LEFT JOIN categorias c ON c.id = p.categoria_id
       WHERE p.sucursal_id = $1
       ORDER BY c.orden ASC, p.orden ASC, p.nombre ASC`, [sucursalId]);
    }
    async crearProducto(dto) {
        const cocinaId = dto.cocina_id ??
            (await this.database.consultarUno(`SELECT id FROM cocinas WHERE sucursal_id = $1 AND activa = true LIMIT 1`, [dto.sucursal_id]))?.id;
        const fila = await this.database.consultarUno(`INSERT INTO productos (
         sucursal_id, categoria_id, cocina_id, nombre, descripcion,
         precio, precio_para_llevar, disponible, orden
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       RETURNING id, nombre, precio, precio_para_llevar, disponible, categoria_id`, [
            dto.sucursal_id,
            dto.categoria_id,
            cocinaId,
            dto.nombre,
            dto.descripcion ?? null,
            dto.precio,
            dto.precio_para_llevar ?? null,
            dto.disponible ?? true,
            dto.orden ?? 0,
        ]);
        return fila;
    }
    async actualizarProducto(id, sucursalId, dto) {
        await this.exigirProducto(id, sucursalId);
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
        return { id };
    }
    async cambiarDisponibilidad(id, sucursalId, disponible) {
        await this.exigirProducto(id, sucursalId);
        await this.database.consultarUno(`UPDATE productos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`, [disponible, id, sucursalId]);
        void this.realtime.catalogoDisponibilidad(sucursalId, {
            producto_ids: [id],
            disponible,
        });
        return { id, disponible };
    }
    listarToppings(sucursalId) {
        return this.database.consultar(`SELECT id, nombre, precio, disponible, created_at
       FROM toppings WHERE sucursal_id = $1 ORDER BY nombre ASC`, [sucursalId]);
    }
    async crearTopping(dto) {
        return this.database.consultarUno(`INSERT INTO toppings (sucursal_id, nombre, precio, disponible)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, precio, disponible`, [dto.sucursal_id, dto.nombre, dto.precio]);
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
        return { id, ...datos };
    }
    listarBebidas(sucursalId) {
        return this.database.consultar(`SELECT id, nombre, precio, disponible, created_at
       FROM bebidas WHERE sucursal_id = $1 ORDER BY nombre ASC`, [sucursalId]);
    }
    async crearBebida(dto) {
        return this.database.consultarUno(`INSERT INTO bebidas (sucursal_id, nombre, precio, disponible)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, precio, disponible`, [dto.sucursal_id, dto.nombre, dto.precio]);
    }
    async actualizarBebida(id, sucursalId, datos) {
        await this.exigirBebida(id, sucursalId);
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
        return { id, ...datos };
    }
    async vincularToppingProducto(productoId, toppingId, sucursalId) {
        await this.exigirProducto(productoId, sucursalId);
        await this.exigirTopping(toppingId, sucursalId);
        await this.database.consultarUno(`INSERT INTO producto_toppings (producto_id, topping_id)
       VALUES ($1,$2)
       ON CONFLICT (producto_id, topping_id) DO NOTHING`, [productoId, toppingId]);
        return { producto_id: productoId, topping_id: toppingId };
    }
    async vincularBebidaProducto(productoId, bebidaId, sucursalId) {
        await this.exigirProducto(productoId, sucursalId);
        await this.exigirBebida(bebidaId, sucursalId);
        await this.database.consultarUno(`INSERT INTO producto_bebidas (producto_id, bebida_id)
       VALUES ($1,$2)
       ON CONFLICT (producto_id, bebida_id) DO NOTHING`, [productoId, bebidaId]);
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
       ORDER BY c.nombre ASC`, [sucursalId]);
    }
    async crearCombo(dto) {
        return this.database.enTransaccion(async (client) => {
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
    }
    async cambiarDisponibilidadCombo(id, sucursalId, disponible) {
        await this.exigirCombo(id, sucursalId);
        await this.database.consultarUno(`UPDATE combos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`, [disponible, id, sucursalId]);
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
           ) VALUES ($1,$2,$3,$4)`, [
                    sucursalId,
                    productoId,
                    item.producto_incluido_id,
                    item.cantidad,
                ]);
            }
        });
        await this.costeo.recalcularProductoPorId(productoId, sucursalId);
        return this.listarItemsIncluidos(productoId, sucursalId);
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
    async exigirProducto(id, sucursalId) {
        const p = await this.database.consultarUno(`SELECT id FROM productos WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!p)
            throw new common_1.NotFoundException('Producto no encontrado');
    }
};
exports.CatalogoService = CatalogoService;
exports.CatalogoService = CatalogoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        costeo_service_1.CosteoService,
        realtime_broadcast_service_1.RealtimeBroadcastService])
], CatalogoService);
//# sourceMappingURL=catalogo.service.js.map