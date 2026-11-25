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
exports.PedidosCrearService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const facturacion_service_1 = require("../facturacion/facturacion.service");
const zonas_service_1 = require("../zonas/zonas.service");
const promociones_service_1 = require("../promociones/promociones.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const costeo_service_1 = require("../costeo/costeo.service");
const pedidos_caja_auditoria_service_1 = require("./pedidos-caja-auditoria.service");
const pedidos_soporte_service_1 = require("./pedidos-soporte.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
const pedidos_inventario_service_1 = require("./pedidos-inventario.service");
const pedido_estados_1 = require("./pedido-estados");
const pedidos_idempotencia_util_1 = require("./pedidos-idempotencia.util");
const DIAS_ANTICIPACION_ENCARGO_MIN = 2;
let PedidosCrearService = class PedidosCrearService {
    database;
    facturacion;
    zonas;
    realtime;
    alertasRiesgo;
    costeo;
    promociones;
    cajaAuditoria;
    soporte;
    cuentaMesa;
    inventario;
    constructor(database, facturacion, zonas, realtime, alertasRiesgo, costeo, promociones, cajaAuditoria, soporte, cuentaMesa, inventario) {
        this.database = database;
        this.facturacion = facturacion;
        this.zonas = zonas;
        this.realtime = realtime;
        this.alertasRiesgo = alertasRiesgo;
        this.costeo = costeo;
        this.promociones = promociones;
        this.cajaAuditoria = cajaAuditoria;
        this.soporte = soporte;
        this.cuentaMesa = cuentaMesa;
        this.inventario = inventario;
    }
    async crear(dto, opciones = {}) {
        const items = dto.items ?? [];
        const combos = dto.combos ?? [];
        if (!items.length && !combos.length) {
            throw new common_1.BadRequestException('El pedido debe incluir al menos un ?tem');
        }
        const totalLineas = items.reduce((s, i) => s + (i.cantidad ?? 1), 0) +
            combos.reduce((s, c) => s + (c.cantidad ?? 1), 0);
        if (totalLineas > 50) {
            throw new common_1.BadRequestException({
                error: 'LIMITE_ITEMS',
                message: 'El pedido no puede superar 50 ítems',
            });
        }
        if (dto.tipo === 'mesa' && !dto.mesa_id) {
            throw new common_1.BadRequestException({
                error: 'MESA_REQUERIDA',
                message: 'Un pedido de mesa requiere mesa_id',
            });
        }
        const claveIdempotencia = dto.idempotency_key?.trim() || null;
        const huellaIdempotencia = claveIdempotencia
            ? (0, pedidos_idempotencia_util_1.huellaIdempotenciaPedido)(dto)
            : null;
        if (claveIdempotencia) {
            const existente = await this.database.consultarUno(`SELECT pedido_id, huella FROM pedidos_idempotencia
         WHERE sucursal_id = $1 AND clave = $2`, [dto.sucursal_id, claveIdempotencia]);
            if (existente) {
                if (existente.huella && existente.huella !== huellaIdempotencia) {
                    throw new common_1.ConflictException({
                        error: 'IDEMPOTENCY_KEY_REUSED',
                        message: 'La clave idempotente ya se usó con otro contenido',
                    });
                }
                const pedido = await this.database.consultarUno(`SELECT id, numero_pedido, estado, total, seguimiento_token::text AS seguimiento_token
           FROM pedidos WHERE id = $1 AND sucursal_id = $2`, [existente.pedido_id, dto.sucursal_id]);
                if (!pedido) {
                    throw new common_1.ConflictException({
                        error: 'IDEMPOTENCY_KEY_REUSED',
                        message: 'La clave idempotente no corresponde a un pedido de esta sucursal',
                    });
                }
                return {
                    pedido_id: pedido.id,
                    numero_pedido: pedido.numero_pedido,
                    estado: pedido.estado,
                    total: Number(pedido.total),
                    seguimiento_token: pedido.seguimiento_token,
                    idempotente: true,
                };
            }
        }
        if (dto.requiere_factura) {
            if (!dto.nit_cliente?.trim() ||
                !dto.nombre_fiscal_cliente?.trim() ||
                !dto.email_cliente?.trim()) {
                throw new common_1.BadRequestException({
                    error: 'DATOS_FACTURA_REQUERIDOS',
                    message: 'Indica NIT, nombre fiscal y email para la factura',
                });
            }
        }
        if (dto.tipo === 'encargo') {
            if (combos.length > 0) {
                throw new common_1.BadRequestException({
                    error: 'ENCARGO_SIN_COMBOS',
                    message: 'Los pedidos de encargo no admiten combos',
                });
            }
            if (!opciones.soloEstimar || dto.fecha_entrega_deseada?.trim()) {
                this.validarFechaEncargo(dto.fecha_entrega_deseada);
            }
        }
        let catalogoCambios = [];
        const resultado = await this.database.enTransaccion(async (client) => {
            if (opciones.soloEstimar) {
            }
            else if (claveIdempotencia && huellaIdempotencia) {
                const clave = claveIdempotencia;
                const claveScope = `${dto.sucursal_id}:${clave}`;
                await client.query(`SELECT pg_advisory_xact_lock(hashtext($1::text))`, [
                    claveScope,
                ]);
                const existenteTx = await this.soporte.consultarUnoCliente(client, `SELECT pedido_id, huella FROM pedidos_idempotencia
           WHERE sucursal_id = $1 AND clave = $2`, [dto.sucursal_id, clave]);
                if (existenteTx) {
                    if (existenteTx.huella && existenteTx.huella !== huellaIdempotencia) {
                        throw new common_1.ConflictException({
                            error: 'IDEMPOTENCY_KEY_REUSED',
                            message: 'La clave idempotente ya se usó con otro contenido',
                        });
                    }
                    const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, numero_pedido, estado, total, seguimiento_token::text AS seguimiento_token
             FROM pedidos WHERE id = $1 AND sucursal_id = $2`, [existenteTx.pedido_id, dto.sucursal_id]);
                    if (pedido) {
                        return {
                            pedido_id: pedido.id,
                            numero_pedido: pedido.numero_pedido,
                            subtotal: 0,
                            costo_domicilio: 0,
                            total: Number(pedido.total),
                            estado: pedido.estado,
                            tiempo_estimado_minutos: 25,
                            factura_id: null,
                            seguimiento_token: pedido.seguimiento_token,
                            idempotente: true,
                        };
                    }
                }
            }
            const sucursal = await this.soporte.consultarUnoCliente(client, `SELECT id FROM sucursales WHERE id = $1 AND activa = true`, [dto.sucursal_id]);
            if (!sucursal) {
                throw new common_1.BadRequestException('Sucursal no disponible');
            }
            const horario = await this.soporte.consultarUnoCliente(client, `SELECT CASE
           WHEN NOT EXISTS (
             SELECT 1 FROM horarios_sucursal h
             WHERE h.sucursal_id = $1 AND h.activo = true
           ) THEN true
           ELSE EXISTS (
             SELECT 1 FROM horarios_sucursal h
             WHERE h.sucursal_id = $1 AND h.activo = true
               AND h.dia_semana = EXTRACT(DOW FROM NOW() AT TIME ZONE 'America/Bogota')::int
               AND (NOW() AT TIME ZONE 'America/Bogota')::time
                 BETWEEN h.hora_apertura AND h.hora_cierre
           )
         END AS activo`, [dto.sucursal_id]);
            const puedeForzarHorario = opciones.creadoPorStaff === true &&
                dto.forzar_fuera_horario === true &&
                (opciones.rol === 'admin' ||
                    opciones.rol === 'gerente' ||
                    opciones.rol === 'super_admin');
            if (!horario?.activo && !puedeForzarHorario) {
                throw new common_1.BadRequestException('RESTAURANTE_CERRADO');
            }
            let mesaNombre = null;
            if (dto.mesa_id) {
                const mesa = await this.soporte.consultarUnoCliente(client, opciones.soloEstimar
                    ? `SELECT id, nombre, estado_operativo FROM mesas
               WHERE id = $1 AND sucursal_id = $2 AND activa = true`
                    : `SELECT id, nombre, estado_operativo FROM mesas
               WHERE id = $1 AND sucursal_id = $2 AND activa = true FOR UPDATE`, [dto.mesa_id, dto.sucursal_id]);
                if (!mesa) {
                    throw new common_1.BadRequestException('MESA_NO_ENCONTRADA');
                }
                if (!opciones.creadoPorStaff && mesa.estado_operativo === 'reservada') {
                    throw new common_1.BadRequestException({
                        error: 'MESA_RESERVADA',
                        message: 'Esta mesa está reservada. Pide al personal que confirme tu llegada antes de pedir.',
                    });
                }
                mesaNombre = mesa.nombre;
                if (opciones.creadoPorStaff &&
                    opciones.usuarioId &&
                    this.soporte.esRolMesero(opciones.rol)) {
                    await this.soporte.assertMeseraPuedeTomarMesa(client, dto.sucursal_id, dto.mesa_id, opciones.usuarioId);
                }
            }
            let subtotal = 0;
            const lineasInventario = [];
            const lineasPreparadas = [];
            const combosPreparados = [];
            for (const item of items) {
                const producto = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio, precio_para_llevar, disponible, cocina_id,
                  costo_calculado, es_encargo
           FROM productos
           WHERE id = $1 AND sucursal_id = $2`, [item.producto_id, dto.sucursal_id]);
                if (!producto?.disponible) {
                    throw new common_1.BadRequestException('PRODUCTO_NO_DISPONIBLE');
                }
                if (dto.tipo === 'encargo' && !producto.es_encargo) {
                    throw new common_1.BadRequestException({
                        error: 'PRODUCTO_NO_ENCARGO',
                        message: 'Solo productos marcados como encargo en este pedido',
                    });
                }
                const precioUnit = this.soporte.precioVentaProducto(producto, dto.tipo);
                let lineaTotal = precioUnit * item.cantidad;
                const toppings = [];
                for (const t of item.toppings ?? []) {
                    const top = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio, costo_calculado FROM toppings
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [t.topping_id, dto.sucursal_id]);
                    if (!top)
                        throw new common_1.BadRequestException('TOPPING_NO_DISPONIBLE');
                    const p = Number(top.precio);
                    toppings.push({
                        id: top.id,
                        nombre: top.nombre,
                        precio: p,
                        costo: Number(top.costo_calculado ?? 0),
                    });
                    lineaTotal += p * item.cantidad;
                }
                const bebidas = [];
                for (const b of item.bebidas ?? []) {
                    const beb = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio, costo_calculado FROM bebidas
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [b.bebida_id, dto.sucursal_id]);
                    if (!beb)
                        throw new common_1.BadRequestException('BEBIDA_NO_DISPONIBLE');
                    const p = Number(beb.precio);
                    bebidas.push({
                        id: beb.id,
                        nombre: beb.nombre,
                        precio: p,
                        cantidad: b.cantidad,
                        costo: Number(beb.costo_calculado ?? 0),
                    });
                    lineaTotal += p * b.cantidad;
                }
                subtotal += lineaTotal;
                const costoExtras = toppings.reduce((s, t) => s + t.costo * item.cantidad, 0) +
                    bebidas.reduce((s, b) => s + b.costo * b.cantidad, 0);
                const costoProductoUnit = Number(producto.costo_calculado ?? 0);
                const costoUnitarioExtra = item.cantidad > 0 ? costoExtras / item.cantidad : 0;
                lineasPreparadas.push({
                    productoId: producto.id,
                    cantidad: item.cantidad,
                    precioUnitario: precioUnit,
                    precioVentaLinea: lineaTotal,
                    costoUnitario: costoProductoUnit + costoUnitarioExtra,
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
                    extras: [
                        ...toppings.map((t) => ({
                            tipo: 'topping',
                            id: t.id,
                            cantidad: item.cantidad,
                        })),
                        ...bebidas.map((b) => ({
                            tipo: 'bebida',
                            id: b.id,
                            cantidad: b.cantidad,
                        })),
                    ],
                });
            }
            for (const comboDto of combos) {
                const combo = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio_fijo, disponible FROM combos
           WHERE id = $1 AND sucursal_id = $2`, [comboDto.combo_id, dto.sucursal_id]);
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
           WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [productoItem.item_id, dto.sucursal_id]);
                if (!producto) {
                    throw new common_1.BadRequestException('PRODUCTO_NO_DISPONIBLE');
                }
                const productosCombo = comboItems.rows
                    .filter((ci) => ci.tipo_item === 'producto')
                    .map((ci) => ({ productoId: ci.item_id, cantidad: ci.cantidad }));
                const toppings = [];
                for (const t of comboDto.toppings ?? []) {
                    const top = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio, costo_calculado FROM toppings
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [t.topping_id, dto.sucursal_id]);
                    if (!top)
                        throw new common_1.BadRequestException('TOPPING_NO_DISPONIBLE');
                    toppings.push({
                        id: top.id,
                        nombre: top.nombre,
                        precio: Number(top.precio),
                        costo: Number(top.costo_calculado ?? 0),
                    });
                }
                const bebidas = [];
                for (const b of comboDto.bebidas ?? []) {
                    const beb = await this.soporte.consultarUnoCliente(client, `SELECT id, nombre, precio, costo_calculado FROM bebidas
             WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [b.bebida_id, dto.sucursal_id]);
                    if (!beb)
                        throw new common_1.BadRequestException('BEBIDA_NO_DISPONIBLE');
                    bebidas.push({
                        id: beb.id,
                        nombre: beb.nombre,
                        precio: Number(beb.precio),
                        cantidad: b.cantidad,
                        costo: Number(beb.costo_calculado ?? 0),
                    });
                }
                const extrasUnitario = toppings.reduce((s, t) => s + t.precio, 0) +
                    bebidas.reduce((s, b) => s + b.precio * b.cantidad, 0);
                subtotal += (precioFijo + extrasUnitario) * comboDto.cantidad;
                combosPreparados.push({
                    comboId: combo.id,
                    nombre: combo.nombre,
                    cantidad: comboDto.cantidad,
                    precioFijo,
                    productoPrincipalId: producto.id,
                    cocinaId: producto.cocina_id,
                    costoUnitario: 0,
                    productosCombo,
                    toppings,
                    bebidas,
                    extrasUnitario,
                });
                for (const pc of productosCombo) {
                    lineasInventario.push({
                        productoId: pc.productoId,
                        cantidad: pc.cantidad * comboDto.cantidad,
                        precioVentaLinea: 1,
                    });
                }
            }
            const costoDomicilio = dto.tipo === 'domicilio'
                ? (await this.zonas.calcularCostoDomicilio(client, dto.sucursal_id, dto.lat ?? null, dto.lng ?? null)).costo
                : 0;
            let descuentoPromo = 0;
            let promocionId = null;
            let motivoDescuento = null;
            if (dto.codigo_promocion?.trim()) {
                const promo = await this.promociones.resolverDescuentoPorCodigo(client, dto.sucursal_id, dto.codigo_promocion, subtotal);
                descuentoPromo = promo.monto;
                promocionId = promo.promocion_id;
                motivoDescuento = promo.motivo;
            }
            else {
                const auto = await this.promociones.resolverMejorAutomatica(client, dto.sucursal_id, subtotal);
                if (auto) {
                    descuentoPromo = auto.monto;
                    promocionId = auto.promocion_id;
                    motivoDescuento = auto.motivo;
                }
            }
            const total = subtotal + costoDomicilio - descuentoPromo;
            const iva = await this.facturacion.calcularIvaParaPedidoEnTransaccion(client, dto.sucursal_id, total);
            if (opciones.soloEstimar) {
                return {
                    subtotal,
                    costo_domicilio: costoDomicilio,
                    descuento: descuentoPromo,
                    motivo_descuento: motivoDescuento,
                    promocion_id: promocionId,
                    total,
                    iva_porcentaje: iva.iva_porcentaje,
                    iva_valor: iva.iva_valor,
                    lineas: lineasPreparadas.map((l) => ({
                        producto_id: l.productoId,
                        cantidad: l.cantidad,
                        precio_unitario: l.precioUnitario,
                        subtotal: l.precioVentaLinea,
                        nombre: lineasInventario.find((i) => i.productoId === l.productoId && i.cantidad === l.cantidad)?.nombreProducto ?? null,
                    })),
                    combos: combosPreparados.map((c) => ({
                        combo_id: c.comboId,
                        nombre: c.nombre,
                        cantidad: c.cantidad,
                        precio_unitario: c.precioFijo + c.extrasUnitario,
                        subtotal: (c.precioFijo + c.extrasUnitario) * c.cantidad,
                    })),
                    estimar: true,
                };
            }
            const estadoInicial = this.soporte.resolverEstadoInicial(dto, opciones.creadoPorStaff);
            const metodoPago = dto.metodo_pago ?? 'pendiente';
            const numeroPedido = await this.soporte.generarNumeroPedido(client, dto.sucursal_id);
            await client.query(`INSERT INTO dispositivos_cliente (device_id, ultimo_acceso, plataforma)
         VALUES ($1, now(), 'android')
         ON CONFLICT (device_id) DO UPDATE SET ultimo_acceso = now()`, [dto.device_id]);
            const authDisp = await client.query(`SELECT auth_uid::text AS auth_uid FROM dispositivos_cliente
         WHERE device_id = $1 AND anonimizado = false`, [dto.device_id]);
            const clienteAuthUid = authDisp.rows[0]?.auth_uid ?? null;
            const insertPedido = await client.query(`INSERT INTO pedidos (
           sucursal_id, mesa_id, device_id, numero_pedido, tipo, estado,
           cliente_nombre, cliente_telefono, direccion_entrega, lat, lng,
           metodo_pago, subtotal, costo_domicilio, descuento, motivo_descuento,
           promocion_id, total, requiere_factura,
           observaciones, tiempo_estimado_minutos, iva_porcentaje, iva_valor,
           cliente_auth_uid
         ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24::uuid)
         RETURNING id, seguimiento_token::text AS seguimiento_token`, [
                dto.sucursal_id,
                dto.mesa_id ?? null,
                dto.device_id,
                numeroPedido,
                dto.tipo,
                estadoInicial,
                dto.cliente_nombre ?? null,
                dto.cliente_telefono ?? null,
                dto.direccion_entrega ?? null,
                dto.lat ?? null,
                dto.lng ?? null,
                metodoPago,
                subtotal,
                costoDomicilio,
                descuentoPromo,
                motivoDescuento,
                promocionId,
                total,
                dto.requiere_factura ?? false,
                this.observacionesPedido(dto),
                25,
                iva.iva_porcentaje,
                iva.iva_valor,
                clienteAuthUid,
            ]);
            const pedidoId = insertPedido.rows[0].id;
            const seguimientoToken = insertPedido.rows[0].seguimiento_token;
            const opcionesStock = { incluirEmpaques: dto.tipo === 'domicilio' };
            const contextoStock = {
                origen: opciones.creadoPorStaff
                    ? 'staff'
                    : dto.tipo === 'domicilio'
                        ? 'domicilio'
                        : dto.tipo === 'para_llevar'
                            ? 'para_llevar'
                            : 'mesa',
                clienteNombre: dto.cliente_nombre,
                mesaNombre,
            };
            await this.inventario.validarStockDisponible(client, dto.sucursal_id, lineasInventario, opcionesStock, contextoStock);
            const debeDescontarAhora = (0, pedido_estados_1.estadoActivaCocina)(estadoInicial);
            let costosRecalculados = new Map();
            if (debeDescontarAhora) {
                const stock = await this.inventario.descontarStockPedido(client, dto.sucursal_id, pedidoId, lineasInventario, opcionesStock);
                costosRecalculados = stock.costos;
                catalogoCambios.push(...stock.catalogo);
                await client.query(`UPDATE pedidos SET stock_descontado = true WHERE id = $1`, [pedidoId]);
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
                    dto.sucursal_id,
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
                    const costoExtras = combo.toppings.reduce((s, t) => s + t.costo, 0) +
                        combo.bebidas.reduce((s, b) => s + b.costo * b.cantidad, 0);
                    const costoUnit = combo.costoUnitario + costoExtras;
                    const precioVenta = combo.precioFijo + combo.extrasUnitario;
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
                    for (const t of combo.toppings) {
                        await client.query(`INSERT INTO pedido_item_toppings (pedido_item_id, topping_id, nombre_topping, precio_topping)
               VALUES ($1,$2,$3,$4)`, [itemId, t.id, t.nombre, t.precio]);
                    }
                    for (const b of combo.bebidas) {
                        await client.query(`INSERT INTO pedido_item_bebidas (pedido_item_id, bebida_id, nombre_bebida, precio_bebida, cantidad)
               VALUES ($1,$2,$3,$4,$5)`, [itemId, b.id, b.nombre, b.precio, b.cantidad]);
                    }
                    const margenPct = precioVenta > 0
                        ? ((precioVenta - costoUnit) / precioVenta) * 100
                        : 0;
                    await client.query(`INSERT INTO margenes_venta (
               pedido_id, pedido_item_id, sucursal_id,
               precio_venta, costo_al_momento, margen_porcentaje
             ) VALUES ($1,$2,$3,$4,$5,$6)`, [
                        pedidoId,
                        itemId,
                        dto.sucursal_id,
                        precioVenta,
                        costoUnit,
                        margenPct,
                    ]);
                }
            }
            const metodoCajaRef = dto.pagos?.[0]?.metodo_pago ?? metodoPago;
            const registrarCajaAlCrear = this.cajaAuditoria.debeRegistrarVentaAlCrear(estadoInicial, dto.tipo, dto.mesa_id, metodoCajaRef);
            if (dto.pagos?.length) {
                const sumaPagos = dto.pagos.reduce((s, p) => s + p.monto, 0);
                if (Math.abs(sumaPagos - total) > 0.01) {
                    throw new common_1.BadRequestException({
                        error: 'PAGOS_NO_COINCIDEN',
                        message: `La suma de pagos (${sumaPagos}) debe ser ${total}`,
                    });
                }
                const propinaCaja = dto.propina ?? 0;
                for (const pago of dto.pagos) {
                    if (registrarCajaAlCrear) {
                        await this.cajaAuditoria.registrarVentaEnCaja(client, dto.sucursal_id, pedidoId, pago.monto, pago.metodo_pago, {
                            exigirCaja: true,
                            descripcion: `Venta ${numeroPedido}`,
                            usuarioId: opciones.usuarioId,
                        });
                    }
                    await client.query(`INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, referencia
             ) VALUES ($1,$2,$3,$4,$5,$6)`, [
                        dto.sucursal_id,
                        pedidoId,
                        pago.monto,
                        total > 0 ? propinaCaja * (pago.monto / total) : 0,
                        pago.metodo_pago,
                        'Cobro al crear pedido',
                    ]);
                }
                await client.query(`UPDATE pedidos SET monto_pagado = $2, propina_acumulada = $3, metodo_pago = $4 WHERE id = $1`, [pedidoId, total, propinaCaja, dto.pagos[0].metodo_pago]);
            }
            else if (dto.propina != null && dto.propina > 0) {
                await client.query(`UPDATE pedidos SET propina_acumulada = $2 WHERE id = $1`, [pedidoId, dto.propina]);
            }
            else if (registrarCajaAlCrear) {
                await this.cajaAuditoria.registrarVentaEnCaja(client, dto.sucursal_id, pedidoId, total, metodoPago, {
                    exigirCaja: true,
                    descripcion: `Venta ${numeroPedido}`,
                    usuarioId: opciones.usuarioId,
                });
                await client.query(`UPDATE pedidos SET monto_pagado = $2, metodo_pago = $3 WHERE id = $1`, [pedidoId, total, metodoPago]);
            }
            await this.cajaAuditoria.registrarAuditoria(client, dto.sucursal_id, pedidoId, {
                numero_pedido: numeroPedido,
                tipo: dto.tipo,
                total,
                subtotal,
                costo_domicilio: costoDomicilio,
                items: items.length + combos.length,
                device_id: dto.device_id,
            });
            await client.query(`INSERT INTO estados_pedido_historial (pedido_id, estado_anterior, estado_nuevo)
         VALUES ($1, NULL, $2)`, [pedidoId, estadoInicial]);
            if (dto.mesa_id) {
                await this.cuentaMesa.marcarEstadoOperativoMesa(client, dto.mesa_id, dto.sucursal_id, 'ocupada');
            }
            if (opciones.creadoPorStaff &&
                opciones.usuarioId &&
                dto.mesa_id &&
                estadoInicial === 'en_cocina' &&
                this.soporte.esRolMesero(opciones.rol)) {
                await client.query(`UPDATE pedidos SET mesera_id = $1, aprobado_at = now() WHERE id = $2`, [opciones.usuarioId, pedidoId]);
                await this.soporte.asignarMeseraAMesa(client, dto.sucursal_id, dto.mesa_id, opciones.usuarioId);
            }
            let facturaId = null;
            if (dto.requiere_factura) {
                facturaId = await this.facturacion.crearBorradorEnTransaccion(client, {
                    sucursalId: dto.sucursal_id,
                    pedidoId,
                    total,
                    nitCliente: dto.nit_cliente.trim(),
                    nombreFiscalCliente: dto.nombre_fiscal_cliente.trim(),
                    emailCliente: dto.email_cliente.trim(),
                });
            }
            if (claveIdempotencia && huellaIdempotencia) {
                await client.query(`INSERT INTO pedidos_idempotencia (sucursal_id, clave, huella, pedido_id)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (sucursal_id, clave) DO NOTHING`, [dto.sucursal_id, claveIdempotencia, huellaIdempotencia, pedidoId]);
            }
            return {
                pedido_id: pedidoId,
                numero_pedido: numeroPedido,
                subtotal,
                costo_domicilio: costoDomicilio,
                total,
                estado: estadoInicial,
                tiempo_estimado_minutos: 25,
                factura_id: facturaId,
                seguimiento_token: seguimientoToken,
            };
        });
        if (opciones.soloEstimar || resultado.estimar) {
            return resultado;
        }
        const creado = resultado;
        const idempotente = creado.idempotente === true;
        if (!idempotente) {
            this.soporte.notificarPedidoRealtime(dto.sucursal_id, creado.pedido_id, creado.estado, creado.numero_pedido, { mesaId: dto.mesa_id ?? null });
            if (dto.mesa_id) {
                void this.realtime.mesasActualizadas(dto.sucursal_id);
            }
            this.soporte.notificarCatalogoDisponibilidad(dto.sucursal_id, catalogoCambios);
            if ((0, pedido_estados_1.estadoActivaCocina)(creado.estado)) {
                void this.soporte.notificarCocinasPorPedido(creado.pedido_id, dto.sucursal_id);
            }
            if (this.cajaAuditoria.debeRegistrarVentaAlCrear(creado.estado, dto.tipo, dto.mesa_id, dto.metodo_pago ?? 'pendiente')) {
                void this.realtime.cajaMovimiento(dto.sucursal_id, {
                    pedido_id: creado.pedido_id,
                });
            }
        }
        return resultado;
    }
    validarFechaEncargo(fecha) {
        if (!fecha?.trim()) {
            throw new common_1.BadRequestException({
                error: 'FECHA_ENCARGO_REQUERIDA',
                message: 'Indica la fecha deseada de entrega del encargo',
            });
        }
        const entrega = new Date(`${fecha.trim()}T12:00:00`);
        if (Number.isNaN(entrega.getTime())) {
            throw new common_1.BadRequestException({
                error: 'FECHA_ENCARGO_INVALIDA',
                message: 'Fecha de entrega no válida',
            });
        }
        const minima = new Date();
        minima.setHours(0, 0, 0, 0);
        minima.setDate(minima.getDate() + DIAS_ANTICIPACION_ENCARGO_MIN);
        if (entrega < minima) {
            throw new common_1.BadRequestException({
                error: 'FECHA_ENCARGO_MUY_CERCANA',
                message: `Los encargos requieren al menos ${DIAS_ANTICIPACION_ENCARGO_MIN} días de anticipación`,
            });
        }
    }
    observacionesPedido(dto) {
        const base = dto.observaciones?.trim() ?? '';
        if (dto.tipo !== 'encargo' || !dto.fecha_entrega_deseada?.trim()) {
            return base || null;
        }
        const prefijo = `[Encargo entrega: ${dto.fecha_entrega_deseada.trim()}]`;
        return base ? `${prefijo} ${base}` : prefijo;
    }
};
exports.PedidosCrearService = PedidosCrearService;
exports.PedidosCrearService = PedidosCrearService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        facturacion_service_1.FacturacionService,
        zonas_service_1.ZonasService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        costeo_service_1.CosteoService,
        promociones_service_1.PromocionesService,
        pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
        pedidos_soporte_service_1.PedidosSoporteService,
        pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
        pedidos_inventario_service_1.PedidosInventarioService])
], PedidosCrearService);
//# sourceMappingURL=pedidos-crear.service.js.map