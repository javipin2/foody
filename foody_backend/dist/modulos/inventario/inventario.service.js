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
exports.InventarioService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const costeo_service_1 = require("../costeo/costeo.service");
const catalogo_disponibilidad_service_1 = require("../catalogo/catalogo-disponibilidad.service");
const unidad_costeo_util_1 = require("../costeo/unidad-costeo.util");
const insumo_mercado_util_1 = require("./insumo-mercado.util");
let InventarioService = class InventarioService {
    database;
    alertasRiesgo;
    costeo;
    catalogoDisponibilidad;
    constructor(database, alertasRiesgo, costeo, catalogoDisponibilidad) {
        this.database = database;
        this.alertasRiesgo = alertasRiesgo;
        this.costeo = costeo;
        this.catalogoDisponibilidad = catalogoDisponibilidad;
    }
    async resumenInventarioHermanas(restauranteId, sucursalPropiaId) {
        const sucursales = await this.database.consultar(`SELECT id, nombre FROM sucursales
       WHERE restaurante_id = $1 AND activa = true
       ORDER BY nombre ASC`, [restauranteId]);
        const resultado = [];
        for (const suc of sucursales) {
            const stats = await this.database.consultarUno(`SELECT COUNT(*)::text AS total,
                COUNT(*) FILTER (
                  WHERE descontar_stock = true
                    AND stock_actual > 0
                    AND stock_actual <= stock_minimo
                )::text AS bajo,
                COUNT(*) FILTER (
                  WHERE descontar_stock = true AND stock_actual <= 0
                )::text AS agotados
         FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true`, [suc.id]);
            const ingredientes = await this.database.consultar(`SELECT id, nombre, stock_actual, stock_minimo, unidad_base,
                (stock_actual <= stock_minimo) AS bajo_minimo
         FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true
           AND descontar_stock = true
           AND (stock_actual <= stock_minimo)
         ORDER BY stock_actual ASC, nombre ASC
         LIMIT 12`, [suc.id]);
            resultado.push({
                sucursal_id: suc.id,
                nombre: suc.nombre,
                es_propia: suc.id === sucursalPropiaId,
                solo_lectura: suc.id !== sucursalPropiaId,
                total_insumos: Number(stats?.total ?? 0),
                bajo_stock: Number(stats?.bajo ?? 0),
                agotados: Number(stats?.agotados ?? 0),
                alertas: ingredientes.map((ing) => ({
                    id: ing.id,
                    nombre: ing.nombre,
                    stock_actual: Number(ing.stock_actual),
                    stock_minimo: Number(ing.stock_minimo),
                    unidad_base: ing.unidad_base,
                    bajo_minimo: ing.bajo_minimo,
                })),
            });
        }
        return {
            sucursal_propia: sucursalPropiaId,
            puede_ver_hermanas: true,
            sucursales: resultado,
        };
    }
    async listarIngredientes(sucursalId) {
        const filas = await this.database.consultar(`SELECT id, nombre, unidad_base, tipo_costeo, stock_actual, stock_minimo,
              costo_unitario_actual, descontar_stock, activo, created_at,
              proveedor, precio_compra, peso_bruto, peso_neto, categoria_insumo,
              rendimiento_porcentaje,
              (stock_actual <= stock_minimo) AS bajo_minimo
       FROM ingredientes
       WHERE sucursal_id = $1 AND activo = true
       ORDER BY nombre ASC`, [sucursalId]);
        return filas.map((f) => (0, insumo_mercado_util_1.enriquecerInsumoRespuesta)(f));
    }
    async crearIngrediente(dto) {
        const unidad = dto.unidad_base;
        const tipoCosteo = dto.tipo_costeo ?? (0, insumo_mercado_util_1.tipoCosteoDesdeUnidad)(unidad);
        const descontarStock = dto.descontar_stock ?? unidad !== 'servicio';
        const categoria = dto.categoria_insumo ??
            (descontarStock ? 'alimento' : 'mano_obra');
        let costoUnitario = dto.costo_unitario_actual ?? 0;
        let rendimiento = 100;
        let precioCompra = dto.precio_compra ?? null;
        let pesoBruto = dto.peso_bruto ?? null;
        let pesoNeto = dto.peso_neto ?? null;
        const modoMercado = dto.precio_compra != null &&
            dto.peso_bruto != null &&
            dto.peso_neto != null &&
            dto.peso_neto > 0;
        if (modoMercado) {
            const derivado = (0, insumo_mercado_util_1.derivarCostoDesdeMercado)({
                precio_compra: dto.precio_compra,
                peso_bruto: dto.peso_bruto,
                peso_neto: dto.peso_neto,
                unidad_base: unidad,
            });
            costoUnitario = derivado.costo_unitario_actual;
            rendimiento = derivado.rendimiento_porcentaje;
        }
        else if (!descontarStock && dto.costo_unitario_actual != null) {
            costoUnitario = dto.costo_unitario_actual;
            precioCompra = null;
            pesoBruto = null;
            pesoNeto = null;
        }
        const fila = await this.database.consultarUno(`INSERT INTO ingredientes (
         sucursal_id, nombre, unidad_base, tipo_costeo,
         stock_actual, stock_minimo, costo_unitario_actual, descontar_stock,
         proveedor, precio_compra, peso_bruto, peso_neto, categoria_insumo,
         rendimiento_porcentaje
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       RETURNING id, nombre, unidad_base, stock_actual, stock_minimo,
                 costo_unitario_actual, descontar_stock, proveedor,
                 precio_compra, peso_bruto, peso_neto, categoria_insumo,
                 rendimiento_porcentaje`, [
            dto.sucursal_id,
            dto.nombre,
            unidad,
            tipoCosteo,
            dto.stock_actual ?? 0,
            dto.stock_minimo ?? 0,
            costoUnitario,
            descontarStock,
            dto.proveedor ?? null,
            precioCompra,
            pesoBruto,
            pesoNeto,
            categoria,
            rendimiento,
        ]);
        if (!fila) {
            throw new common_1.NotFoundException('INGREDIENTE_NO_CREADO');
        }
        if (costoUnitario > 0) {
            await this.costeo.recalcularSucursal(dto.sucursal_id);
        }
        return (0, insumo_mercado_util_1.enriquecerInsumoRespuesta)(fila);
    }
    async actualizarIngrediente(id, sucursalId, usuarioId, dto) {
        let recalcularCostos = false;
        let stockCambio = false;
        const result = await this.database.enTransaccion(async (client) => {
            const actual = await this.exigirIngrediente(client, id, sucursalId);
            if (dto.stock_nuevo !== undefined) {
                const nuevo = dto.stock_nuevo;
                const anterior = Number(actual.stock_actual);
                if (nuevo !== anterior) {
                    await client.query(`INSERT INTO movimientos_ingrediente (
               sucursal_id, ingrediente_id, tipo, cantidad,
               stock_anterior, stock_posterior, motivo, usuario_id
             ) VALUES ($1,$2,'ajuste',$3,$4,$5,$6,$7)`, [
                        sucursalId,
                        id,
                        Math.abs(nuevo - anterior),
                        anterior,
                        nuevo,
                        dto.motivo_ajuste ?? 'Ajuste manual',
                        usuarioId,
                    ]);
                    await client.query(`UPDATE ingredientes SET stock_actual = $1 WHERE id = $2 AND sucursal_id = $3`, [nuevo, id, sucursalId]);
                    stockCambio = true;
                }
            }
            const campos = [];
            const valores = [];
            let i = 1;
            const setCampo = (col, val) => {
                campos.push(`${col} = $${i++}`);
                valores.push(val);
            };
            if (dto.nombre !== undefined)
                setCampo('nombre', dto.nombre);
            if (dto.proveedor !== undefined)
                setCampo('proveedor', dto.proveedor);
            if (dto.categoria_insumo !== undefined) {
                setCampo('categoria_insumo', dto.categoria_insumo);
            }
            if (dto.unidad_base !== undefined) {
                setCampo('unidad_base', dto.unidad_base);
                setCampo('tipo_costeo', (0, insumo_mercado_util_1.tipoCosteoDesdeUnidad)(dto.unidad_base));
            }
            if (dto.descontar_stock !== undefined) {
                setCampo('descontar_stock', dto.descontar_stock);
            }
            if (dto.stock_minimo !== undefined) {
                setCampo('stock_minimo', dto.stock_minimo);
            }
            const precioCompra = dto.precio_compra ?? (actual.precio_compra != null ? Number(actual.precio_compra) : null);
            const pesoBruto = dto.peso_bruto ?? (actual.peso_bruto != null ? Number(actual.peso_bruto) : null);
            const pesoNeto = dto.peso_neto ?? (actual.peso_neto != null ? Number(actual.peso_neto) : null);
            const unidad = dto.unidad_base ?? actual.unidad_base;
            const tocóMercado = dto.precio_compra !== undefined ||
                dto.peso_bruto !== undefined ||
                dto.peso_neto !== undefined;
            if (tocóMercado) {
                if (precioCompra == null || pesoBruto == null || pesoNeto == null) {
                    throw new common_1.BadRequestException('DATOS_MERCADO_INCOMPLETOS');
                }
                const derivado = (0, insumo_mercado_util_1.derivarCostoDesdeMercado)({
                    precio_compra: precioCompra,
                    peso_bruto: pesoBruto,
                    peso_neto: pesoNeto,
                    unidad_base: unidad,
                });
                setCampo('precio_compra', precioCompra);
                setCampo('peso_bruto', pesoBruto);
                setCampo('peso_neto', pesoNeto);
                setCampo('costo_unitario_actual', derivado.costo_unitario_actual);
                setCampo('rendimiento_porcentaje', derivado.rendimiento_porcentaje);
                recalcularCostos = true;
            }
            else if (dto.costo_unitario_actual !== undefined) {
                setCampo('costo_unitario_actual', dto.costo_unitario_actual);
                recalcularCostos = true;
            }
            if (campos.length) {
                valores.push(id, sucursalId);
                await client.query(`UPDATE ingredientes SET ${campos.join(', ')}
           WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
            }
            const fila = await this.obtenerIngrediente(client, id, sucursalId);
            return { fila, stockCambio };
        });
        if (result.stockCambio) {
            const cambios = await this.catalogoDisponibilidad.sincronizarPorIngrediente(sucursalId, id);
            this.catalogoDisponibilidad.emitirCambios(sucursalId, cambios);
        }
        if (recalcularCostos) {
            await this.costeo.recalcularSucursal(sucursalId);
        }
        return (0, insumo_mercado_util_1.enriquecerInsumoRespuesta)(result.fila);
    }
    listarMovimientos(sucursalId, limite = 50) {
        return this.database.consultar(`SELECT m.id, m.ingrediente_id, i.nombre AS ingrediente_nombre,
              m.tipo, m.cantidad, m.stock_anterior, m.stock_posterior,
              m.motivo, m.pedido_id, m.created_at
       FROM movimientos_ingrediente m
       INNER JOIN ingredientes i ON i.id = m.ingrediente_id
       WHERE m.sucursal_id = $1
       ORDER BY m.created_at DESC
       LIMIT $2`, [sucursalId, limite]);
    }
    registrarCompra(dto, usuarioId) {
        return this.database.enTransaccion(async (client) => {
            let totalCompra = 0;
            for (const item of dto.items) {
                totalCompra += item.precio_total;
            }
            const compra = await client.query(`INSERT INTO compras_inventario (
           sucursal_id, usuario_id, proveedor, total_compra, observaciones
         ) VALUES ($1,$2,$3,$4,$5)
         RETURNING id`, [
                dto.sucursal_id,
                usuarioId,
                dto.proveedor ?? null,
                totalCompra,
                dto.observaciones ?? null,
            ]);
            const compraId = compra.rows[0].id;
            for (const item of dto.items) {
                const ing = await this.exigirIngrediente(client, item.ingrediente_id, dto.sucursal_id);
                const costoUnitario = item.cantidad_unidades_base > 0
                    ? item.precio_total / item.cantidad_unidades_base
                    : 0;
                const stockAnterior = Number(ing.stock_actual);
                const stockPosterior = stockAnterior + item.cantidad_unidades_base;
                const costoAnterior = Number(ing.costo_unitario_actual ?? 0);
                await client.query(`INSERT INTO compra_items (
             compra_id, ingrediente_id, cantidad_presentaciones,
             precio_presentacion, cantidad_unidades_base, costo_unitario_base
           ) VALUES ($1,$2,1,$3,$4,$5)`, [
                    compraId,
                    item.ingrediente_id,
                    item.precio_total,
                    item.cantidad_unidades_base,
                    costoUnitario,
                ]);
                await client.query(`UPDATE ingredientes
           SET stock_actual = $1, costo_unitario_actual = $2
           WHERE id = $3 AND sucursal_id = $4`, [stockPosterior, costoUnitario, item.ingrediente_id, dto.sucursal_id]);
                await client.query(`INSERT INTO movimientos_ingrediente (
             sucursal_id, ingrediente_id, tipo, cantidad,
             stock_anterior, stock_posterior, motivo, usuario_id
           ) VALUES ($1,$2,'compra',$3,$4,$5,$6,$7)`, [
                    dto.sucursal_id,
                    item.ingrediente_id,
                    item.cantidad_unidades_base,
                    stockAnterior,
                    stockPosterior,
                    `Compra ${compraId}`,
                    usuarioId,
                ]);
                await this.alertasRiesgo.evaluarSubidaCostoIngrediente(client, dto.sucursal_id, item.ingrediente_id, ing.nombre, costoAnterior, costoUnitario);
            }
            return { compra_id: compraId, total_compra: totalCompra };
        }).then(async (result) => {
            await this.costeo.recalcularSucursal(dto.sucursal_id);
            return result;
        });
    }
    async recetaDeProducto(productoId, sucursalId) {
        const producto = await this.database.consultarUno(`SELECT receta_id, costo_calculado FROM productos
       WHERE id = $1 AND sucursal_id = $2`, [productoId, sucursalId]);
        if (!producto)
            throw new common_1.NotFoundException('PRODUCTO_NO_ENCONTRADO');
        if (!producto.receta_id) {
            return {
                producto_id: productoId,
                receta_id: null,
                items: [],
                margen_error: 0.05,
                costo_calculado: producto.costo_calculado,
            };
        }
        const receta = await this.database.consultarUno(`SELECT margen_error FROM recetas WHERE id = $1 AND sucursal_id = $2`, [producto.receta_id, sucursalId]);
        const items = await this.database.consultar(`SELECT ri.id, ri.tipo_item, ri.ingrediente_id, i.nombre AS ingrediente_nombre,
              ri.subreceta_id, sr.nombre AS subreceta_nombre,
              ri.cantidad, ri.unidad, ri.orden
       FROM receta_items ri
       LEFT JOIN ingredientes i ON i.id = ri.ingrediente_id
       LEFT JOIN recetas sr ON sr.id = ri.subreceta_id
       WHERE ri.receta_id = $1
       ORDER BY ri.orden ASC`, [producto.receta_id]);
        return {
            producto_id: productoId,
            receta_id: producto.receta_id,
            margen_error: Number(receta?.margen_error ?? 0.05),
            costo_calculado: producto.costo_calculado,
            items,
        };
    }
    configurarRecetaProducto(dto, sucursalId) {
        return this.database.enTransaccion(async (client) => {
            const producto = await client.query(`SELECT id, nombre, receta_id FROM productos
         WHERE id = $1 AND sucursal_id = $2`, [dto.producto_id, sucursalId]);
            if (!producto.rows[0]) {
                throw new common_1.NotFoundException('PRODUCTO_NO_ENCONTRADO');
            }
            const fila = producto.rows[0];
            let recetaId = fila.receta_id;
            if (!recetaId) {
                const nueva = await client.query(`INSERT INTO recetas (sucursal_id, nombre, tipo, rendimiento_porciones)
           VALUES ($1,$2,'producto',1)
           RETURNING id`, [sucursalId, `Receta ${fila.nombre}`]);
                recetaId = nueva.rows[0].id;
                await client.query(`UPDATE productos SET receta_id = $1 WHERE id = $2 AND sucursal_id = $3`, [recetaId, dto.producto_id, sucursalId]);
            }
            if (dto.margen_error !== undefined) {
                await client.query(`UPDATE recetas SET margen_error = $1, tipo = 'producto'
           WHERE id = $2 AND sucursal_id = $3`, [dto.margen_error, recetaId, sucursalId]);
            }
            await client.query(`DELETE FROM receta_items WHERE receta_id = $1`, [
                recetaId,
            ]);
            let orden = 0;
            for (const item of dto.items) {
                const tipo = item.tipo_item ?? 'ingrediente';
                if (tipo === 'subreceta') {
                    if (!item.subreceta_id) {
                        throw new common_1.BadRequestException('SUBRECETA_REQUERIDA');
                    }
                    const sr = await client.query(`SELECT unidad_resultado FROM recetas
             WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`, [item.subreceta_id, sucursalId]);
                    if (!sr.rows[0]) {
                        throw new common_1.NotFoundException('SUBRECETA_NO_ENCONTRADA');
                    }
                    (0, unidad_costeo_util_1.exigirUnidadesCompatibles)(item.unidad, sr.rows[0].unidad_resultado, `Receta de ${fila.nombre}`);
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
                    const ing = await this.exigirIngrediente(client, item.ingrediente_id, sucursalId);
                    (0, unidad_costeo_util_1.exigirUnidadesCompatibles)(item.unidad, ing.unidad_base, `Receta de ${fila.nombre}`);
                    await client.query(`INSERT INTO receta_items (
               receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden
             ) VALUES ($1,$2,$3,$4,$5,$6)`, [
                        recetaId,
                        tipo,
                        item.ingrediente_id,
                        item.cantidad,
                        item.unidad,
                        orden++,
                    ]);
                }
            }
            const costoPorcion = await this.costeo.recalcularProducto(client, dto.producto_id, sucursalId);
            return {
                producto_id: dto.producto_id,
                receta_id: recetaId,
                costo_calculado: costoPorcion,
                items: dto.items.length,
            };
        });
    }
    async iniciarConteo(sucursalId, usuarioId) {
        const activo = await this.database.consultarUno(`SELECT id FROM conteos_inventario
       WHERE sucursal_id = $1 AND estado = 'en_proceso'
       LIMIT 1`, [sucursalId]);
        if (activo) {
            return { conteo_id: activo.id, reutilizado: true };
        }
        const fila = await this.database.consultarUno(`INSERT INTO conteos_inventario (sucursal_id, usuario_id, estado)
       VALUES ($1,$2,'en_proceso')
       RETURNING id`, [sucursalId, usuarioId]);
        return { conteo_id: fila.id, reutilizado: false };
    }
    cerrarConteo(conteoId, sucursalId, usuarioId, dto) {
        return this.database.enTransaccion(async (client) => {
            const conteo = await client.query(`SELECT id, estado FROM conteos_inventario
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [conteoId, sucursalId]);
            if (!conteo.rows[0]) {
                throw new common_1.NotFoundException('CONTEO_NO_ENCONTRADO');
            }
            if (conteo.rows[0].estado !== 'en_proceso') {
                throw new common_1.BadRequestException('El conteo ya fue cerrado');
            }
            let ajustes = 0;
            for (const item of dto.items) {
                const ing = await this.exigirIngrediente(client, item.ingrediente_id, sucursalId);
                const teorico = Number(ing.stock_actual);
                const real = item.cantidad_real;
                const diferencia = real - teorico;
                await client.query(`INSERT INTO conteo_items (
             conteo_id, ingrediente_id, cantidad_teorica, cantidad_real
           ) VALUES ($1,$2,$3,$4)`, [conteoId, item.ingrediente_id, teorico, real]);
                if (diferencia !== 0) {
                    await client.query(`UPDATE ingredientes SET stock_actual = $1
             WHERE id = $2 AND sucursal_id = $3`, [real, item.ingrediente_id, sucursalId]);
                    await client.query(`INSERT INTO movimientos_ingrediente (
               sucursal_id, ingrediente_id, tipo, cantidad,
               stock_anterior, stock_posterior, motivo, usuario_id
             ) VALUES ($1,$2,'conteo',$3,$4,$5,$6,$7)`, [
                        sucursalId,
                        item.ingrediente_id,
                        Math.abs(diferencia),
                        teorico,
                        real,
                        `Conteo físico ${conteoId}`,
                        usuarioId,
                    ]);
                    ajustes++;
                }
            }
            await client.query(`UPDATE conteos_inventario
         SET estado = 'cerrado', cerrado_at = now()
         WHERE id = $1`, [conteoId]);
            return { conteo_id: conteoId, items: dto.items.length, ajustes };
        });
    }
    listarCostosProductos(sucursalId) {
        return this.costeo.resumenSucursal(sucursalId).then((r) => r.productos);
    }
    listarTraslados(restauranteId, sucursalId) {
        const params = [restauranteId];
        let filtroSucursal = '';
        if (sucursalId) {
            filtroSucursal =
                ' AND (t.sucursal_origen_id = $2 OR t.sucursal_destino_id = $2)';
            params.push(sucursalId);
        }
        return this.database.consultar(`       SELECT t.id, t.estado, t.cantidad, t.motivo, t.created_at, t.recibido_at,
              t.sucursal_origen_id, t.sucursal_destino_id,
              io.nombre AS ingrediente_nombre, io.unidad_base,
              so.nombre AS sucursal_origen, sd.nombre AS sucursal_destino,
              u.nombre AS usuario_nombre
       FROM traslados_inventario t
       INNER JOIN ingredientes io ON io.id = t.ingrediente_id
       INNER JOIN sucursales so ON so.id = t.sucursal_origen_id
       INNER JOIN sucursales sd ON sd.id = t.sucursal_destino_id
       LEFT JOIN usuarios u ON u.id = t.usuario_id
       WHERE t.restaurante_id = $1${filtroSucursal}
       ORDER BY t.created_at DESC
       LIMIT 100`, params);
    }
    crearTraslado(restauranteId, usuarioId, dto) {
        if (dto.sucursal_origen_id === dto.sucursal_destino_id) {
            throw new common_1.BadRequestException('ORIGEN_IGUAL_DESTINO');
        }
        return this.database.enTransaccion(async (client) => {
            const sucursales = await client.query(`SELECT id FROM sucursales
         WHERE restaurante_id = $1 AND activa = true
           AND id = ANY($2::uuid[])`, [restauranteId, [dto.sucursal_origen_id, dto.sucursal_destino_id]]);
            if (sucursales.rows.length < 2) {
                throw new common_1.BadRequestException('SUCURSALES_INVALIDAS');
            }
            const origen = await this.exigirIngrediente(client, dto.ingrediente_id, dto.sucursal_origen_id);
            const stockAnterior = Number(origen.stock_actual);
            if (stockAnterior < dto.cantidad) {
                throw new common_1.BadRequestException('STOCK_INSUFICIENTE_TRASLADO');
            }
            const stockPosterior = stockAnterior - dto.cantidad;
            const destinoIng = await client.query(`SELECT id FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true
           AND LOWER(nombre) = LOWER($2)
         LIMIT 1`, [dto.sucursal_destino_id, origen.nombre]);
            if (!destinoIng.rows[0]) {
                throw new common_1.BadRequestException({
                    error: 'INGREDIENTE_DESTINO_NO_ENCONTRADO',
                    message: `No existe «${origen.nombre}» en la sucursal destino`,
                });
            }
            await client.query(`UPDATE ingredientes SET stock_actual = $1
         WHERE id = $2 AND sucursal_id = $3`, [stockPosterior, dto.ingrediente_id, dto.sucursal_origen_id]);
            await client.query(`INSERT INTO movimientos_ingrediente (
           sucursal_id, ingrediente_id, tipo, cantidad,
           stock_anterior, stock_posterior, motivo, usuario_id
         ) VALUES ($1,$2,'ajuste',$3,$4,$5,$6,$7)`, [
                dto.sucursal_origen_id,
                dto.ingrediente_id,
                dto.cantidad,
                stockAnterior,
                stockPosterior,
                `Traslado saliente → ${dto.sucursal_destino_id}`,
                usuarioId,
            ]);
            const traslado = await client.query(`INSERT INTO traslados_inventario (
           restaurante_id, sucursal_origen_id, sucursal_destino_id,
           ingrediente_id, cantidad, usuario_id, motivo
         ) VALUES ($1,$2,$3,$4,$5,$6,$7)
         RETURNING id`, [
                restauranteId,
                dto.sucursal_origen_id,
                dto.sucursal_destino_id,
                dto.ingrediente_id,
                dto.cantidad,
                usuarioId,
                dto.motivo ?? null,
            ]);
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues
         ) VALUES ($1,$2,'CREAR_TRASLADO','traslados_inventario',$3,$4::jsonb)`, [
                dto.sucursal_origen_id,
                usuarioId,
                traslado.rows[0].id,
                JSON.stringify({
                    destino: dto.sucursal_destino_id,
                    ingrediente: origen.nombre,
                    cantidad: dto.cantidad,
                }),
            ]);
            return {
                traslado_id: traslado.rows[0].id,
                ingrediente_destino_id: destinoIng.rows[0].id,
                estado: 'pendiente',
            };
        });
    }
    recibirTraslado(trasladoId, restauranteId, sucursalDestinoId, usuarioId) {
        return this.database.enTransaccion(async (client) => {
            const t = await client.query(`SELECT t.id, t.estado, t.cantidad, t.ingrediente_id, t.sucursal_destino_id,
                i.nombre
         FROM traslados_inventario t
         INNER JOIN ingredientes i ON i.id = t.ingrediente_id
         WHERE t.id = $1 AND t.restaurante_id = $2 FOR UPDATE`, [trasladoId, restauranteId]);
            const fila = t.rows[0];
            if (!fila)
                throw new common_1.NotFoundException('TRASLADO_NO_ENCONTRADO');
            if (fila.sucursal_destino_id !== sucursalDestinoId) {
                throw new common_1.BadRequestException('TRASLADO_OTRA_SUCURSAL');
            }
            if (fila.estado !== 'pendiente') {
                throw new common_1.BadRequestException('TRASLADO_YA_CERRADO');
            }
            const destinoIng = await client.query(`SELECT id, stock_actual FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true
           AND LOWER(nombre) = LOWER($2)
         LIMIT 1`, [sucursalDestinoId, fila.nombre]);
            if (!destinoIng.rows[0]) {
                throw new common_1.BadRequestException('INGREDIENTE_DESTINO_NO_ENCONTRADO');
            }
            const cantidad = Number(fila.cantidad);
            const stockAnterior = Number(destinoIng.rows[0].stock_actual);
            const stockPosterior = stockAnterior + cantidad;
            await client.query(`UPDATE ingredientes SET stock_actual = $1 WHERE id = $2`, [stockPosterior, destinoIng.rows[0].id]);
            await client.query(`INSERT INTO movimientos_ingrediente (
           sucursal_id, ingrediente_id, tipo, cantidad,
           stock_anterior, stock_posterior, motivo, usuario_id
         ) VALUES ($1,$2,'compra',$3,$4,$5,$6,$7)`, [
                sucursalDestinoId,
                destinoIng.rows[0].id,
                cantidad,
                stockAnterior,
                stockPosterior,
                `Traslado recibido ${trasladoId}`,
                usuarioId,
            ]);
            await client.query(`UPDATE traslados_inventario
         SET estado = 'recibido', recibido_at = now()
         WHERE id = $1`, [trasladoId]);
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id
         ) VALUES ($1,$2,'RECIBIR_TRASLADO','traslados_inventario',$3)`, [sucursalDestinoId, usuarioId, trasladoId]);
            return { traslado_id: trasladoId, estado: 'recibido' };
        });
    }
    async exigirIngrediente(client, id, sucursalId) {
        const fila = await client.query(`SELECT id, nombre, stock_actual, stock_minimo, costo_unitario_actual,
              unidad_base, precio_compra, peso_bruto, peso_neto
       FROM ingredientes
       WHERE id = $1 AND sucursal_id = $2 AND activo = true`, [id, sucursalId]);
        if (!fila.rows[0]) {
            throw new common_1.NotFoundException('INGREDIENTE_NO_ENCONTRADO');
        }
        return fila.rows[0];
    }
    async exigirSubreceta(client, id, sucursalId) {
        const fila = await client.query(`SELECT id FROM recetas
       WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`, [id, sucursalId]);
        if (!fila.rows[0]) {
            throw new common_1.NotFoundException('SUBRECETA_NO_ENCONTRADA');
        }
        return fila.rows[0];
    }
    async obtenerIngrediente(client, id, sucursalId) {
        const fila = await client.query(`SELECT id, nombre, unidad_base, stock_actual, stock_minimo,
              costo_unitario_actual, descontar_stock, proveedor,
              precio_compra, peso_bruto, peso_neto, categoria_insumo,
              rendimiento_porcentaje
       FROM ingredientes WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!fila.rows[0]) {
            throw new common_1.NotFoundException('INGREDIENTE_NO_ENCONTRADO');
        }
        return fila.rows[0];
    }
};
exports.InventarioService = InventarioService;
exports.InventarioService = InventarioService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        costeo_service_1.CosteoService,
        catalogo_disponibilidad_service_1.CatalogoDisponibilidadService])
], InventarioService);
//# sourceMappingURL=inventario.service.js.map