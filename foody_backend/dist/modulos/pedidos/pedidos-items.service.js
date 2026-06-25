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
exports.PedidosItemsService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const facturacion_service_1 = require("../facturacion/facturacion.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const costeo_service_1 = require("../costeo/costeo.service");
const pedidos_soporte_service_1 = require("./pedidos-soporte.service");
const pedidos_inventario_service_1 = require("./pedidos-inventario.service");
const ESTADOS_PEDIDO_CERRADO = [
    'entregado',
    'cancelado',
    'rechazado',
    'pagado',
];
let PedidosItemsService = class PedidosItemsService {
    database;
    facturacion;
    realtime;
    alertasRiesgo;
    costeo;
    soporte;
    inventario;
    constructor(database, facturacion, realtime, alertasRiesgo, costeo, soporte) {
        this.database = database;
        this.facturacion = facturacion;
        this.realtime = realtime;
        this.alertasRiesgo = alertasRiesgo;
        this.costeo = costeo;
        this.soporte = soporte;
        this.inventario = new pedidos_inventario_service_1.PedidosInventarioService(this.costeo, this.alertasRiesgo);
    }
    async agregarItems(pedidoId, sucursalId, dto, opciones = {}) {
        const items = dto.items ?? [];
        const combos = dto.combos ?? [];
        if (!items.length && !combos.length) {
            throw new common_1.BadRequestException('Debes incluir al menos un ?tem o combo');
        }
        const resultado = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, numero_pedido, tipo, estado, mesa_id, subtotal, costo_domicilio,
                descuento, total, metodo_pago, stock_descontado
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (ESTADOS_PEDIDO_CERRADO.includes(pedido.estado)) {
                throw new common_1.BadRequestException({
                    error: 'PEDIDO_CERRADO',
                    message: 'No se pueden agregar ?tems a un pedido cerrado',
                });
            }
            if (pedido.mesa_id &&
                opciones.creadoPorStaff &&
                opciones.usuarioId &&
                this.soporte.esRolMesero(opciones.rol)) {
                await this.soporte.assertMeseraPuedeTomarMesa(client, sucursalId, pedido.mesa_id, opciones.usuarioId);
            }
            let deltaSubtotal = 0;
            const lineasInventario = [];
            const lineasPreparadas = [];
            const combosPreparados = [];
            for (const item of items) {
                const producto = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio, precio_para_llevar, disponible, cocina_id, costo_calculado
           FROM productos WHERE id = $1 AND sucursal_id = $2`, [item.producto_id, sucursalId]);
                if (!producto?.disponible) {
                    throw new common_1.BadRequestException('PRODUCTO_NO_DISPONIBLE');
                }
                const precioUnit = this.soporte.precioVentaProducto(producto, pedido.tipo);
                let lineaTotal = precioUnit * item.cantidad;
                const toppings = [];
                for (const t of item.toppings ?? []) {
                    const top = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio FROM toppings
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [t.topping_id, sucursalId]);
                    if (!top)
                        throw new common_1.BadRequestException('TOPPING_NO_DISPONIBLE');
                    const p = Number(top.precio);
                    toppings.push({ id: top.id, nombre: top.nombre, precio: p });
                    lineaTotal += p * item.cantidad;
                }
                const bebidas = [];
                for (const b of item.bebidas ?? []) {
                    const beb = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio FROM bebidas
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [b.bebida_id, sucursalId]);
                    if (!beb)
                        throw new common_1.BadRequestException('BEBIDA_NO_DISPONIBLE');
                    const p = Number(beb.precio);
                    bebidas.push({
                        id: beb.id,
                        nombre: beb.nombre,
                        precio: p,
                        cantidad: b.cantidad,
                    });
                    lineaTotal += p * b.cantidad;
                }
                deltaSubtotal += lineaTotal;
                lineasPreparadas.push({
                    productoId: producto.id,
                    cantidad: item.cantidad,
                    precioUnitario: precioUnit,
                    precioVentaLinea: lineaTotal,
                    costoUnitario: Number(producto.costo_calculado ?? 0),
                    cocinaId: producto.cocina_id,
                    observaciones: item.observaciones ?? null,
                    toppings,
                    bebidas,
                });
                lineasInventario.push({
                    productoId: producto.id,
                    cantidad: item.cantidad,
                    precioVentaLinea: lineaTotal,
                    nombreProducto: producto.nombre,
                });
            }
            for (const comboDto of combos) {
                const combo = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio_fijo, disponible FROM combos
           WHERE id = $1 AND sucursal_id = $2`, [comboDto.combo_id, sucursalId]);
                if (!combo?.disponible) {
                    throw new common_1.BadRequestException('COMBO_NO_DISPONIBLE');
                }
                const precioFijo = Number(combo.precio_fijo);
                const comboItems = await client.query(`SELECT tipo_item, item_id, cantidad FROM combo_items WHERE combo_id = $1`, [combo.id]);
                const productoItem = comboItems.rows.find((ci) => ci.tipo_item === 'producto');
                if (!productoItem) {
                    throw new common_1.BadRequestException('COMBO_SIN_PRODUCTO');
                }
                const producto = await this.soporte.consultarUnoCliente(client, `SELECT id, cocina_id, costo_calculado FROM productos
           WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [productoItem.item_id, sucursalId]);
                if (!producto) {
                    throw new common_1.BadRequestException('PRODUCTO_NO_DISPONIBLE');
                }
                const productosCombo = comboItems.rows
                    .filter((ci) => ci.tipo_item === 'producto')
                    .map((ci) => ({ productoId: ci.item_id, cantidad: ci.cantidad }));
                deltaSubtotal += precioFijo * comboDto.cantidad;
                combosPreparados.push({
                    comboId: combo.id,
                    nombre: combo.nombre,
                    cantidad: comboDto.cantidad,
                    precioFijo,
                    productoPrincipalId: producto.id,
                    cocinaId: producto.cocina_id,
                    costoUnitario: 0,
                    productosCombo,
                });
                for (const pc of productosCombo) {
                    lineasInventario.push({
                        productoId: pc.productoId,
                        cantidad: pc.cantidad * comboDto.cantidad,
                        precioVentaLinea: 1,
                    });
                }
            }
            const opcionesStock = { incluirEmpaques: pedido.tipo === 'domicilio' };
            await this.inventario.validarStockDisponible(client, sucursalId, lineasInventario, opcionesStock, { origen: opciones.creadoPorStaff ? 'staff' : 'mesa' });
            let costosRecalculados = new Map();
            const catalogoCambios = [];
            if (pedido.stock_descontado) {
                const stock = await this.inventario.descontarStockPedido(client, sucursalId, pedidoId, lineasInventario, opcionesStock);
                costosRecalculados = stock.costos;
                catalogoCambios.push(...stock.catalogo);
            }
            else {
                for (const l of lineasPreparadas) {
                    costosRecalculados.set(l.productoId, l.costoUnitario);
                }
            }
            for (const combo of combosPreparados) {
                let costoUnit = 0;
                for (const pc of combo.productosCombo) {
                    const unit = costosRecalculados.get(pc.productoId) ?? 0;
                    costoUnit += unit * pc.cantidad;
                }
                combo.costoUnitario = costoUnit;
            }
            for (const linea of lineasPreparadas) {
                const costoUnit = costosRecalculados.get(linea.productoId) ?? linea.costoUnitario;
                const itemRes = await client.query(`INSERT INTO pedido_items (
             pedido_id, producto_id, cocina_id, cantidad, precio_unitario,
             costo_unitario, observaciones
           ) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`, [
                    pedidoId,
                    linea.productoId,
                    linea.cocinaId,
                    linea.cantidad,
                    linea.precioUnitario,
                    costoUnit,
                    linea.observaciones,
                ]);
                const itemId = itemRes.rows[0].id;
                const precioVenta = linea.precioVentaLinea;
                const costoTotal = costoUnit * linea.cantidad;
                const margenPct = precioVenta > 0
                    ? ((precioVenta - costoTotal) / precioVenta) * 100
                    : 0;
                await client.query(`INSERT INTO margenes_venta (
             pedido_id, pedido_item_id, sucursal_id,
             precio_venta, costo_al_momento, margen_porcentaje
           ) VALUES ($1,$2,$3,$4,$5,$6)`, [
                    pedidoId,
                    itemId,
                    sucursalId,
                    precioVenta,
                    costoTotal,
                    margenPct,
                ]);
                for (const t of linea.toppings) {
                    await client.query(`INSERT INTO pedido_item_toppings (pedido_item_id, topping_id, nombre_topping, precio_topping)
             VALUES ($1,$2,$3,$4)`, [itemId, t.id, t.nombre, t.precio]);
                }
                for (const b of linea.bebidas) {
                    await client.query(`INSERT INTO pedido_item_bebidas (pedido_item_id, bebida_id, nombre_bebida, precio_bebida, cantidad)
             VALUES ($1,$2,$3,$4,$5)`, [itemId, b.id, b.nombre, b.precio, b.cantidad]);
                }
            }
            for (const combo of combosPreparados) {
                for (let u = 0; u < combo.cantidad; u++) {
                    const costoUnit = combo.costoUnitario;
                    const itemRes = await client.query(`INSERT INTO pedido_items (
               pedido_id, producto_id, cocina_id, cantidad, precio_unitario,
               costo_unitario, observaciones
             ) VALUES ($1,$2,$3,1,$4,$5,$6) RETURNING id`, [
                        pedidoId,
                        combo.productoPrincipalId,
                        combo.cocinaId,
                        combo.precioFijo,
                        costoUnit,
                        `Combo: ${combo.nombre}`,
                    ]);
                    const itemId = itemRes.rows[0].id;
                    await client.query(`INSERT INTO pedido_combo_selecciones (
               pedido_item_id, combo_id, nombre_combo, precio_combo
             ) VALUES ($1,$2,$3,$4)`, [itemId, combo.comboId, combo.nombre, combo.precioFijo]);
                    const margenPct = combo.precioFijo > 0
                        ? ((combo.precioFijo - costoUnit) / combo.precioFijo) * 100
                        : 0;
                    await client.query(`INSERT INTO margenes_venta (
               pedido_id, pedido_item_id, sucursal_id,
               precio_venta, costo_al_momento, margen_porcentaje
             ) VALUES ($1,$2,$3,$4,$5,$6)`, [
                        pedidoId,
                        itemId,
                        sucursalId,
                        combo.precioFijo,
                        costoUnit,
                        margenPct,
                    ]);
                }
            }
            const subtotalAnterior = Number(pedido.subtotal);
            const subtotalNuevo = subtotalAnterior + deltaSubtotal;
            const costoDomicilio = Number(pedido.costo_domicilio);
            const descuento = Number(pedido.descuento);
            const totalNuevo = subtotalNuevo + costoDomicilio - descuento;
            const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(client, sucursalId, totalNuevo);
            await client.query(`UPDATE pedidos SET
           subtotal = $1, total = $2, iva_porcentaje = $3, iva_valor = $4
         WHERE id = $5`, [subtotalNuevo, totalNuevo, iva.iva_porcentaje, iva.iva_valor, pedidoId]);
            return {
                pedido_id: pedidoId,
                numero_pedido: pedido.numero_pedido,
                subtotal: subtotalNuevo,
                delta_subtotal: deltaSubtotal,
                total: totalNuevo,
                estado: pedido.estado,
                mesa_id: pedido.mesa_id,
                catalogo_cambios: catalogoCambios,
            };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, resultado.pedido_id, resultado.estado, resultado.numero_pedido);
        this.soporte.notificarCatalogoDisponibilidad(sucursalId, resultado.catalogo_cambios ?? []);
        if (resultado.mesa_id) {
            void this.realtime.mesasActualizadas(sucursalId);
        }
        void this.soporte.notificarCocinasPorPedido(resultado.pedido_id, sucursalId);
        return resultado;
    }
    async eliminarItemPedido(pedidoId, itemId, sucursalId, usuarioId, motivo) {
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, tipo, mesa_id, stock_descontado,
                subtotal, costo_domicilio, descuento, numero_pedido
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (ESTADOS_PEDIDO_CERRADO.includes(pedido.estado)) {
                throw new common_1.BadRequestException({
                    error: 'PEDIDO_CERRADO',
                    message: 'No se pueden eliminar ?tems de un pedido cerrado',
                });
            }
            const item = await this.soporte.consultarUnoCliente(client, `SELECT pi.id, pi.producto_id, pi.cantidad, pi.precio_unitario,
                pi.estado_cocina, pi.cocina_id, pr.nombre AS nombre_producto
         FROM pedido_items pi
         INNER JOIN productos pr ON pr.id = pi.producto_id
         WHERE pi.id = $1 AND pi.pedido_id = $2`, [itemId, pedidoId]);
            if (!item)
                throw new common_1.NotFoundException('?tem de pedido no encontrado');
            const conteoItems = await client.query(`SELECT COUNT(*)::text AS n FROM pedido_items WHERE pedido_id = $1`, [pedidoId]);
            if (Number(conteoItems.rows[0]?.n ?? 0) <= 1) {
                throw new common_1.BadRequestException({
                    error: 'PEDIDO_SIN_ITEMS',
                    message: 'No puedes eliminar el ?ltimo ?tem. Cancela el pedido completo.',
                });
            }
            const enCocina = ['preparando', 'listo'].includes(item.estado_cocina);
            if (enCocina) {
                await this.alertasRiesgo.registrarEnTransaccion(client, {
                    sucursalId,
                    tipo: 'item_eliminado_post_cocina',
                    nivel: 'alto',
                    descripcion: `${pedido.numero_pedido}: se elimin? ?${item.nombre_producto}? (estado cocina: ${item.estado_cocina}). Motivo: ${motivo?.trim() || 'Sin motivo'}`,
                    referenciaId: itemId,
                    referenciaTipo: 'pedido_item',
                });
            }
            if (pedido.stock_descontado) {
                if (enCocina) {
                    await this.inventario.registrarMermaLineaProducto(client, sucursalId, pedidoId, item.producto_id, item.cantidad, motivo ?? `?tem eliminado en cocina (${item.estado_cocina})`);
                }
                else {
                    await this.inventario.restaurarStockLineaProducto(client, sucursalId, pedidoId, item.producto_id, item.cantidad, { incluirEmpaques: pedido.tipo === 'domicilio' });
                }
            }
            const lineaTotal = Number(item.precio_unitario) * item.cantidad;
            await client.query(`DELETE FROM pedido_items WHERE id = $1`, [itemId]);
            const subtotalNuevo = Math.max(0, Number(pedido.subtotal) - lineaTotal);
            const totalNuevo = subtotalNuevo +
                Number(pedido.costo_domicilio) -
                Number(pedido.descuento);
            const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(client, sucursalId, totalNuevo);
            await client.query(`UPDATE pedidos SET
           subtotal = $1, total = $2, iva_porcentaje = $3, iva_valor = $4
         WHERE id = $5`, [
                subtotalNuevo,
                totalNuevo,
                iva.iva_porcentaje,
                iva.iva_valor,
                pedidoId,
            ]);
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, accion, tabla_afectada, registro_id, usuario_id, datos_despues
         ) VALUES ($1,'ELIMINAR_ITEM_PEDIDO','pedido_items',$2,$3,$4::jsonb)`, [
                sucursalId,
                itemId,
                usuarioId,
                JSON.stringify({
                    pedido_id: pedidoId,
                    numero_pedido: pedido.numero_pedido,
                    producto: item.nombre_producto,
                    estado_cocina: item.estado_cocina,
                    motivo: motivo?.trim() || null,
                }),
            ]);
            return {
                pedido_id: pedidoId,
                item_id: itemId,
                estado: pedido.estado,
                numero_pedido: pedido.numero_pedido,
                subtotal: subtotalNuevo,
                total: totalNuevo,
                cocina_id: item.cocina_id,
                mesa_id: pedido.mesa_id,
            };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, result.pedido_id, result.estado, result.numero_pedido);
        if (result.cocina_id) {
            void this.realtime.cocinaActualizada(result.cocina_id, {
                pedido_id: result.pedido_id,
                sucursal_id: sucursalId,
                accion: 'item_eliminado',
            });
        }
        if (result.mesa_id) {
            void this.realtime.mesasActualizadas(sucursalId);
        }
        return result;
    }
    async actualizarComensalEtiqueta(pedidoId, itemId, sucursalId, comensalEtiqueta) {
        const res = await this.database.consultarUno(`UPDATE pedido_items pi
       SET comensal_etiqueta = $4
       FROM pedidos p
       WHERE pi.id = $1 AND pi.pedido_id = $2 AND p.id = $2
         AND p.sucursal_id = $3 AND p.estado NOT IN ('cancelado','rechazado','pagado')
       RETURNING pi.id`, [itemId, pedidoId, sucursalId, comensalEtiqueta?.trim() || null]);
        if (!res) {
            throw new common_1.NotFoundException('Ítem no encontrado o pedido cerrado');
        }
        return { item_id: itemId, comensal_etiqueta: comensalEtiqueta?.trim() || null };
    }
};
exports.PedidosItemsService = PedidosItemsService;
exports.PedidosItemsService = PedidosItemsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        facturacion_service_1.FacturacionService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        costeo_service_1.CosteoService,
        pedidos_soporte_service_1.PedidosSoporteService])
], PedidosItemsService);
//# sourceMappingURL=pedidos-items.service.js.map