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
const crypto_1 = require("crypto");
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
    async crearTareasCombo(client, sucursalId, pedidoId, pedidoItemId, componentes) {
        for (const [indice, componente] of componentes.entries()) {
            if (!componente.cocina_id) {
                throw new common_1.BadRequestException({
                    error: 'COMBO_COMPONENTE_SIN_COCINA',
                    message: `El componente «${componente.nombre}» no tiene estación asignada.`,
                });
            }
            await client.query(`INSERT INTO pedido_combo_tareas_cocina (
           pedido_id, pedido_item_id, pedido_item_id_original,
           sucursal_id, cocina_id, componente_indice,
           tipo_item, componente_id, nombre_snapshot, cantidad,
           precio_unitario_snapshot, costo_unitario_snapshot,
           producto_padre_id, producto_padre_nombre_snapshot
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`, [
                pedidoId,
                pedidoItemId,
                pedidoItemId,
                sucursalId,
                componente.cocina_id,
                indice,
                componente.tipo_item,
                componente.item_id,
                componente.nombre,
                componente.cantidad,
                componente.precio_unitario,
                componente.costo_unitario,
                componente.producto_padre_id ?? null,
                componente.producto_padre_nombre_snapshot ?? null,
            ]);
        }
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
        return (await this.expandirLineaConComponentes(client, sucursalId, linea, incluirEmpaques)).expandidos;
    }
    async expandirLineaConComponentes(client, sucursalId, linea, incluirEmpaques) {
        const acumulador = new Map();
        const componentes = [];
        const sumar = (items) => {
            for (const i of items) {
                acumulador.set(i.ingrediente_id, (acumulador.get(i.ingrediente_id) ?? 0) + i.cantidad);
            }
        };
        const producto = await this.costeo.expandirIngredientesProducto(client, linea.productoId, sucursalId, linea.cantidad, incluirEmpaques);
        sumar(producto);
        if (linea.comboComponenteIndice != null &&
            linea.comboComponenteId != null) {
            componentes.push({
                indice: linea.comboComponenteIndice,
                componenteId: linea.comboComponenteId,
                tipoItem: 'producto',
                ingredientes: producto,
            });
        }
        else {
            componentes.push({
                indice: 0,
                componenteId: linea.productoId,
                tipoItem: 'producto',
                ingredientes: producto,
            });
        }
        for (const [indiceExtra, extra] of (linea.extras ?? []).entries()) {
            const expansionExtra = await this.costeo.expandirIngredientesExtra(client, extra.tipo, extra.id, sucursalId, extra.cantidad, incluirEmpaques);
            sumar(expansionExtra);
            if (extra.comboComponenteIndice != null &&
                extra.comboComponenteId != null) {
                componentes.push({
                    indice: extra.comboComponenteIndice,
                    componenteId: extra.comboComponenteId,
                    tipoItem: extra.tipo,
                    ingredientes: expansionExtra,
                });
            }
            else if (linea.comboComponenteIndice == null ||
                linea.comboComponenteId == null) {
                componentes.push({
                    indice: indiceExtra + 1,
                    componenteId: extra.id,
                    tipoItem: extra.tipo,
                    ingredientes: expansionExtra,
                });
            }
        }
        return {
            expandidos: [...acumulador.entries()].map(([ingrediente_id, cantidad]) => ({ ingrediente_id, cantidad })),
            componentes,
        };
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
            const expansion = await this.expandirLineaConComponentes(client, sucursalId, linea, incluirEmpaques);
            const expandidos = expansion.expandidos;
            if (expandidos.length === 0) {
                const costoProducto = await this.costoCalculadoProducto(client, linea.productoId);
                costosPorProducto.set(linea.productoId, costoProducto);
                continue;
            }
            const ingredientes = await this.cargarStockIngredientes(client, sucursalId, expandidos);
            await this.registrarSnapshotStockCombo(client, sucursalId, pedidoId, linea, expansion.componentes, ingredientes);
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
            if (linea.pedidoItemId &&
                linea.comboComponenteIndice == null &&
                linea.comboComponenteId == null) {
                await this.registrarSnapshotStockItemNormal(client, sucursalId, pedidoId, linea.pedidoItemId, linea.cantidad, expansion.componentes, ingredientes);
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
    async registrarSnapshotStockItemNormal(client, sucursalId, pedidoId, pedidoItemId, unidadesLinea, componentes, ingredientes) {
        const porIngrediente = new Map(ingredientes.map((i) => [i.ingrediente_id, i]));
        const loteId = (0, crypto_1.randomUUID)();
        for (const componente of componentes) {
            for (const ingrediente of componente.ingredientes) {
                const stock = porIngrediente.get(ingrediente.ingrediente_id);
                if (!stock?.descontar_stock || ingrediente.cantidad <= 0)
                    continue;
                await client.query(`INSERT INTO pedido_item_stock_ledger (
             pedido_id, pedido_item_id, pedido_item_id_original, sucursal_id,
             lote_id, tipo_componente, componente_id, ingrediente_id,
             evento, cantidad, unidades_linea, costo_unitario_snapshot
           ) VALUES ($1,$2,$2,$3,$4,$5,$6,$7,'consumo',$8,$9,$10)`, [
                    pedidoId,
                    pedidoItemId,
                    sucursalId,
                    loteId,
                    componente.tipoItem,
                    componente.componenteId,
                    ingrediente.ingrediente_id,
                    ingrediente.cantidad,
                    unidadesLinea,
                    stock.costo_unitario_actual,
                ]);
            }
        }
    }
    async ajustarStockItemNormalDesdeSnapshot(client, params) {
        const operacionId = (0, crypto_1.randomUUID)();
        const snapshots = await client.query(`SELECT c.id, c.tipo_componente, c.componente_id, c.ingrediente_id,
              c.cantidad::text,
              c.unidades_linea::text,
              COALESCE((
                SELECT SUM(a.unidades_linea) FROM pedido_item_stock_ledger a
                WHERE a.consumo_id = c.id AND a.evento IN ('devolucion', 'merma')
              ), 0)::text AS unidades_ajustadas,
              COALESCE((
                SELECT SUM(a.cantidad) FROM pedido_item_stock_ledger a
                WHERE a.consumo_id = c.id AND a.evento IN ('devolucion', 'merma')
              ), 0)::text AS cantidad_ajustada
       FROM pedido_item_stock_ledger c
       WHERE c.pedido_item_id_original = $1 AND c.pedido_id = $2
         AND c.sucursal_id = $3 AND c.evento = 'consumo'
         AND ($4::text IS NULL OR c.tipo_componente = $4)
         AND ($5::uuid IS NULL OR c.componente_id = $5)
         AND c.unidades_linea > COALESCE((
           SELECT SUM(a.unidades_linea) FROM pedido_item_stock_ledger a
           WHERE a.consumo_id = c.id AND a.evento IN ('devolucion', 'merma')
         ), 0)
       ORDER BY c.created_at DESC, c.id DESC
       FOR UPDATE OF c`, [
            params.pedidoItemId,
            params.pedidoId,
            params.sucursalId,
            params.tipoComponente ?? null,
            params.componenteId ?? null,
        ]);
        const hasSnapshots = snapshots.rows.length > 0;
        if (!hasSnapshots) {
            const legacyMovimientos = await client.query(`SELECT COUNT(*)::text AS n FROM movimientos_ingrediente
         WHERE pedido_id = $1 AND pedido_item_id = $2
           AND sucursal_id = $3 AND tipo = 'venta'`, [params.pedidoId, params.pedidoItemId, params.sucursalId]);
            if (Number(legacyMovimientos.rows[0]?.n ?? 0) === 0)
                return;
        }
        const ingredientesTocados = new Set();
        const grupos = new Map();
        for (const snapshot of snapshots.rows) {
            const key = `${snapshot.tipo_componente}:${snapshot.componente_id}:${snapshot.ingrediente_id}`;
            grupos.set(key, [...(grupos.get(key) ?? []), snapshot]);
        }
        let gruposIncompletos = 0;
        for (const filas of grupos.values()) {
            let unidadesPendientes = params.unidades;
            for (const snapshot of filas) {
                if (unidadesPendientes <= 0)
                    break;
                const unidadesOriginales = Number(snapshot.unidades_linea);
                const unidadesDisponibles = unidadesOriginales - Number(snapshot.unidades_ajustadas);
                const cantidadDisponible = Number(snapshot.cantidad) - Number(snapshot.cantidad_ajustada);
                if (unidadesDisponibles <= 0 || cantidadDisponible <= 0)
                    continue;
                const unidadesAjustar = Math.min(unidadesPendientes, unidadesDisponibles);
                const cantidadAjustar = cantidadDisponible * (unidadesAjustar / unidadesDisponibles);
                const ingrediente = await client.query(`SELECT stock_actual, stock_minimo FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [snapshot.ingrediente_id, params.sucursalId]);
                const fila = ingrediente.rows[0];
                if (!fila) {
                    throw new common_1.BadRequestException({
                        error: 'STOCK_LEDGER_INGREDIENTE_INCONSISTENTE',
                        message: 'No se puede conciliar el ingrediente de esta línea.',
                    });
                }
                const stockAnterior = Number(fila.stock_actual);
                const stockPosterior = params.evento === 'devolucion'
                    ? stockAnterior + cantidadAjustar
                    : stockAnterior;
                await this.stockMovimiento.aplicarMovimiento({
                    client,
                    sucursalId: params.sucursalId,
                    ingredienteId: snapshot.ingrediente_id,
                    tipo: params.evento,
                    cantidad: cantidadAjustar,
                    stockAnterior,
                    stockPosterior,
                    pedidoId: params.pedidoId,
                    pedidoItemId: params.pedidoItemId,
                    usuarioId: params.usuarioId,
                    motivo: params.motivo,
                });
                await client.query(`INSERT INTO pedido_item_stock_ledger (
           pedido_id, pedido_item_id, pedido_item_id_original, sucursal_id,
           lote_id, tipo_componente, componente_id, ingrediente_id,
           evento, cantidad, unidades_linea, costo_unitario_snapshot,
           consumo_id, operacion_id
         )
         SELECT pedido_id, pedido_item_id, pedido_item_id_original, sucursal_id,
                lote_id, tipo_componente, componente_id, ingrediente_id,
                $2, $3, $4, costo_unitario_snapshot, id, $5
         FROM pedido_item_stock_ledger WHERE id = $1`, [
                    snapshot.id,
                    params.evento,
                    cantidadAjustar,
                    unidadesAjustar,
                    operacionId,
                ]);
                if (params.evento === 'devolucion') {
                    ingredientesTocados.add(snapshot.ingrediente_id);
                }
                unidadesPendientes -= unidadesAjustar;
            }
            if (unidadesPendientes > 0.000001)
                gruposIncompletos += 1;
        }
        if (!hasSnapshots || gruposIncompletos > 0) {
            throw new common_1.BadRequestException({
                error: 'STOCK_LEDGER_LINEA_INCOMPLETO',
                message: 'No hay snapshot completo para conciliar el inventario de esta línea. No se modificó su stock.',
            });
        }
        await this.sincronizarDisponibilidadIngredientes(client, params.sucursalId, ingredientesTocados);
    }
    async registrarSnapshotStockCombo(client, sucursalId, pedidoId, linea, componentes, ingredientesAgregados) {
        if (!linea.pedidoItemId || linea.comboComponenteIndice == null)
            return;
        const porIngrediente = new Map(ingredientesAgregados.map((i) => [i.ingrediente_id, i]));
        for (const componente of componentes) {
            for (const item of componente.ingredientes) {
                const ingredienteId = item.ingrediente_id;
                const cantidad = item.cantidad;
                const ingrediente = porIngrediente.get(ingredienteId);
                if (!ingrediente || ingrediente.descontar_stock === false)
                    continue;
                await client.query(`INSERT INTO pedido_combo_stock_ledger (
             pedido_id, pedido_item_id, pedido_item_id_original,
             componente_indice,
             componente_id, ingrediente_id, evento, cantidad,
             costo_unitario_snapshot
           ) VALUES ($1,$2,$3,$4,$5,$6,'consumo',$7,$8)`, [
                    pedidoId,
                    linea.pedidoItemId,
                    linea.pedidoItemId,
                    componente.indice,
                    componente.componenteId,
                    ingredienteId,
                    cantidad,
                    ingrediente.costo_unitario_actual,
                ]);
            }
        }
    }
    async restaurarStockPedido(client, sucursalId, pedidoId) {
        const catalogoPorProducto = new Map();
        const movs = await client.query(`SELECT ingrediente_id,
              GREATEST(
                COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'venta'), 0)
                - COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'devolucion'), 0)
                - COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'merma'), 0)
                - COALESCE(SUM(cantidad) FILTER (
                    WHERE tipo = 'ajuste'
                      AND motivo IN (
                        'Devolución por cancelación/rechazo de pedido',
                        'Devolución por ítem eliminado del pedido'
                      )
                  ), 0),
                0
              )::text AS cantidad
       FROM movimientos_ingrediente
       WHERE pedido_id = $1 AND sucursal_id = $2
         AND tipo IN ('venta', 'devolucion', 'merma', 'ajuste')
       GROUP BY ingrediente_id
       HAVING GREATEST(
         COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'venta'), 0)
         - COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'devolucion'), 0)
         - COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'merma'), 0)
         - COALESCE(SUM(cantidad) FILTER (
             WHERE tipo = 'ajuste'
               AND motivo IN (
                 'Devolución por cancelación/rechazo de pedido',
                 'Devolución por ítem eliminado del pedido'
               )
           ), 0),
         0
       ) > 0`, [pedidoId, sucursalId]);
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
                tipo: 'devolucion',
                cantidad,
                stockAnterior,
                stockPosterior,
                pedidoId,
                pedidoItemId: null,
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
    async ajustarStockComponenteCombo(client, params) {
        const { sucursalId, pedidoId, pedidoItemIdOriginal, decisionId, componenteIndice, componenteId, tipoItem, cantidad, evento, motivo, usuarioId, } = params;
        if (evento === 'consumo') {
            const expansion = tipoItem === 'producto'
                ? await this.costeo.expandirIngredientesProducto(client, componenteId, sucursalId, cantidad, false)
                : await this.costeo.expandirIngredientesExtra(client, tipoItem, componenteId, sucursalId, cantidad, false);
            const ingredientes = await this.cargarStockIngredientes(client, sucursalId, expansion);
            const faltas = ingredientes
                .filter((i) => i.descontar_stock && i.stock_actual < i.cantidad)
                .map((i) => ({
                ingrediente_id: i.ingrediente_id,
                nombre: i.nombre,
                necesita: i.cantidad,
                disponible: i.stock_actual,
                unidad: i.unidad_base,
            }));
            if (faltas.length)
                this.lanzarStockInsuficiente(faltas);
            const tocados = new Set();
            for (const ingrediente of ingredientes) {
                if (!ingrediente.descontar_stock)
                    continue;
                const stockPosterior = ingrediente.stock_actual - ingrediente.cantidad;
                await this.stockMovimiento.aplicarMovimiento({
                    client,
                    sucursalId,
                    ingredienteId: ingrediente.ingrediente_id,
                    tipo: 'venta',
                    cantidad: ingrediente.cantidad,
                    stockAnterior: ingrediente.stock_actual,
                    stockPosterior,
                    pedidoId,
                    pedidoItemId: pedidoItemIdOriginal,
                    usuarioId,
                    motivo,
                });
                await this.insertarMovimientoLedgerCombo(client, {
                    ...params,
                    ingredienteId: ingrediente.ingrediente_id,
                    cantidadIngrediente: ingrediente.cantidad,
                    costoUnitario: ingrediente.costo_unitario_actual,
                });
                tocados.add(ingrediente.ingrediente_id);
            }
            await this.sincronizarDisponibilidadIngredientes(client, sucursalId, tocados);
            return;
        }
        const result = await client.query(`SELECT ingrediente_id,
              GREATEST(
                COALESCE(SUM(cantidad) FILTER (WHERE evento = 'consumo'), 0)
                - COALESCE(SUM(cantidad) FILTER (WHERE evento IN ('devolucion', 'merma')), 0),
                0
              )::text AS cantidad,
              MAX(costo_unitario_snapshot)::text AS costo_unitario_snapshot
       FROM pedido_combo_stock_ledger
       WHERE pedido_id = $1 AND pedido_item_id_original = $2
         AND componente_indice = $3 AND componente_id = $4
       GROUP BY ingrediente_id
       HAVING GREATEST(
         COALESCE(SUM(cantidad) FILTER (WHERE evento = 'consumo'), 0)
         - COALESCE(SUM(cantidad) FILTER (WHERE evento IN ('devolucion', 'merma')), 0),
         0
       ) > 0`, [pedidoId, pedidoItemIdOriginal, componenteIndice, componenteId]);
        const tocados = new Set();
        for (const fila of result.rows) {
            const cantidadIngrediente = Number(fila.cantidad);
            const ingrediente = await client.query(`SELECT stock_actual FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [fila.ingrediente_id, sucursalId]);
            const stockActual = Number(ingrediente.rows[0]?.stock_actual);
            if (!ingrediente.rows[0]) {
                throw new common_1.BadRequestException({
                    error: 'COMBO_INGREDIENTE_LEDGER_INCONSISTENTE',
                    message: 'No se puede conciliar el combo: un ingrediente del ledger ya no existe en la sede.',
                });
            }
            const stockPosterior = evento === 'devolucion'
                ? stockActual + cantidadIngrediente
                : stockActual;
            await this.stockMovimiento.aplicarMovimiento({
                client,
                sucursalId,
                ingredienteId: fila.ingrediente_id,
                tipo: evento,
                cantidad: cantidadIngrediente,
                stockAnterior: stockActual,
                stockPosterior,
                pedidoId,
                pedidoItemId: pedidoItemIdOriginal,
                usuarioId,
                motivo,
            });
            await this.insertarMovimientoLedgerCombo(client, {
                ...params,
                ingredienteId: fila.ingrediente_id,
                cantidadIngrediente,
                costoUnitario: Number(fila.costo_unitario_snapshot),
            });
            if (evento === 'devolucion')
                tocados.add(fila.ingrediente_id);
        }
        await this.sincronizarDisponibilidadIngredientes(client, sucursalId, tocados);
    }
    async insertarMovimientoLedgerCombo(client, params) {
        await client.query(`INSERT INTO pedido_combo_stock_ledger (
         pedido_id, pedido_item_id, pedido_item_id_original,
         componente_indice, componente_id, ingrediente_id,
         evento, cantidad, costo_unitario_snapshot, decision_id
       ) VALUES ($1,$2,$2,$3,$4,$5,$6,$7,$8,$9)`, [
            params.pedidoId,
            params.pedidoItemIdOriginal,
            params.componenteIndice,
            params.componenteId,
            params.ingredienteId,
            params.evento,
            params.cantidadIngrediente,
            params.costoUnitario,
            params.decisionId,
        ]);
    }
    async sincronizarDisponibilidadIngredientes(client, sucursalId, ingredientes) {
        for (const ingredienteId of ingredientes) {
            await this.catalogoDisponibilidad.sincronizarPorIngredienteEnTransaccion(client, sucursalId, ingredienteId);
        }
    }
    async registrarMermaLineaProducto(client, sucursalId, pedidoId, productoId, cantidad, motivo, pedidoItemId) {
        if (pedidoItemId) {
            const combo = await client.query(`SELECT EXISTS (
           SELECT 1 FROM pedido_combo_selecciones WHERE pedido_item_id = $1
         ) AS existe`, [pedidoItemId]);
            if (combo.rows[0]?.existe) {
                const tareas = await client.query(`SELECT componente_indice, componente_id, tipo_item,
                  cantidad::text AS cantidad
           FROM pedido_combo_tareas_cocina
           WHERE pedido_item_id_original = $1 AND pedido_id = $2
           ORDER BY componente_indice`, [pedidoItemId, pedidoId]);
                if (tareas.rows.length === 0) {
                    throw new common_1.BadRequestException({
                        error: 'COMBO_STOCK_LEDGER_INCONSISTENTE',
                        message: 'No se registra merma del combo porque faltan sus snapshots de tareas por estación.',
                    });
                }
                for (const tarea of tareas.rows) {
                    await this.ajustarStockComponenteCombo(client, {
                        sucursalId,
                        pedidoId,
                        pedidoItemIdOriginal: pedidoItemId,
                        decisionId: null,
                        componenteIndice: tarea.componente_indice,
                        componenteId: tarea.componente_id,
                        tipoItem: tarea.tipo_item,
                        cantidad: Number(tarea.cantidad),
                        evento: 'merma',
                        motivo,
                        usuarioId: '',
                    });
                }
                return;
            }
            const snapshot = await client.query(`SELECT COUNT(*)::text AS n FROM pedido_item_stock_ledger
         WHERE pedido_item_id_original = $1 AND pedido_id = $2
           AND sucursal_id = $3 AND evento = 'consumo'`, [pedidoItemId, pedidoId, sucursalId]);
            if (Number(snapshot.rows[0]?.n ?? 0) > 0) {
                await this.ajustarStockItemNormalDesdeSnapshot(client, {
                    sucursalId,
                    pedidoId,
                    pedidoItemId,
                    unidades: cantidad,
                    evento: 'merma',
                    motivo,
                });
                return;
            }
            const movimientos = await client.query(`SELECT COUNT(*)::text AS n FROM movimientos_ingrediente
         WHERE pedido_id = $1 AND pedido_item_id = $2
           AND sucursal_id = $3 AND tipo = 'venta'`, [pedidoId, pedidoItemId, sucursalId]);
            if (Number(movimientos.rows[0]?.n ?? 0) > 0) {
                throw new common_1.BadRequestException({
                    error: 'STOCK_LEDGER_LINEA_INCOMPLETO',
                    message: 'No se registra merma automática porque esta línea no conserva el desglose de ingredientes consumido al vender.',
                });
            }
            return;
        }
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
                pedidoItemId,
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
        const items = await client.query(`SELECT id AS item_id, producto_id, cantidad, estado_cocina
       FROM pedido_items WHERE pedido_id = $1`, [pedidoId]);
        for (const item of items.rows) {
            if (item.estado_cocina === 'no_disponible')
                continue;
            await this.registrarMermaLineaProducto(client, sucursalId, pedidoId, item.producto_id, Number(item.cantidad), motivo, item.item_id);
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
                    const componentesProducto = snapshot
                        .map((componente, indice) => ({ componente, indice }))
                        .filter(({ componente }) => componente.tipo_item === 'producto');
                    for (const { componente, indice } of componentesProducto) {
                        const cant = Number(componente.cantidad) * row.cantidad;
                        const key = `${row.item_id}:${componente.item_id}`;
                        const prev = lineas.get(key);
                        lineas.set(key, {
                            pedidoItemId: row.item_id,
                            cantidad: (prev?.cantidad ?? 0) + cant,
                            precioVentaLinea: prev?.precioVentaLinea ?? 0,
                            extras: prev?.extras ?? [],
                            comboComponenteIndice: indice,
                            comboComponenteId: componente.item_id,
                        });
                    }
                    const productoAncla = componentesProducto[0]?.componente.item_id;
                    if (productoAncla) {
                        for (const { componente, indice } of snapshot
                            .map((componente, snapshotIndice) => ({
                            componente,
                            indice: snapshotIndice,
                        }))
                            .filter(({ componente }) => componente.tipo_item !== 'producto')) {
                            const productoDestino = componente.producto_padre_id ?? productoAncla;
                            const destino = lineas.get(`${row.item_id}:${productoDestino}`);
                            if (!destino)
                                continue;
                            destino.extras.push({
                                tipo: componente.tipo_item,
                                id: componente.item_id,
                                cantidad: Number(componente.cantidad) * row.cantidad,
                                comboComponenteIndice: indice,
                                comboComponenteId: componente.item_id,
                            });
                        }
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
            ...(v.comboComponenteIndice == null
                ? {}
                : {
                    comboComponenteIndice: v.comboComponenteIndice,
                    comboComponenteId: v.comboComponenteId,
                }),
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