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
exports.PedidosInventarioService = void 0;
const common_1 = require("@nestjs/common");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const catalogo_disponibilidad_service_1 = require("../catalogo/catalogo-disponibilidad.service");
const costeo_service_1 = require("../costeo/costeo.service");
const stock_movimiento_service_1 = require("../inventario/stock-movimiento.service");
let PedidosInventarioService = class PedidosInventarioService {
    costeo;
    catalogoDisponibilidad;
    stockMovimiento;
    alertas;
    constructor(costeo, catalogoDisponibilidad, stockMovimiento, alertas) {
        this.costeo = costeo;
        this.catalogoDisponibilidad = catalogoDisponibilidad;
        this.stockMovimiento = stockMovimiento;
        this.alertas = alertas;
    }
    async validarStockDisponible(client, sucursalId, lineas, opciones = {}, contextoAlerta) {
        const faltas = await this.detectarFaltasStock(client, sucursalId, lineas, opciones);
        if (faltas.length > 0) {
            if (contextoAlerta) {
                await this.registrarAlertasIntentoPedido(client, sucursalId, lineas, faltas, opciones, contextoAlerta);
            }
            this.lanzarStockInsuficiente(faltas);
        }
    }
    async registrarAlertasIntentoPedido(client, sucursalId, lineas, faltasAgregadas, opciones, contexto) {
        if (!this.alertas)
            return;
        const incluirEmpaques = opciones.incluirEmpaques ?? false;
        const idsFaltantes = new Set(faltasAgregadas.map((f) => f.ingrediente_id));
        for (const linea of lineas) {
            const faltasLinea = await this.detectarFaltasStock(client, sucursalId, [linea], opciones);
            if (faltasLinea.length === 0)
                continue;
            const nombreProducto = linea.nombreProducto ??
                (await this.nombreProducto(client, linea.productoId));
            for (const falta of faltasLinea) {
                if (!idsFaltantes.has(falta.ingrediente_id))
                    continue;
                const origenTxt = this.textoOrigenPedido(contexto);
                const detalleVia = await this.explicarFaltaEnProducto(client, sucursalId, linea.productoId, linea.cantidad, falta, incluirEmpaques);
                const descripcion = `Un cliente intentó pedir ${linea.cantidad}× ${nombreProducto}${origenTxt}, ` +
                    `pero no hay stock de ${falta.nombre} ` +
                    `(necesita ${this.fmtCantidad(falta.necesita)} ${falta.unidad}, hay ${this.fmtCantidad(falta.disponible)}). ` +
                    detalleVia;
                await this.alertas.registrar({
                    sucursalId,
                    tipo: 'intento_pedido_sin_stock',
                    nivel: 'alto',
                    descripcion,
                    referenciaId: falta.ingrediente_id,
                    referenciaTipo: 'ingrediente',
                    deduplicar: true,
                });
            }
        }
    }
    textoOrigenPedido(ctx) {
        const partes = [];
        if (ctx.clienteNombre?.trim()) {
            partes.push(ctx.clienteNombre.trim());
        }
        if (ctx.mesaNombre?.trim()) {
            partes.push(`mesa ${ctx.mesaNombre.trim()}`);
        }
        else if (ctx.origen === 'domicilio') {
            partes.push('domicilio');
        }
        else if (ctx.origen === 'para_llevar') {
            partes.push('para llevar');
        }
        else if (ctx.origen === 'staff') {
            partes.push('pedido staff');
        }
        if (partes.length === 0)
            return '';
        return ` (${partes.join(', ')})`;
    }
    async explicarFaltaEnProducto(client, sucursalId, productoId, cantidadPedida, falta, incluirEmpaques) {
        const incluidos = await client.query(`SELECT pii.producto_incluido_id, pii.cantidad::float AS cantidad, pr.nombre
       FROM producto_items_incluidos pii
       INNER JOIN productos pr ON pr.id = pii.producto_incluido_id
       WHERE pii.producto_id = $1 AND pii.sucursal_id = $2`, [productoId, sucursalId]);
        const viasIncluidos = [];
        for (const inc of incluidos.rows) {
            const cantIncluidos = cantidadPedida * Number(inc.cantidad);
            const exp = await this.costeo.expandirIngredientesProducto(client, inc.producto_incluido_id, sucursalId, cantIncluidos, incluirEmpaques);
            const uso = exp.find((e) => e.ingrediente_id === falta.ingrediente_id);
            if (uso && uso.cantidad > 0) {
                viasIncluidos.push({
                    nombre: inc.nombre,
                    cantidadTotal: cantIncluidos,
                    necesita: uso.cantidad,
                });
            }
        }
        if (viasIncluidos.length > 0) {
            const lista = viasIncluidos
                .map((v) => `${this.fmtCantidad(v.cantidadTotal)}× ${v.nombre} ` +
                `(${this.fmtCantidad(v.necesita)} ${falta.unidad} de ${falta.nombre})`)
                .join(', ');
            return `El ${falta.nombre} se usa en los ítems incluidos: ${lista}.`;
        }
        const recetaDirecta = await this.costeo.expandirSoloRecetaProducto(client, productoId, sucursalId, cantidadPedida, incluirEmpaques);
        const enReceta = recetaDirecta.find((e) => e.ingrediente_id === falta.ingrediente_id);
        if (enReceta) {
            return `El ${falta.nombre} forma parte de la receta directa del plato.`;
        }
        return `Revisa la receta e ítems incluidos del plato en Costos y márgenes.`;
    }
    async nombreProducto(client, productoId) {
        const fila = await client.query(`SELECT nombre FROM productos WHERE id = $1`, [productoId]);
        return fila.rows[0]?.nombre ?? 'Producto';
    }
    fmtCantidad(n) {
        return Number.isInteger(n) ? String(n) : n.toFixed(1);
    }
    async expandirLineaCompleta(client, sucursalId, linea, incluirEmpaques) {
        const acumulador = new Map();
        const sumar = (items) => {
            for (const i of items) {
                acumulador.set(i.ingrediente_id, (acumulador.get(i.ingrediente_id) ?? 0) + i.cantidad);
            }
        };
        sumar(await this.costeo.expandirIngredientesProducto(client, linea.productoId, sucursalId, linea.cantidad, incluirEmpaques));
        for (const extra of linea.extras ?? []) {
            sumar(await this.costeo.expandirIngredientesExtra(client, extra.tipo, extra.id, sucursalId, extra.cantidad, incluirEmpaques));
        }
        return [...acumulador.entries()].map(([ingrediente_id, cantidad]) => ({
            ingrediente_id,
            cantidad,
        }));
    }
    async detectarFaltasStock(client, sucursalId, lineas, opciones = {}) {
        const incluirEmpaques = opciones.incluirEmpaques ?? false;
        const acumulado = new Map();
        for (const linea of lineas) {
            const expandidos = await this.expandirLineaCompleta(client, sucursalId, linea, incluirEmpaques);
            if (expandidos.length === 0)
                continue;
            const ingredientes = await this.cargarStockIngredientes(client, sucursalId, expandidos, { lanzarSiFaltaIngrediente: false });
            for (const ing of ingredientes) {
                if (!ing.descontar_stock)
                    continue;
                const prev = acumulado.get(ing.ingrediente_id);
                acumulado.set(ing.ingrediente_id, {
                    cantidad: (prev?.cantidad ?? 0) + ing.cantidad,
                    nombre: ing.nombre,
                    unidad: ing.unidad_base,
                });
            }
        }
        const faltas = [];
        const considerarQr = opciones.considerarReservaQrPendiente !== false;
        const comprometido = considerarQr
            ? await this.ingredientesComprometidosQrPendiente(client, sucursalId, opciones.excluirPedidoIdReservaQr)
            : new Map();
        for (const [ingredienteId, req] of acumulado) {
            const fila = await client.query(`SELECT stock_actual, descontar_stock FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 AND activo = true`, [ingredienteId, sucursalId]);
            const ing = fila.rows[0];
            if (!ing || ing.descontar_stock === false)
                continue;
            const disponible = Number(ing.stock_actual) - (comprometido.get(ingredienteId) ?? 0);
            if (disponible < req.cantidad) {
                faltas.push({
                    ingrediente_id: ingredienteId,
                    nombre: req.nombre,
                    necesita: req.cantidad,
                    disponible: Math.max(0, disponible),
                    unidad: req.unidad,
                });
            }
        }
        return faltas;
    }
    async ingredientesComprometidosQrPendiente(client, sucursalId, excluirPedidoId) {
        const params = [sucursalId];
        let excluirSql = '';
        if (excluirPedidoId) {
            params.push(excluirPedidoId);
            excluirSql = 'AND p.id <> $2';
        }
        const pendientes = await client.query(`SELECT p.id FROM pedidos p
       WHERE p.sucursal_id = $1
         AND p.estado = 'pendiente_aprobacion'
         AND p.stock_descontado = false
         ${excluirSql}`, params);
        const mapa = new Map();
        for (const row of pendientes.rows) {
            const lineas = await this.lineasDesdePedido(client, row.id, sucursalId);
            const acumulado = new Map();
            for (const linea of lineas) {
                const expandidos = await this.expandirLineaCompleta(client, sucursalId, linea, false);
                for (const ing of expandidos) {
                    acumulado.set(ing.ingrediente_id, (acumulado.get(ing.ingrediente_id) ?? 0) + ing.cantidad);
                }
            }
            for (const [id, cant] of acumulado) {
                mapa.set(id, (mapa.get(id) ?? 0) + cant);
            }
        }
        return mapa;
    }
    lanzarStockInsuficiente(faltas) {
        const resumen = faltas
            .map((f) => `${f.nombre}: necesitas ${f.necesita} ${f.unidad}, hay ${f.disponible}`)
            .join('; ');
        throw new common_1.BadRequestException({
            error: 'STOCK_INSUFICIENTE',
            message: resumen,
            detalles: faltas,
        });
    }
    async descontarStockPedido(client, sucursalId, pedidoId, lineas, opciones = {}) {
        const costosPorProducto = new Map();
        const catalogoPorProducto = new Map();
        const ingredientesTocados = new Set();
        const incluirEmpaques = opciones.incluirEmpaques ?? false;
        for (const linea of lineas) {
            const expandidos = await this.expandirLineaCompleta(client, sucursalId, linea, incluirEmpaques);
            if (expandidos.length === 0) {
                const costoProducto = await this.costoCalculadoProducto(client, linea.productoId);
                costosPorProducto.set(linea.productoId, costoProducto);
                continue;
            }
            const ingredientes = await this.cargarStockIngredientes(client, sucursalId, expandidos);
            let costoLinea = 0;
            const faltasLinea = ingredientes
                .filter((ing) => ing.descontar_stock && ing.stock_actual < ing.cantidad)
                .map((ing) => ({
                ingrediente_id: ing.ingrediente_id,
                nombre: ing.nombre,
                necesita: ing.cantidad,
                disponible: ing.stock_actual,
                unidad: ing.unidad_base,
            }));
            if (faltasLinea.length > 0) {
                this.lanzarStockInsuficiente(faltasLinea);
            }
            for (const ing of ingredientes) {
                costoLinea += ing.cantidad * ing.costo_unitario_actual;
                if (!ing.descontar_stock)
                    continue;
            }
            for (const ing of ingredientes) {
                if (!ing.descontar_stock)
                    continue;
                const stockAnterior = ing.stock_actual;
                const stockPosterior = stockAnterior - ing.cantidad;
                await this.stockMovimiento.aplicarMovimiento({
                    client,
                    sucursalId,
                    ingredienteId: ing.ingrediente_id,
                    tipo: 'venta',
                    cantidad: ing.cantidad,
                    stockAnterior,
                    stockPosterior,
                    pedidoId,
                    pedidoItemId: linea.pedidoItemId,
                    motivo: 'Venta pedido',
                });
                await this.alertarStockBajo(client, sucursalId, ing.ingrediente_id, stockPosterior, ing.stock_minimo);
                ingredientesTocados.add(ing.ingrediente_id);
                ing.stock_actual = stockPosterior;
            }
            costosPorProducto.set(linea.productoId, costoLinea / linea.cantidad);
        }
        for (const ingredienteId of ingredientesTocados) {
            const cambios = await this.catalogoDisponibilidad.sincronizarPorIngredienteEnTransaccion(client, sucursalId, ingredienteId);
            for (const c of cambios) {
                catalogoPorProducto.set(c.producto_id, c.disponible);
            }
        }
        const catalogo = [
            ...[...catalogoPorProducto.entries()].map(([producto_id, disponible]) => ({
                producto_id,
                disponible,
            })),
        ];
        return { costos: costosPorProducto, catalogo };
    }
    async restaurarStockPedido(client, sucursalId, pedidoId) {
        const catalogoPorProducto = new Map();
        const movs = await client.query(`SELECT ingrediente_id, cantidad
       FROM movimientos_ingrediente
       WHERE pedido_id = $1 AND sucursal_id = $2 AND tipo = 'venta'`, [pedidoId, sucursalId]);
        const ingredientesTocados = new Set();
        for (const mov of movs.rows) {
            const cantidad = Number(mov.cantidad);
            const ing = await client.query(`SELECT stock_actual, stock_minimo FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [mov.ingrediente_id, sucursalId]);
            const fila = ing.rows[0];
            if (!fila)
                continue;
            const stockAnterior = Number(fila.stock_actual);
            const stockPosterior = stockAnterior + cantidad;
            await this.stockMovimiento.aplicarMovimiento({
                client,
                sucursalId,
                ingredienteId: mov.ingrediente_id,
                tipo: 'ajuste',
                cantidad,
                stockAnterior,
                stockPosterior,
                pedidoId,
                motivo: 'Devolución por cancelación/rechazo de pedido',
            });
            ingredientesTocados.add(mov.ingrediente_id);
        }
        for (const ingredienteId of ingredientesTocados) {
            const cambios = await this.catalogoDisponibilidad.sincronizarPorIngredienteEnTransaccion(client, sucursalId, ingredienteId);
            for (const c of cambios) {
                catalogoPorProducto.set(c.producto_id, c.disponible);
            }
        }
        return [...catalogoPorProducto.entries()].map(([producto_id, disponible]) => ({ producto_id, disponible }));
    }
    async registrarMermaLineaProducto(client, sucursalId, pedidoId, productoId, cantidad, motivo) {
        const expandidos = await this.costeo.expandirIngredientesProducto(client, productoId, sucursalId, cantidad, false);
        if (expandidos.length === 0)
            return;
        const ingredientes = await this.cargarStockIngredientes(client, sucursalId, expandidos);
        for (const ing of ingredientes) {
            if (!ing.descontar_stock)
                continue;
            const stock = ing.stock_actual;
            await this.stockMovimiento.aplicarMovimiento({
                client,
                sucursalId,
                ingredienteId: ing.ingrediente_id,
                tipo: 'merma',
                cantidad: ing.cantidad,
                stockAnterior: stock,
                stockPosterior: stock,
                pedidoId,
                motivo,
            });
        }
    }
    async pedidoRequiereMermaAlCancelar(client, pedidoId, estadoAnterior) {
        const estadosMerma = [
            'en_cocina',
            'listo',
            'asignado',
            'en_camino',
            'entregado',
        ];
        if (estadosMerma.includes(estadoAnterior))
            return true;
        const items = await client.query(`SELECT COUNT(*)::text AS n FROM pedido_items
       WHERE pedido_id = $1 AND estado_cocina IN ('preparando', 'listo')`, [pedidoId]);
        return Number(items.rows[0]?.n ?? 0) > 0;
    }
    async registrarMermaPedidoCompleto(client, sucursalId, pedidoId, motivo) {
        const items = await client.query(`SELECT producto_id, cantidad, estado_cocina
       FROM pedido_items WHERE pedido_id = $1`, [pedidoId]);
        for (const item of items.rows) {
            if (item.estado_cocina === 'no_disponible')
                continue;
            await this.registrarMermaLineaProducto(client, sucursalId, pedidoId, item.producto_id, Number(item.cantidad), motivo);
        }
    }
    async restaurarStockLineaProducto(client, sucursalId, pedidoId, productoId, cantidad, opciones = {}) {
        const expandidos = await this.costeo.expandirIngredientesProducto(client, productoId, sucursalId, cantidad, opciones.incluirEmpaques ?? false);
        if (expandidos.length === 0)
            return;
        const ingredientes = await this.cargarStockIngredientes(client, sucursalId, expandidos);
        for (const ing of ingredientes) {
            if (!ing.descontar_stock)
                continue;
            const stockAnterior = ing.stock_actual;
            const stockPosterior = stockAnterior + ing.cantidad;
            await this.stockMovimiento.aplicarMovimiento({
                client,
                sucursalId,
                ingredienteId: ing.ingrediente_id,
                tipo: 'ajuste',
                cantidad: ing.cantidad,
                stockAnterior,
                stockPosterior,
                pedidoId,
                motivo: 'Devolución por ítem eliminado del pedido',
            });
            await this.alertarStockBajo(client, sucursalId, ing.ingrediente_id, stockPosterior, ing.stock_minimo);
        }
    }
    async lineasDesdePedido(client, pedidoId, sucursalId) {
        const lineas = new Map();
        const items = await client.query(`SELECT pi.id AS item_id, pi.producto_id, pi.cantidad, pi.precio_unitario
       FROM pedido_items pi
       WHERE pi.pedido_id = $1`, [pedidoId]);
        for (const row of items.rows) {
            const combo = await client.query(`SELECT combo_id, componentes_snapshot FROM pedido_combo_selecciones
         WHERE pedido_item_id = $1`, [row.item_id]);
            if (combo.rows[0]) {
                const snapshot = Array.isArray(combo.rows[0].componentes_snapshot)
                    ? combo.rows[0].componentes_snapshot
                    : [];
                if (snapshot.length > 0) {
                    const componentesProducto = snapshot.filter((c) => c.tipo_item === 'producto');
                    for (const componente of componentesProducto) {
                        const cant = Number(componente.cantidad) * row.cantidad;
                        const key = `${row.item_id}:${componente.item_id}`;
                        const prev = lineas.get(key);
                        lineas.set(key, {
                            pedidoItemId: row.item_id,
                            cantidad: (prev?.cantidad ?? 0) + cant,
                            precioVentaLinea: prev?.precioVentaLinea ?? 0,
                            extras: prev?.extras ?? [],
                        });
                    }
                    const productoAncla = componentesProducto[0]?.item_id;
                    if (productoAncla) {
                        const extras = snapshot
                            .filter((c) => c.tipo_item !== 'producto')
                            .map((c) => ({
                            tipo: c.tipo_item,
                            id: c.item_id,
                            cantidad: Number(c.cantidad) * row.cantidad,
                        }));
                        const prev = lineas.get(`${row.item_id}:${productoAncla}`);
                        if (prev)
                            prev.extras.push(...extras);
                    }
                    continue;
                }
                const comboItems = await client.query(`SELECT item_id, cantidad FROM combo_items
           WHERE combo_id = $1 AND tipo_item = 'producto'`, [combo.rows[0].combo_id]);
                for (const ci of comboItems.rows) {
                    const cant = Number(ci.cantidad) * row.cantidad;
                    const key = `${row.item_id}:${ci.item_id}`;
                    const prev = lineas.get(key);
                    lineas.set(key, {
                        pedidoItemId: row.item_id,
                        cantidad: (prev?.cantidad ?? 0) + cant,
                        precioVentaLinea: (prev?.precioVentaLinea ?? 0) + 1,
                        extras: prev?.extras ?? [],
                    });
                }
            }
            else {
                const extras = [];
                const tops = await client.query(`SELECT topping_id FROM pedido_item_toppings WHERE pedido_item_id = $1`, [row.item_id]);
                for (const t of tops.rows) {
                    extras.push({
                        tipo: 'topping',
                        id: t.topping_id,
                        cantidad: row.cantidad,
                    });
                }
                const bebs = await client.query(`SELECT bebida_id, cantidad::float AS cantidad
           FROM pedido_item_bebidas WHERE pedido_item_id = $1`, [row.item_id]);
                for (const b of bebs.rows) {
                    extras.push({
                        tipo: 'bebida',
                        id: b.bebida_id,
                        cantidad: Number(b.cantidad),
                    });
                }
                const key = `${row.item_id}:${row.producto_id}`;
                const prev = lineas.get(key);
                const venta = Number(row.precio_unitario) * row.cantidad;
                const extrasMerged = [...(prev?.extras ?? []), ...extras];
                lineas.set(key, {
                    pedidoItemId: row.item_id,
                    cantidad: (prev?.cantidad ?? 0) + row.cantidad,
                    precioVentaLinea: (prev?.precioVentaLinea ?? 0) + venta,
                    extras: extrasMerged,
                });
            }
        }
        return [...lineas.entries()].map(([key, v]) => ({
            productoId: key.slice(key.indexOf(':') + 1),
            pedidoItemId: v.pedidoItemId,
            cantidad: v.cantidad,
            precioVentaLinea: v.precioVentaLinea,
            extras: v.extras,
        }));
    }
    async validarYDescontarStock(client, sucursalId, pedidoId, lineas, opciones = {}) {
        await this.validarStockDisponible(client, sucursalId, lineas, opciones);
        return this.descontarStockPedido(client, sucursalId, pedidoId, lineas, opciones);
    }
    async alertarStockBajo(client, sucursalId, ingredienteId, stockPosterior, stockMinimo) {
        if (stockPosterior > stockMinimo)
            return;
        if (this.alertas) {
            await this.alertas.registrarEnTransaccion(client, {
                sucursalId,
                tipo: 'stock_minimo_alcanzado',
                nivel: 'medio',
                descripcion: 'Stock bajo en ingrediente tras pedido',
                referenciaId: ingredienteId,
                referenciaTipo: 'ingrediente',
                deduplicar: true,
            });
        }
        else {
            await client.query(`INSERT INTO alertas_riesgo (
           sucursal_id, tipo, nivel, descripcion, referencia_id, referencia_tipo
         ) VALUES ($1,'stock_minimo_alcanzado','medio',$2,$3,'ingrediente')`, [sucursalId, 'Stock bajo en ingrediente tras pedido', ingredienteId]);
        }
    }
    async cargarStockIngredientes(client, sucursalId, expandidos, opciones = {}) {
        const lanzar = opciones.lanzarSiFaltaIngrediente !== false;
        const ids = expandidos.map((e) => e.ingrediente_id);
        const resultado = await client.query(`SELECT id, nombre, unidad_base, stock_actual, stock_minimo,
              costo_unitario_actual, descontar_stock
       FROM ingredientes
       WHERE sucursal_id = $1 AND activo = true AND id = ANY($2::uuid[])
       FOR UPDATE`, [sucursalId, ids]);
        const porId = new Map(resultado.rows.map((r) => [r.id, r]));
        return expandidos.map((exp) => {
            const fila = porId.get(exp.ingrediente_id);
            if (!fila) {
                if (lanzar) {
                    this.lanzarStockInsuficiente([
                        {
                            ingrediente_id: exp.ingrediente_id,
                            nombre: 'Insumo no encontrado',
                            necesita: exp.cantidad,
                            disponible: 0,
                            unidad: 'und',
                        },
                    ]);
                }
                return {
                    ingrediente_id: exp.ingrediente_id,
                    nombre: 'Insumo no encontrado',
                    unidad_base: 'und',
                    cantidad: exp.cantidad,
                    stock_actual: 0,
                    stock_minimo: 0,
                    costo_unitario_actual: 0,
                    descontar_stock: true,
                };
            }
            return {
                ingrediente_id: exp.ingrediente_id,
                nombre: fila.nombre,
                unidad_base: fila.unidad_base ?? 'und',
                cantidad: exp.cantidad,
                stock_actual: Number(fila.stock_actual),
                stock_minimo: Number(fila.stock_minimo),
                costo_unitario_actual: Number(fila.costo_unitario_actual),
                descontar_stock: fila.descontar_stock !== false,
            };
        });
    }
    async costoCalculadoProducto(client, productoId) {
        const fila = await client.query(`SELECT costo_calculado AS costo FROM productos WHERE id = $1`, [productoId]);
        return Number(fila.rows[0]?.costo ?? 0);
    }
};
exports.PedidosInventarioService = PedidosInventarioService;
exports.PedidosInventarioService = PedidosInventarioService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [costeo_service_1.CosteoService,
        catalogo_disponibilidad_service_1.CatalogoDisponibilidadService,
        stock_movimiento_service_1.StockMovimientoService,
        alertas_riesgo_service_1.AlertasRiesgoService])
], PedidosInventarioService);
//# sourceMappingURL=pedidos-inventario.service.js.map