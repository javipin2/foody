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
exports.PedidosPagosService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const pedidos_caja_auditoria_service_1 = require("./pedidos-caja-auditoria.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
const sql_venta_linea_item_1 = require("./sql-venta-linea-item");
const pedido_estados_1 = require("./pedido-estados");
let PedidosPagosService = class PedidosPagosService {
    database;
    cajaAuditoria;
    cuentaMesa;
    realtime;
    constructor(database, cajaAuditoria, cuentaMesa, realtime) {
        this.database = database;
        this.cajaAuditoria = cajaAuditoria;
        this.cuentaMesa = cuentaMesa;
        this.realtime = realtime;
    }
    async cobrarCuentaMesa(sucursalId, mesaId, usuarioId, dto = {}, rol) {
        const cached = await this.leerCobroIdempotente(dto.idempotency_key);
        if (cached)
            return cached;
        const ctx = { usuarioId, rol };
        const result = (await this.database.enTransaccion(async (client) => {
            const again = await this.leerCobroIdempotenteEnTx(client, dto.idempotency_key);
            if (again)
                return again;
            const mesa = await this.consultarUnoCliente(client, `SELECT id, nombre, mesa_grupo_id FROM mesas
         WHERE id = $1 AND sucursal_id = $2 AND activa = true`, [mesaId, sucursalId]);
            if (!mesa)
                throw new common_1.NotFoundException('Mesa no encontrada');
            const mesaIds = await this.resolverMesasGrupo(client, sucursalId, mesa);
            const pedidos = await this.obtenerPedidosActivos(client, sucursalId, mesaIds);
            if (!pedidos.length) {
                throw new common_1.BadRequestException({
                    error: 'MESA_SIN_PEDIDOS',
                    message: 'No hay pedidos activos en esta mesa',
                });
            }
            let itemIds = null;
            if (dto.item_ids?.length) {
                itemIds = await this.validarItemsSplit(client, dto.item_ids, pedidos.map((p) => p.id));
            }
            const montosItems = itemIds?.length
                ? await this.calcularMontosItems(client, itemIds)
                : null;
            if (montosItems)
                this.validarSaldoItems(pedidos, montosItems);
            const montoObjetivo = this.calcularMontoObjetivo(dto, pedidos, montosItems);
            const pagos = this.normalizarPagos(dto, montoObjetivo);
            const montoCobrar = pagos.reduce((s, p) => s + p.monto, 0);
            const propina = dto.propina ?? 0;
            const montosPorPedido = await this.distribuirMonto(pedidos, montoCobrar, montosItems);
            const saldoCajaPorPedido = new Map(pedidos.map((pedido) => [
                pedido.id,
                montosPorPedido.get(pedido.id) ?? 0,
            ]));
            const cobrados = [];
            let totalCobrado = 0;
            for (const p of pedidos) {
                const asignado = montosPorPedido.get(p.id) ?? 0;
                if (asignado <= 0)
                    continue;
                totalCobrado += asignado;
                const nuevoPagado = Number(p.monto_pagado) + asignado;
                const totalPedido = Number(p.total);
                const quedaPagado = nuevoPagado >= totalPedido - 0.01;
                const fraccionPropina = montoCobrar > 0 ? propina * (asignado / montoCobrar) : 0;
                if (quedaPagado) {
                    await this.exigirCocinaCompletaParaPagado(client, p.id, ctx, dto.motivo);
                    const anterior = p.estado;
                    const metodoPrincipal = pagos[0]?.metodo_pago ?? 'efectivo';
                    await client.query(`UPDATE pedidos
             SET estado = 'pagado', metodo_pago = $2,
                 monto_pagado = $3, propina_acumulada = propina_acumulada + $4
             WHERE id = $1`, [p.id, metodoPrincipal, totalPedido, fraccionPropina]);
                    await client.query(`INSERT INTO estados_pedido_historial
               (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
             VALUES ($1, $2, 'pagado', $3, $4)`, [
                        p.id,
                        anterior,
                        usuarioId,
                        dto.motivo?.trim() || 'Cobro cuenta mesa',
                    ]);
                    cobrados.push({
                        id: p.id,
                        numero_pedido: p.numero_pedido,
                        total: totalPedido,
                    });
                }
                else {
                    await client.query(`UPDATE pedidos
             SET monto_pagado = $2,
                 propina_acumulada = propina_acumulada + $3,
                 estado = CASE
                   WHEN estado NOT IN ('pagando', 'pagado', 'cancelado', 'rechazado')
                   THEN 'pagando' ELSE estado END
             WHERE id = $1`, [p.id, nuevoPagado, fraccionPropina]);
                    if (!['pagando', 'pagado', 'cancelado', 'rechazado'].includes(p.estado)) {
                        await client.query(`INSERT INTO estados_pedido_historial
                 (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
               VALUES ($1, $2, 'pagando', $3, $4)`, [
                            p.id,
                            p.estado,
                            usuarioId,
                            dto.motivo?.trim() || 'Abono cuenta mesa',
                        ]);
                    }
                }
            }
            if (itemIds?.length) {
                for (const itemId of itemIds) {
                    await client.query(`UPDATE pedido_items SET estado_cobro = 'cobrado' WHERE id = $1`, [itemId]);
                }
            }
            const pedidoRef = cobrados[0]?.id ??
                pedidos.find((p) => (montosPorPedido.get(p.id) ?? 0) > 0)?.id ??
                pedidos[0]?.id;
            for (const pago of pagos) {
                const pagoRow = await client.query(`INSERT INTO pagos_pedido (
             sucursal_id, pedido_id, mesa_id, monto, propina, metodo_pago, usuario_id, referencia
           ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
           RETURNING id`, [
                    sucursalId,
                    pedidoRef ?? null,
                    mesaId,
                    pago.monto,
                    montoCobrar > 0 ? propina * (pago.monto / montoCobrar) : 0,
                    pago.metodo_pago,
                    usuarioId,
                    dto.motivo?.trim() || null,
                ]);
                if (itemIds?.length && pagos.length === 1) {
                    for (const itemId of itemIds) {
                        await client.query(`INSERT INTO pago_pedido_items (pago_id, pedido_item_id) VALUES ($1,$2)`, [pagoRow.rows[0].id, itemId]);
                    }
                }
                let restantePago = pago.monto;
                for (const pedido of pedidos) {
                    const saldoPedido = saldoCajaPorPedido.get(pedido.id) ?? 0;
                    const asignado = Math.min(restantePago, saldoPedido);
                    if (asignado <= 0.01)
                        continue;
                    const registrado = await this.cajaAuditoria.registrarVentaEnCaja(client, sucursalId, pedido.id, asignado, pago.metodo_pago, {
                        exigirCaja: true,
                        descripcion: `Cobro mesa ${mesa.nombre}`,
                    });
                    if (!registrado) {
                        throw new common_1.BadRequestException({
                            error: 'MOVIMIENTO_CAJA_NO_REGISTRADO',
                            message: `No se pudo registrar en Caja el pago del pedido ${pedido.numero_pedido}`,
                        });
                    }
                    saldoCajaPorPedido.set(pedido.id, saldoPedido - asignado);
                    restantePago -= asignado;
                }
                if (restantePago > 0.01) {
                    throw new common_1.BadRequestException({
                        error: 'DISTRIBUCION_COBRO_INVALIDA',
                        message: 'No se pudo distribuir el pago entre los pedidos de la mesa',
                    });
                }
            }
            const pedidosPost = await this.obtenerPedidosActivos(client, sucursalId, mesaIds);
            const saldoRestante = this.saldoPendientePedidos(pedidosPost);
            if (saldoRestante <= 0.01) {
                await this.liberarMesasGrupo(client, mesaIds, sucursalId);
            }
            await this.cajaAuditoria.registrarAuditoriaCobroMesa(client, sucursalId, mesa.id, usuarioId, {
                mesa_nombre: mesa.nombre,
                pagos,
                propina,
                total_cobrado: totalCobrado,
                item_ids: itemIds,
                saldo_restante: saldoRestante,
                pedidos: cobrados,
            });
            const payload = {
                mesa_id: mesa.id,
                mesa_nombre: mesa.nombre,
                total_cobrado: totalCobrado,
                propina,
                pagos,
                saldo_restante: saldoRestante,
                pedidos_cobrados: cobrados,
                parcial: saldoRestante > 0.01,
            };
            await this.guardarCobroIdempotente(client, dto.idempotency_key, sucursalId, payload);
            return payload;
        }));
        for (const p of result.pedidos_cobrados ?? []) {
            void this.realtime.pedidoActualizado({
                pedido_id: p.id,
                sucursal_id: sucursalId,
                estado: 'pagado',
                numero_pedido: p.numero_pedido,
            });
        }
        void this.realtime.mesasActualizadas(sucursalId);
        void this.realtime.cajaMovimiento(sucursalId, {
            mesa_id: result.mesa_id,
            total_cobrado: result.total_cobrado,
        });
        return result;
    }
    async cobrarPedidoCaja(sucursalId, pedidoId, usuarioId, dto = {}, rol) {
        const cached = await this.leerCobroIdempotente(dto.idempotency_key);
        if (cached)
            return cached;
        const ctx = { usuarioId, rol };
        const result = (await this.database.enTransaccion(async (client) => {
            const again = await this.leerCobroIdempotenteEnTx(client, dto.idempotency_key);
            if (again)
                return again;
            const pedido = await this.consultarUnoCliente(client, `SELECT id, numero_pedido, estado, total, monto_pagado, metodo_pago, mesa_id
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (['cancelado', 'rechazado', 'pagado'].includes(pedido.estado)) {
                throw new common_1.ConflictException({
                    error: 'PEDIDO_CERRADO',
                    message: 'El pedido ya está cerrado o pagado',
                });
            }
            const saldo = Math.max(0, Number(pedido.total) - Number(pedido.monto_pagado));
            const montoObjetivo = dto.monto_parcial != null ? Math.min(dto.monto_parcial, saldo) : saldo;
            if (montoObjetivo <= 0) {
                throw new common_1.BadRequestException({
                    error: 'SIN_SALDO',
                    message: 'No hay saldo pendiente en este pedido',
                });
            }
            const pagos = this.normalizarPagos(dto, montoObjetivo);
            const montoCobrar = pagos.reduce((s, p) => s + p.monto, 0);
            const propina = dto.propina ?? 0;
            const nuevoPagado = Number(pedido.monto_pagado) + montoCobrar;
            const totalPedido = Number(pedido.total);
            const quedaPagado = nuevoPagado >= totalPedido - 0.01;
            const anterior = pedido.estado;
            if (quedaPagado) {
                await this.exigirCocinaCompletaParaPagado(client, pedidoId, ctx, dto.motivo);
                await client.query(`UPDATE pedidos
           SET estado = 'pagado', metodo_pago = $2,
               monto_pagado = $3, propina_acumulada = propina_acumulada + $4
           WHERE id = $1`, [pedidoId, pagos[0]?.metodo_pago ?? 'efectivo', totalPedido, propina]);
                await client.query(`INSERT INTO estados_pedido_historial
             (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
           VALUES ($1, $2, 'pagado', $3, $4)`, [
                    pedidoId,
                    anterior,
                    usuarioId,
                    dto.motivo?.trim() || 'Cobro en caja',
                ]);
            }
            else {
                await client.query(`UPDATE pedidos
           SET monto_pagado = $2,
               propina_acumulada = propina_acumulada + $3,
               estado = CASE
                 WHEN estado NOT IN ('pagando', 'pagado', 'cancelado', 'rechazado')
                 THEN 'pagando' ELSE estado END
           WHERE id = $1`, [pedidoId, nuevoPagado, propina]);
                if (!['pagando', 'pagado', 'cancelado', 'rechazado'].includes(anterior)) {
                    await client.query(`INSERT INTO estados_pedido_historial
               (pedido_id, estado_anterior, estado_nuevo, usuario_id, motivo)
             VALUES ($1, $2, 'pagando', $3, $4)`, [
                        pedidoId,
                        anterior,
                        usuarioId,
                        dto.motivo?.trim() || 'Abono en caja',
                    ]);
                }
            }
            for (const pago of pagos) {
                await client.query(`INSERT INTO pagos_pedido (
             sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
           ) VALUES ($1,$2,$3,$4,$5,$6,$7)`, [
                    sucursalId,
                    pedidoId,
                    pago.monto,
                    montoCobrar > 0 ? propina * (pago.monto / montoCobrar) : 0,
                    pago.metodo_pago,
                    usuarioId,
                    dto.motivo?.trim() || null,
                ]);
                await this.cajaAuditoria.registrarVentaEnCaja(client, sucursalId, pedidoId, pago.monto, pago.metodo_pago, {
                    exigirCaja: true,
                    descripcion: `Cobro pedido ${pedido.numero_pedido}`,
                });
            }
            const saldoRestante = Math.max(0, totalPedido - nuevoPagado);
            if (quedaPagado && pedido.mesa_id) {
                await this.cuentaMesa.liberarMesaSiSinPedidosActivos(client, pedido.mesa_id, sucursalId);
            }
            const payload = {
                pedido_id: pedidoId,
                numero_pedido: pedido.numero_pedido,
                total_cobrado: montoCobrar,
                propina,
                pagos,
                saldo_restante: saldoRestante,
                parcial: saldoRestante > 0.01,
                pagado: quedaPagado,
                mesa_id: pedido.mesa_id,
            };
            await this.guardarCobroIdempotente(client, dto.idempotency_key, sucursalId, payload);
            return payload;
        }));
        if (result.pagado && result.mesa_id) {
            void this.realtime.mesasActualizadas(sucursalId);
        }
        void this.realtime.pedidoActualizado({
            pedido_id: result.pedido_id,
            sucursal_id: sucursalId,
            estado: result.pagado ? 'pagado' : 'pagando',
            numero_pedido: result.numero_pedido,
        });
        void this.realtime.cajaMovimiento(sucursalId, {
            pedido_id: result.pedido_id,
            total_cobrado: result.total_cobrado,
        });
        return result;
    }
    async exigirCocinaCompletaParaPagado(client, pedidoId, ctx, motivo) {
        const completa = await (0, pedido_estados_1.pedidoCocinaCompleta)(client, pedidoId);
        if (completa)
            return;
        if ((0, pedido_estados_1.puedeForzarPagadoSinCocinaCompleta)(ctx.rol, motivo))
            return;
        throw new common_1.BadRequestException({
            error: 'COCINA_INCOMPLETA_PARA_PAGADO',
            message: 'Hay ítems aún en cocina. Registra un abono o espera cocina completa. Admin/gerente puede cerrar con motivo.',
        });
    }
    async leerCobroIdempotente(clave) {
        const k = clave?.trim();
        if (!k)
            return null;
        const prev = await this.database.consultarUno(`SELECT resultado FROM cobros_idempotencia WHERE clave = $1`, [k]);
        if (prev?.resultado == null)
            return null;
        return prev.resultado;
    }
    async leerCobroIdempotenteEnTx(client, clave) {
        const k = clave?.trim();
        if (!k)
            return null;
        const prev = await client.query(`SELECT resultado FROM cobros_idempotencia WHERE clave = $1 FOR UPDATE`, [k]);
        if (prev.rows[0]?.resultado == null)
            return null;
        return prev.rows[0].resultado;
    }
    async guardarCobroIdempotente(client, clave, sucursalId, payload) {
        const k = clave?.trim();
        if (!k)
            return;
        await client.query(`INSERT INTO cobros_idempotencia (clave, sucursal_id, resultado)
       VALUES ($1, $2, $3::jsonb)
       ON CONFLICT (clave) DO NOTHING`, [k, sucursalId, JSON.stringify(payload)]);
    }
    calcularMontoObjetivo(dto, pedidos, montosItems) {
        if (montosItems) {
            return [...montosItems.values()].reduce((sum, monto) => sum + monto, 0);
        }
        if (dto.monto_parcial != null) {
            const saldo = this.saldoPendientePedidos(pedidos);
            if (dto.monto_parcial > saldo + 0.01) {
                throw new common_1.BadRequestException({
                    error: 'MONTO_PARCIAL_EXCESO',
                    message: `El abono supera el saldo (${saldo})`,
                });
            }
            return dto.monto_parcial;
        }
        return this.saldoPendientePedidos(pedidos);
    }
    normalizarPagos(dto, montoObjetivo) {
        if (dto.pagos?.length) {
            const suma = dto.pagos.reduce((s, p) => s + p.monto, 0);
            if (Math.abs(suma - montoObjetivo) > 0.01) {
                throw new common_1.BadRequestException({
                    error: 'PAGOS_NO_COINCIDEN',
                    message: `La suma de pagos (${suma}) debe ser ${montoObjetivo}`,
                });
            }
            return dto.pagos;
        }
        const metodo = dto.metodo_pago ?? 'efectivo';
        if (!['efectivo', 'tarjeta', 'transferencia', 'nequi'].includes(metodo)) {
            throw new common_1.BadRequestException({
                error: 'METODO_PAGO_INVALIDO',
                message: 'Indica un método de pago válido',
            });
        }
        return [{ metodo_pago: metodo, monto: montoObjetivo }];
    }
    saldoPendientePedidos(pedidos) {
        return pedidos.reduce((s, p) => s + Math.max(0, Number(p.total) - Number(p.monto_pagado)), 0);
    }
    async resolverMesasGrupo(client, sucursalId, mesa) {
        const grupoId = mesa.mesa_grupo_id ?? mesa.id;
        const filas = await client.query(`SELECT id FROM mesas
       WHERE sucursal_id = $2 AND activa = true
         AND (id = $1 OR mesa_grupo_id = $1)`, [grupoId, sucursalId]);
        return filas.rows.map((r) => r.id);
    }
    async obtenerPedidosActivos(client, sucursalId, mesaIds) {
        const res = await client.query(`SELECT id, numero_pedido, estado, total, monto_pagado, metodo_pago
       FROM pedidos
       WHERE sucursal_id = $1 AND mesa_id = ANY($2::uuid[])
         AND (${pedido_estados_1.SQL_WHERE_PEDIDO_BLOQUEA_MESA})
       ORDER BY created_at ASC
       FOR UPDATE`, [sucursalId, mesaIds]);
        return res.rows;
    }
    async validarItemsSplit(client, itemIds, pedidoIds) {
        const res = await client.query(`SELECT id FROM pedido_items
       WHERE id = ANY($1::uuid[]) AND pedido_id = ANY($2::uuid[])
         AND estado_cobro = 'pendiente'`, [itemIds, pedidoIds]);
        if (res.rows.length !== itemIds.length) {
            throw new common_1.BadRequestException({
                error: 'ITEMS_INVALIDOS',
                message: 'Algunos ítems no pertenecen a la mesa o ya fueron cobrados',
            });
        }
        return itemIds;
    }
    async calcularMontosItems(client, itemIds) {
        const res = await client.query(`SELECT pi.pedido_id,
              SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}) AS subtotal_items,
              p.subtotal AS subtotal_pedido,
              p.descuento
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       WHERE pi.id = ANY($1::uuid[])
       GROUP BY pi.pedido_id, p.subtotal, p.descuento`, [itemIds]);
        const montos = new Map();
        for (const fila of res.rows) {
            const bruto = Number(fila.subtotal_items ?? 0);
            const subtotal = Number(fila.subtotal_pedido ?? 0);
            const descuento = Number(fila.descuento ?? 0);
            const descuentoAsignado = subtotal > 0 ? Math.min(descuento, (bruto / subtotal) * descuento) : 0;
            montos.set(fila.pedido_id, Math.max(0, Math.round((bruto - descuentoAsignado) * 100) / 100));
        }
        return montos;
    }
    validarSaldoItems(pedidos, montosItems) {
        const pedidosPorId = new Map(pedidos.map((pedido) => [pedido.id, pedido]));
        for (const [pedidoId, montoItem] of montosItems) {
            const pedido = pedidosPorId.get(pedidoId);
            if (!pedido)
                continue;
            const saldo = Math.max(0, Number(pedido.total) - Number(pedido.monto_pagado));
            if (montoItem > saldo + 0.01) {
                throw new common_1.BadRequestException({
                    error: 'ITEMS_EXCEDEN_SALDO',
                    message: `Los ítems del pedido ${pedido.numero_pedido} superan su saldo (${saldo})`,
                });
            }
        }
    }
    distribuirMonto(pedidos, monto, montosItems) {
        const montosPorPedido = new Map();
        if (montosItems) {
            return new Map(montosItems);
        }
        let restante = monto;
        for (const p of pedidos) {
            const saldo = Math.max(0, Number(p.total) - Number(p.monto_pagado));
            const asignar = Math.min(saldo, restante);
            if (asignar > 0) {
                montosPorPedido.set(p.id, asignar);
                restante -= asignar;
            }
            if (restante <= 0.01)
                break;
        }
        return montosPorPedido;
    }
    async liberarMesasGrupo(client, mesaIds, sucursalId) {
        for (const mesaId of mesaIds) {
            const activo = await this.consultarUnoCliente(client, `SELECT COUNT(*)::int AS n FROM pedidos
         WHERE mesa_id = $1 AND sucursal_id = $2
           AND (${pedido_estados_1.SQL_WHERE_PEDIDO_BLOQUEA_MESA})`, [mesaId, sucursalId]);
            if ((activo?.n ?? 0) === 0) {
                await client.query(`UPDATE mesas
           SET mesera_asignada_id = NULL, mesera_asignada_at = NULL,
               estado_operativo = 'libre', mesa_grupo_id = NULL
           WHERE id = $1 AND sucursal_id = $2`, [mesaId, sucursalId]);
            }
        }
    }
    async consultarUnoCliente(client, sql, parametros) {
        const res = await client.query(sql, parametros);
        return res.rows[0] ?? null;
    }
};
exports.PedidosPagosService = PedidosPagosService;
exports.PedidosPagosService = PedidosPagosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
        pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
        realtime_broadcast_service_1.RealtimeBroadcastService])
], PedidosPagosService);
//# sourceMappingURL=pedidos-pagos.service.js.map