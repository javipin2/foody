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
exports.CosteoService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const unidad_costeo_util_1 = require("./unidad-costeo.util");
let CosteoService = class CosteoService {
    database;
    alertasRiesgo;
    constructor(database, alertasRiesgo) {
        this.database = database;
        this.alertasRiesgo = alertasRiesgo;
    }
    costoRealUnitario(costoUnitario, rendimientoPorcentaje) {
        const rend = rendimientoPorcentaje > 0 ? rendimientoPorcentaje : 100;
        return costoUnitario * (100 / rend);
    }
    async calcularReceta(client, recetaId, sucursalId, visitados = new Set()) {
        if (visitados.has(recetaId)) {
            throw new common_1.BadRequestException('RECETA_CIRCULAR');
        }
        visitados.add(recetaId);
        const receta = await this.consultarReceta(client, recetaId, sucursalId);
        const items = await client.query(`SELECT tipo_item, ingrediente_id, subreceta_id,
              cantidad::float AS cantidad, unidad
       FROM receta_items WHERE receta_id = $1 ORDER BY orden, id`, [recetaId]);
        let costoIngredientes = 0;
        let costoSubrecetas = 0;
        let costoEmpaques = 0;
        let costoMerma = 0;
        const margenError = Number(receta.margen_error ?? 0.05);
        for (const item of items.rows) {
            const cantidad = Number(item.cantidad);
            if (item.tipo_item === 'ingrediente' && item.ingrediente_id) {
                const { costoReal, mermaExtra } = await this.costoLineaIngrediente(client, item.ingrediente_id, sucursalId, cantidad, item.unidad);
                costoIngredientes += costoReal;
                costoMerma += mermaExtra;
            }
            else if (item.tipo_item === 'subreceta' && item.subreceta_id) {
                const cantidadEfectiva = await this.cantidadEnUnidadSubreceta(client, item.subreceta_id, sucursalId, cantidad, item.unidad);
                const unit = await this.costoUnitarioSubreceta(client, item.subreceta_id, sucursalId, visitados);
                costoSubrecetas += cantidadEfectiva * unit;
            }
            else if (item.tipo_item === 'empaque' && item.ingrediente_id) {
                const { costoReal } = await this.costoLineaIngrediente(client, item.ingrediente_id, sucursalId, cantidad, item.unidad);
                costoEmpaques += costoReal;
            }
        }
        const sumaBase = costoIngredientes + costoSubrecetas;
        if (receta.tipo === 'subreceta') {
            const totalConMargen = sumaBase * (1 + margenError);
            const cantidadResultado = Math.max(Number(receta.cantidad_resultado ?? 1), 0.001);
            const costoPorUnidad = totalConMargen / cantidadResultado;
            return {
                receta_id: recetaId,
                costo_ingredientes: costoIngredientes,
                costo_subrecetas: costoSubrecetas,
                costo_empaques: 0,
                costo_merma: costoMerma,
                costo_base: totalConMargen,
                costo_domicilio: totalConMargen,
                costo_por_porcion: costoPorUnidad,
            };
        }
        const costoBase = sumaBase * (1 + margenError);
        const porciones = Math.max(Number(receta.rendimiento_porciones ?? 1), 1);
        const costoDomicilio = costoBase + costoEmpaques;
        return {
            receta_id: recetaId,
            costo_ingredientes: costoIngredientes,
            costo_subrecetas: costoSubrecetas,
            costo_empaques: costoEmpaques,
            costo_merma: costoMerma,
            costo_base: costoBase,
            costo_domicilio: costoDomicilio,
            costo_por_porcion: costoBase / porciones,
        };
    }
    async persistirCostoReceta(client, sucursalId, desglose, precioVenta) {
        const foodCost = precioVenta && precioVenta > 0
            ? (desglose.costo_por_porcion / precioVenta) * 100
            : null;
        await client.query(`INSERT INTO costos_receta (
         receta_id, sucursal_id, costo_total, costo_por_porcion,
         costo_ingredientes, costo_subrecetas, costo_empaques, costo_merma,
         food_cost_porcentaje, calculado_at
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, now())`, [
            desglose.receta_id,
            sucursalId,
            desglose.costo_base,
            desglose.costo_por_porcion,
            desglose.costo_ingredientes,
            desglose.costo_subrecetas,
            desglose.costo_empaques,
            desglose.costo_merma,
            foodCost,
        ]);
    }
    async recalcularProducto(client, productoId, sucursalId, recalculando = new Set(), recalcularPadres = true) {
        const producto = await client.query(`SELECT receta_id, precio FROM productos
       WHERE id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
        const fila = producto.rows[0];
        if (!fila)
            return 0;
        let costoPorcion = 0;
        let costoDomicilio = 0;
        let desglose = null;
        if (fila.receta_id) {
            desglose = await this.calcularReceta(client, fila.receta_id, sucursalId);
            costoPorcion = desglose.costo_por_porcion;
            costoDomicilio = desglose.costo_domicilio;
        }
        const costoIncluidos = await this.sumarCostosItemsIncluidos(client, productoId, sucursalId, recalculando);
        costoPorcion += costoIncluidos.base;
        costoDomicilio += costoIncluidos.domicilio;
        if (!fila.receta_id && costoIncluidos.base === 0)
            return 0;
        const precio = Number(fila.precio);
        const margenObj = await this.margenObjetivoProducto(client, productoId, sucursalId);
        const precioSugerido = this.calcularPrecioSugerido(costoPorcion, margenObj);
        await client.query(`UPDATE productos SET
         costo_calculado = $1,
         costo_domicilio = $2,
         precio_sugerido = $3
       WHERE id = $4 AND sucursal_id = $5`, [costoPorcion, costoDomicilio, precioSugerido, productoId, sucursalId]);
        if (desglose) {
            await this.persistirCostoReceta(client, sucursalId, desglose, precio);
        }
        await this.evaluarAlertaMargenProducto(client, productoId, sucursalId, precio, costoPorcion);
        if (recalcularPadres) {
            await this.recalcularProductosPadre(client, productoId, sucursalId, recalculando);
        }
        return costoPorcion;
    }
    async recalcularCombo(client, comboId, sucursalId) {
        const combo = await client.query(`SELECT precio_fijo, margen_error, costo_empaque_extra FROM combos
       WHERE id = $1 AND sucursal_id = $2`, [comboId, sucursalId]);
        const fila = combo.rows[0];
        if (!fila)
            throw new common_1.NotFoundException('Combo no encontrado');
        const items = await client.query(`SELECT tipo_item, item_id, cantidad FROM combo_items WHERE combo_id = $1`, [comboId]);
        let costo = Number(fila.costo_empaque_extra ?? 0);
        for (const ci of items.rows) {
            if (ci.tipo_item !== 'producto')
                continue;
            const prod = await client.query(`SELECT costo_calculado AS costo FROM productos
         WHERE id = $1 AND sucursal_id = $2`, [ci.item_id, sucursalId]);
            costo += Number(prod.rows[0]?.costo ?? 0) * ci.cantidad;
        }
        const margenError = Number(fila.margen_error ?? 0);
        costo = costo * (1 + margenError);
        await client.query(`UPDATE combos SET costo_calculado = $1 WHERE id = $2`, [costo, comboId]);
        const precioFijo = Number(fila.precio_fijo);
        if (precioFijo > 0) {
            const margenPct = ((precioFijo - costo) / precioFijo) * 100;
            const umbral = await this.umbralMargenSucursal(client, sucursalId);
            if (margenPct < umbral) {
                await this.alertasRiesgo.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'combo_margen_bajo',
                    nivel: 'medio',
                    descripcion: `Combo con margen ${margenPct.toFixed(1)}% (costo ${costo.toFixed(0)}, precio ${precioFijo})`,
                    referenciaId: comboId,
                    referenciaTipo: 'combo',
                    deduplicar: true,
                });
            }
        }
        return costo;
    }
    async recalcularSucursal(sucursalId) {
        return this.database.enTransaccion(async (client) => {
            const subrecetas = await client.query(`SELECT id FROM recetas
         WHERE sucursal_id = $1 AND tipo = 'subreceta'
         ORDER BY created_at`, [sucursalId]);
            for (const sr of subrecetas.rows) {
                const d = await this.calcularReceta(client, sr.id, sucursalId);
                await this.persistirCostoReceta(client, sucursalId, d, null);
            }
            const productos = await client.query(`SELECT id FROM productos WHERE sucursal_id = $1 AND receta_id IS NOT NULL`, [sucursalId]);
            let nProd = 0;
            for (const p of productos.rows) {
                await this.recalcularProducto(client, p.id, sucursalId);
                nProd++;
            }
            const combos = await client.query(`SELECT id FROM combos WHERE sucursal_id = $1`, [sucursalId]);
            let nCombo = 0;
            for (const c of combos.rows) {
                await this.recalcularCombo(client, c.id, sucursalId);
                nCombo++;
            }
            return {
                productos_recalculados: nProd,
                combos_recalculados: nCombo,
                subrecetas_recalculadas: subrecetas.rows.length,
            };
        });
    }
    async expandirIngredientesProducto(client, productoId, sucursalId, cantidadPorciones, incluirEmpaques) {
        const producto = await client.query(`SELECT receta_id FROM productos WHERE id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
        const recetaId = producto.rows[0]?.receta_id;
        if (!recetaId)
            return [];
        const acumulador = new Map();
        await this.expandirReceta(client, recetaId, sucursalId, cantidadPorciones, incluirEmpaques, new Set(), acumulador);
        const incluidos = await client.query(`SELECT producto_incluido_id, cantidad::float AS cantidad
       FROM producto_items_incluidos
       WHERE producto_id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
        for (const inc of incluidos.rows) {
            const sub = await this.expandirIngredientesProducto(client, inc.producto_incluido_id, sucursalId, cantidadPorciones * Number(inc.cantidad), incluirEmpaques);
            for (const s of sub) {
                acumulador.set(s.ingrediente_id, (acumulador.get(s.ingrediente_id) ?? 0) + s.cantidad);
            }
        }
        return [...acumulador.entries()].map(([ingrediente_id, cantidad]) => ({
            ingrediente_id,
            cantidad,
        }));
    }
    async expandirSoloRecetaProducto(client, productoId, sucursalId, cantidadPorciones, incluirEmpaques) {
        const producto = await client.query(`SELECT receta_id FROM productos WHERE id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
        const recetaId = producto.rows[0]?.receta_id;
        if (!recetaId)
            return [];
        const acumulador = new Map();
        await this.expandirReceta(client, recetaId, sucursalId, cantidadPorciones, incluirEmpaques, new Set(), acumulador);
        return [...acumulador.entries()].map(([ingrediente_id, cantidad]) => ({
            ingrediente_id,
            cantidad,
        }));
    }
    async listarItemsIncluidosProducto(productoId, sucursalId) {
        await this.database.enTransaccion(async (client) => {
            const recalculando = new Set();
            const incluidos = await client.query(`SELECT producto_incluido_id FROM producto_items_incluidos
         WHERE producto_id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
            for (const fila of incluidos.rows) {
                await this.recalcularProducto(client, fila.producto_incluido_id, sucursalId, recalculando, false);
            }
            await this.recalcularProducto(client, productoId, sucursalId, recalculando, false);
        });
        return this.database.consultar(`SELECT pii.id, pii.producto_incluido_id, pii.cantidad,
              pr.nombre AS producto_incluido_nombre,
              pr.precio AS producto_incluido_precio,
              pr.costo_calculado AS producto_incluido_costo
       FROM producto_items_incluidos pii
       INNER JOIN productos pr ON pr.id = pii.producto_incluido_id
       WHERE pii.producto_id = $1 AND pii.sucursal_id = $2
       ORDER BY pr.nombre`, [productoId, sucursalId]);
    }
    calcularPrecioSugerido(costo, margenObjetivoPct) {
        if (margenObjetivoPct >= 100)
            return costo * 2;
        return Math.round(costo / (1 - margenObjetivoPct / 100));
    }
    async impactoStockProducto(productoId, sucursalId, cantidad = 1) {
        return this.database.enTransaccion(async (client) => {
            const producto = await client.query(`SELECT nombre, receta_id FROM productos WHERE id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
            const filaProd = producto.rows[0];
            if (!filaProd) {
                throw new common_1.NotFoundException('Producto no encontrado');
            }
            const expandidos = await this.expandirIngredientesProducto(client, productoId, sucursalId, cantidad, false);
            const incluidos = await client.query(`SELECT pii.producto_incluido_id, pii.cantidad::float AS cantidad, pr.nombre
         FROM producto_items_incluidos pii
         INNER JOIN productos pr ON pr.id = pii.producto_incluido_id
         WHERE pii.producto_id = $1 AND pii.sucursal_id = $2`, [productoId, sucursalId]);
            if (expandidos.length === 0) {
                return {
                    producto_id: productoId,
                    producto_nombre: filaProd.nombre,
                    cantidad,
                    tiene_receta: filaProd.receta_id != null,
                    puede_vender: true,
                    ingredientes: [],
                    faltas: [],
                    incluidos: incluidos.rows.map((i) => ({
                        producto_id: i.producto_incluido_id,
                        nombre: i.nombre,
                        cantidad: Number(i.cantidad) * cantidad,
                    })),
                    mensaje: filaProd.receta_id == null
                        ? 'Sin receta: no descuenta inventario al vender.'
                        : null,
                };
            }
            const ids = expandidos.map((e) => e.ingrediente_id);
            const stockRows = await client.query(`SELECT id, nombre, unidad_base, stock_actual, stock_minimo, descontar_stock
         FROM ingredientes WHERE sucursal_id = $1 AND id = ANY($2::uuid[])`, [sucursalId, ids]);
            const porId = new Map(stockRows.rows.map((r) => [r.id, r]));
            const ingredientes = expandidos.map((exp) => {
                const ing = porId.get(exp.ingrediente_id);
                const disponible = Number(ing?.stock_actual ?? 0);
                const minimo = Number(ing?.stock_minimo ?? 0);
                const descontar = ing?.descontar_stock !== false;
                const necesita = exp.cantidad;
                const falta = descontar && disponible < necesita;
                return {
                    ingrediente_id: exp.ingrediente_id,
                    nombre: ing?.nombre ?? 'Insumo',
                    unidad: ing?.unidad_base ?? 'und',
                    necesita,
                    disponible,
                    minimo,
                    descontar_stock: descontar,
                    bajo_minimo: descontar && disponible <= minimo,
                    falta,
                };
            });
            const faltas = ingredientes.filter((i) => i.falta);
            return {
                producto_id: productoId,
                producto_nombre: filaProd.nombre,
                cantidad,
                tiene_receta: true,
                puede_vender: faltas.length === 0,
                ingredientes,
                faltas,
                incluidos: incluidos.rows.map((i) => ({
                    producto_id: i.producto_incluido_id,
                    nombre: i.nombre,
                    cantidad: Number(i.cantidad) * cantidad,
                })),
                mensaje: faltas.length > 0
                    ? `Falta stock: ${faltas.map((f) => f.nombre).join(', ')}`
                    : 'Stock suficiente para 1 venta.',
            };
        });
    }
    async resumenSucursal(sucursalId) {
        const umbral = await this.umbralMargenSucursalDesdeDb(sucursalId);
        const productos = await this.database.consultar(`SELECT p.id, p.nombre, p.precio, p.precio_para_llevar,
              p.costo_calculado, p.costo_domicilio,
              p.precio_sugerido, p.margen_objetivo,
              CASE WHEN p.precio > 0 AND p.costo_calculado IS NOT NULL
                THEN ROUND(((p.precio - p.costo_calculado) / p.precio) * 100, 1)
                ELSE NULL END AS margen_porcentaje,
              CASE WHEN p.precio > 0 AND p.costo_calculado IS NOT NULL
                THEN ROUND((p.costo_calculado / p.precio) * 100, 1)
                ELSE NULL END AS food_cost_porcentaje
       FROM productos p
       WHERE p.sucursal_id = $1
       ORDER BY p.nombre`, [sucursalId]);
        const combos = await this.listarCombos(sucursalId);
        const bajoMargen = productos.filter((p) => p.margen_porcentaje != null &&
            Number(p.margen_porcentaje) < umbral);
        return {
            productos,
            combos,
            productos_bajo_margen: bajoMargen.length,
            umbral_margen: umbral,
        };
    }
    async recalcularComboPorId(comboId, sucursalId) {
        return this.database.enTransaccion(async (client) => {
            const costo = await this.recalcularCombo(client, comboId, sucursalId);
            return { combo_id: comboId, costo_calculado: costo };
        });
    }
    async recalcularProductoPorId(productoId, sucursalId) {
        return this.database.enTransaccion(async (client) => {
            const costo = await this.recalcularProducto(client, productoId, sucursalId);
            return { producto_id: productoId, costo_calculado: costo };
        });
    }
    crearSubreceta(dto) {
        return this.database.enTransaccion(async (client) => {
            const receta = await client.query(`INSERT INTO recetas (
           sucursal_id, nombre, tipo, margen_error,
           cantidad_resultado, unidad_resultado, rendimiento_porciones
         ) VALUES ($1,$2,'subreceta',$3,$4,$5,1)
         RETURNING id`, [
                dto.sucursal_id,
                dto.nombre,
                dto.margen_error ?? 0.05,
                dto.cantidad_resultado,
                dto.unidad_resultado,
            ]);
            const recetaId = receta.rows[0].id;
            await this.insertarItemsSubreceta(client, recetaId, dto.sucursal_id, dto.items);
            const desglose = await this.calcularReceta(client, recetaId, dto.sucursal_id);
            await this.persistirCostoReceta(client, dto.sucursal_id, desglose, null);
            return {
                receta_id: recetaId,
                costo_por_unidad: desglose.costo_por_porcion,
                desglose,
            };
        });
    }
    listarCombos(sucursalId) {
        return this.database.consultar(`SELECT c.id, c.nombre, c.precio_fijo, c.costo_calculado, c.costo_empaque_extra,
              CASE WHEN c.precio_fijo > 0 AND c.costo_calculado IS NOT NULL
                THEN ROUND(((c.precio_fijo - c.costo_calculado) / c.precio_fijo) * 100, 1)
                ELSE NULL END AS margen_porcentaje,
              CASE WHEN c.precio_fijo > 0 AND c.costo_calculado IS NOT NULL
                THEN ROUND((c.costo_calculado / c.precio_fijo) * 100, 1)
                ELSE NULL END AS food_cost_porcentaje
       FROM combos c
       WHERE c.sucursal_id = $1
       ORDER BY c.nombre`, [sucursalId]);
    }
    listarSubrecetas(sucursalId) {
        return this.database.consultar(`SELECT r.id, r.nombre, r.cantidad_resultado, r.unidad_resultado,
              r.margen_error,
              cr.costo_total,
              cr.costo_por_porcion AS costo_por_unidad,
              cr.costo_ingredientes,
              (
                SELECT COUNT(*)::int
                FROM receta_items ri
                WHERE ri.receta_id = r.id
              ) AS num_items
       FROM recetas r
       LEFT JOIN LATERAL (
         SELECT costo_total, costo_por_porcion, costo_ingredientes
         FROM costos_receta
         WHERE receta_id = r.id
         ORDER BY calculado_at DESC
         LIMIT 1
       ) cr ON true
       WHERE r.sucursal_id = $1 AND r.tipo = 'subreceta'
       ORDER BY r.nombre`, [sucursalId]);
    }
    async obtenerSubrecetaDetalle(recetaId, sucursalId) {
        const cabecera = await this.database.consultarUno(`SELECT id, nombre, cantidad_resultado, unidad_resultado, margen_error
       FROM recetas
       WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`, [recetaId, sucursalId]);
        if (!cabecera)
            throw new common_1.NotFoundException('SUBRECETA_NO_ENCONTRADA');
        const items = await this.database.consultar(`SELECT ri.id, ri.tipo_item, ri.ingrediente_id, ri.subreceta_id,
              ri.cantidad, ri.unidad, ri.orden,
              i.nombre AS ingrediente_nombre,
              i.costo_unitario_actual, i.unidad_base,
              sr.nombre AS subreceta_nombre,
              sr.unidad_resultado AS subreceta_unidad
       FROM receta_items ri
       LEFT JOIN ingredientes i ON i.id = ri.ingrediente_id
       LEFT JOIN recetas sr ON sr.id = ri.subreceta_id
       WHERE ri.receta_id = $1
         AND ri.tipo_item IN ('ingrediente', 'subreceta')
       ORDER BY ri.orden, ri.id`, [recetaId]);
        const costo = await this.database.consultarUno(`SELECT costo_total, costo_por_porcion, costo_ingredientes, costo_merma, calculado_at
       FROM costos_receta
       WHERE receta_id = $1
       ORDER BY calculado_at DESC
       LIMIT 1`, [recetaId]);
        return {
            ...cabecera,
            items,
            costo,
        };
    }
    actualizarSubreceta(recetaId, dto) {
        return this.database.enTransaccion(async (client) => {
            const existe = await client.query(`SELECT id FROM recetas
         WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`, [recetaId, dto.sucursal_id]);
            if (!existe.rows[0]) {
                throw new common_1.NotFoundException('SUBRECETA_NO_ENCONTRADA');
            }
            await client.query(`UPDATE recetas
         SET nombre = $1, margen_error = $2,
             cantidad_resultado = $3, unidad_resultado = $4
         WHERE id = $5`, [
                dto.nombre,
                dto.margen_error ?? 0.05,
                dto.cantidad_resultado,
                dto.unidad_resultado,
                recetaId,
            ]);
            await client.query(`DELETE FROM receta_items WHERE receta_id = $1`, [
                recetaId,
            ]);
            await this.insertarItemsSubreceta(client, recetaId, dto.sucursal_id, dto.items, recetaId);
            const desglose = await this.calcularReceta(client, recetaId, dto.sucursal_id);
            await this.persistirCostoReceta(client, dto.sucursal_id, desglose, null);
            await this.recalcularProductosQueUsanSubreceta(client, recetaId, dto.sucursal_id);
            return {
                receta_id: recetaId,
                costo_por_unidad: desglose.costo_por_porcion,
                desglose,
            };
        });
    }
    recalcularSubrecetaPorId(recetaId, sucursalId) {
        return this.database.enTransaccion(async (client) => {
            const existe = await client.query(`SELECT id FROM recetas
         WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`, [recetaId, sucursalId]);
            if (!existe.rows[0]) {
                throw new common_1.NotFoundException('SUBRECETA_NO_ENCONTRADA');
            }
            const desglose = await this.calcularReceta(client, recetaId, sucursalId);
            await this.persistirCostoReceta(client, sucursalId, desglose, null);
            await this.recalcularProductosQueUsanSubreceta(client, recetaId, sucursalId);
            return {
                receta_id: recetaId,
                costo_por_unidad: desglose.costo_por_porcion,
                desglose,
            };
        });
    }
    async recalcularProductosQueUsanSubreceta(client, subrecetaId, sucursalId) {
        const productos = await client.query(`SELECT DISTINCT p.id AS producto_id
       FROM productos p
       JOIN receta_items ri ON ri.receta_id = p.receta_id
       WHERE p.sucursal_id = $1
         AND ri.tipo_item = 'subreceta'
         AND ri.subreceta_id = $2`, [sucursalId, subrecetaId]);
        for (const row of productos.rows) {
            await this.recalcularProducto(client, row.producto_id, sucursalId);
        }
    }
    async expandirReceta(client, recetaId, sucursalId, factor, incluirEmpaques, visitados, acumulador) {
        if (visitados.has(recetaId))
            return;
        visitados.add(recetaId);
        const receta = await this.consultarReceta(client, recetaId, sucursalId);
        const items = await client.query(`SELECT tipo_item, ingrediente_id, subreceta_id, cantidad::float AS cantidad
       FROM receta_items WHERE receta_id = $1`, [recetaId]);
        for (const item of items.rows) {
            const cantidad = Number(item.cantidad) * factor;
            if (item.tipo_item === 'empaque' && !incluirEmpaques)
                continue;
            if ((item.tipo_item === 'ingrediente' || item.tipo_item === 'empaque') &&
                item.ingrediente_id) {
                const prev = acumulador.get(item.ingrediente_id) ?? 0;
                acumulador.set(item.ingrediente_id, prev + cantidad);
            }
            else if (item.tipo_item === 'subreceta' && item.subreceta_id) {
                const sub = await this.consultarReceta(client, item.subreceta_id, sucursalId);
                const cantidadResultado = Math.max(Number(sub.cantidad_resultado ?? 1), 0.001);
                const factorSub = cantidad / cantidadResultado;
                await this.expandirReceta(client, item.subreceta_id, sucursalId, factorSub, false, visitados, acumulador);
            }
        }
        if (receta.tipo === 'producto' && receta.rendimiento_porciones > 1) {
        }
    }
    async costoUnitarioSubreceta(client, subrecetaId, sucursalId, visitados) {
        const d = await this.calcularReceta(client, subrecetaId, sucursalId, visitados);
        return d.costo_por_porcion;
    }
    async costoLineaIngrediente(client, ingredienteId, sucursalId, cantidad, unidadLinea) {
        const ing = await client.query(`SELECT costo_unitario_actual, rendimiento_porcentaje, unidad_base,
              peso_bruto, peso_neto
       FROM ingredientes
       WHERE id = $1 AND sucursal_id = $2 AND activo = true`, [ingredienteId, sucursalId]);
        const fila = ing.rows[0];
        if (!fila)
            throw new common_1.NotFoundException('INGREDIENTE_NO_ENCONTRADO');
        const unidadBase = fila.unidad_base ?? 'g';
        if (unidadLinea) {
            (0, unidad_costeo_util_1.exigirUnidadesCompatibles)(unidadLinea, unidadBase, 'Línea de receta');
        }
        const cantidadBase = unidadLinea
            ? (0, unidad_costeo_util_1.convertirCantidad)(cantidad, unidadLinea, unidadBase)
            : cantidad;
        const costoBase = Number(fila.costo_unitario_actual ?? 0);
        const modoMercado = fila.peso_neto != null && Number(fila.peso_neto) > 0;
        let costoRealUnit;
        let mermaExtra;
        if (modoMercado) {
            costoRealUnit = costoBase;
            const bruto = Number(fila.peso_bruto ?? 0);
            const neto = Number(fila.peso_neto ?? 1);
            const costoBrutoUnit = bruto > 0 ? costoBase * (neto / bruto) : costoBase;
            mermaExtra = Math.max(0, (costoRealUnit - costoBrutoUnit) * cantidadBase);
        }
        else {
            const rend = Number(fila.rendimiento_porcentaje ?? 100);
            costoRealUnit = this.costoRealUnitario(costoBase, rend);
            const sinMerma = costoBase * cantidadBase;
            const conMerma = costoRealUnit * cantidadBase;
            mermaExtra = Math.max(0, conMerma - sinMerma);
        }
        return {
            costoReal: costoRealUnit * cantidadBase,
            mermaExtra,
        };
    }
    async insertarItemsSubreceta(client, recetaId, sucursalId, items, excluirSubrecetaId) {
        let orden = 0;
        for (const item of items) {
            const tipo = item.tipo_item ?? 'ingrediente';
            if (tipo === 'subreceta') {
                if (!item.subreceta_id) {
                    throw new common_1.BadRequestException('SUBRECETA_REQUERIDA');
                }
                if (item.subreceta_id === excluirSubrecetaId) {
                    throw new common_1.BadRequestException('SUBRECETA_CIRCULAR');
                }
                await this.cantidadEnUnidadSubreceta(client, item.subreceta_id, sucursalId, item.cantidad, item.unidad);
                await client.query(`INSERT INTO receta_items (
             receta_id, tipo_item, subreceta_id, cantidad, unidad, orden
           ) VALUES ($1,'subreceta',$2,$3,$4,$5)`, [
                    recetaId,
                    item.subreceta_id,
                    item.cantidad,
                    item.unidad,
                    orden++,
                ]);
            }
            else {
                if (!item.ingrediente_id) {
                    throw new common_1.BadRequestException('INGREDIENTE_REQUERIDO');
                }
                const ing = await client.query(`SELECT unidad_base FROM ingredientes
           WHERE id = $1 AND sucursal_id = $2 AND activo = true`, [item.ingrediente_id, sucursalId]);
                if (!ing.rows[0]) {
                    throw new common_1.NotFoundException('INGREDIENTE_NO_ENCONTRADO');
                }
                (0, unidad_costeo_util_1.exigirUnidadesCompatibles)(item.unidad, ing.rows[0].unidad_base, 'Línea de subreceta');
                await client.query(`INSERT INTO receta_items (
             receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden
           ) VALUES ($1,'ingrediente',$2,$3,$4,$5)`, [
                    recetaId,
                    item.ingrediente_id,
                    item.cantidad,
                    item.unidad,
                    orden++,
                ]);
            }
        }
    }
    async cantidadEnUnidadSubreceta(client, subrecetaId, sucursalId, cantidad, unidadLinea) {
        const sr = await client.query(`SELECT unidad_resultado FROM recetas
       WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`, [subrecetaId, sucursalId]);
        if (!sr.rows[0])
            throw new common_1.NotFoundException('SUBRECETA_NO_ENCONTRADA');
        const unidadRes = sr.rows[0].unidad_resultado ?? 'g';
        (0, unidad_costeo_util_1.exigirUnidadesCompatibles)(unidadLinea, unidadRes, 'Línea de subreceta');
        return (0, unidad_costeo_util_1.convertirCantidad)(cantidad, unidadLinea, unidadRes);
    }
    async consultarReceta(client, recetaId, sucursalId) {
        const r = await client.query(`SELECT id, COALESCE(tipo, 'producto') AS tipo,
              margen_error, rendimiento_porciones, cantidad_resultado
       FROM recetas WHERE id = $1 AND sucursal_id = $2`, [recetaId, sucursalId]);
        if (!r.rows[0])
            throw new common_1.NotFoundException('RECETA_NO_ENCONTRADA');
        return r.rows[0];
    }
    async margenObjetivoProducto(client, productoId, sucursalId) {
        const p = await client.query(`SELECT COALESCE(p.margen_objetivo, s.margen_objetivo_default, 35)::float AS margen
       FROM productos p
       JOIN sucursales s ON s.id = p.sucursal_id
       WHERE p.id = $1 AND p.sucursal_id = $2`, [productoId, sucursalId]);
        return Number(p.rows[0]?.margen ?? 35);
    }
    async umbralMargenSucursal(client, sucursalId) {
        const r = await client.query(`SELECT COALESCE(umbral_alerta_margen, 35)::float AS umbral
       FROM sucursales WHERE id = $1`, [sucursalId]);
        return Number(r.rows[0]?.umbral ?? 25);
    }
    umbralMargenSucursalDesdeDb(sucursalId) {
        return this.database.enTransaccion(async (client) => this.umbralMargenSucursal(client, sucursalId));
    }
    async sumarCostosItemsIncluidos(client, productoId, sucursalId, recalculando) {
        const filas = await client.query(`SELECT producto_incluido_id, cantidad::float AS cantidad
       FROM producto_items_incluidos
       WHERE producto_id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
        let base = 0;
        let domicilio = 0;
        for (const fila of filas.rows) {
            const unit = await this.obtenerCostoUnitarioIncluido(client, fila.producto_incluido_id, sucursalId, recalculando);
            const cant = Number(fila.cantidad);
            base += unit.base * cant;
            domicilio += unit.domicilio * cant;
        }
        return { base, domicilio };
    }
    async obtenerCostoUnitarioIncluido(client, productoIncluidoId, sucursalId, recalculando) {
        if (recalculando.has(productoIncluidoId)) {
            throw new common_1.BadRequestException('INCLUIDOS_CIRCULAR');
        }
        let prod = await client.query(`SELECT costo_calculado, costo_domicilio FROM productos
       WHERE id = $1 AND sucursal_id = $2`, [productoIncluidoId, sucursalId]);
        if (!prod.rows[0]) {
            throw new common_1.NotFoundException('PRODUCTO_INCLUIDO_NO_ENCONTRADO');
        }
        if (!recalculando.has(productoIncluidoId)) {
            recalculando.add(productoIncluidoId);
            try {
                await this.recalcularProducto(client, productoIncluidoId, sucursalId, recalculando, false);
            }
            finally {
                recalculando.delete(productoIncluidoId);
            }
            prod = await client.query(`SELECT costo_calculado, costo_domicilio FROM productos
         WHERE id = $1 AND sucursal_id = $2`, [productoIncluidoId, sucursalId]);
        }
        const base = Number(prod.rows[0]?.costo_calculado ?? 0);
        const domicilio = Number(prod.rows[0]?.costo_domicilio ?? prod.rows[0]?.costo_calculado ?? 0);
        return { base, domicilio };
    }
    async recalcularProductosPadre(client, productoIncluidoId, sucursalId, recalculando) {
        const padres = await client.query(`SELECT producto_id FROM producto_items_incluidos
       WHERE producto_incluido_id = $1 AND sucursal_id = $2`, [productoIncluidoId, sucursalId]);
        for (const p of padres.rows) {
            if (recalculando.has(p.producto_id))
                continue;
            await this.recalcularProducto(client, p.producto_id, sucursalId, recalculando, false);
        }
    }
    async evaluarAlertaMargenProducto(client, productoId, sucursalId, precio, costo) {
        if (precio <= 0)
            return;
        const margenPct = ((precio - costo) / precio) * 100;
        const umbral = await this.umbralMargenSucursal(client, sucursalId);
        if (margenPct < umbral) {
            await this.alertasRiesgo.registrarEnTransaccion(client, {
                sucursalId,
                tipo: 'producto_margen_bajo',
                nivel: 'medio',
                descripcion: `Producto con margen ${margenPct.toFixed(1)}% (umbral ${umbral}%)`,
                referenciaId: productoId,
                referenciaTipo: 'producto',
                deduplicar: true,
            });
        }
    }
};
exports.CosteoService = CosteoService;
exports.CosteoService = CosteoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        alertas_riesgo_service_1.AlertasRiesgoService])
], CosteoService);
//# sourceMappingURL=costeo.service.js.map