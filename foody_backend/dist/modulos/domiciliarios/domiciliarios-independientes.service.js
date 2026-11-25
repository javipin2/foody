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
exports.DomiciliariosIndependientesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const pedidos_caja_auditoria_service_1 = require("../pedidos/pedidos-caja-auditoria.service");
const pedidos_estado_command_service_1 = require("../pedidos/pedidos-estado-command.service");
const pedidos_soporte_service_1 = require("../pedidos/pedidos-soporte.service");
const dispatch_service_1 = require("./dispatch.service");
const cobro_domicilio_util_1 = require("./cobro-domicilio.util");
let DomiciliariosIndependientesService = class DomiciliariosIndependientesService {
    database;
    dispatch;
    alertasRiesgo;
    realtime;
    cajaAuditoria;
    pedidosEstadoCommand;
    pedidosSoporte;
    constructor(database, dispatch, alertasRiesgo, realtime, cajaAuditoria, pedidosEstadoCommand, pedidosSoporte) {
        this.database = database;
        this.dispatch = dispatch;
        this.alertasRiesgo = alertasRiesgo;
        this.realtime = realtime;
        this.cajaAuditoria = cajaAuditoria;
        this.pedidosEstadoCommand = pedidosEstadoCommand;
        this.pedidosSoporte = pedidosSoporte;
    }
    async iniciarSesion(domiciliarioId, dto) {
        const dom = await this.obtenerActivo(domiciliarioId);
        await this.database.consultar(`UPDATE domiciliarios_sesiones
       SET activa = false, cerrada_at = now(), disponible = false
       WHERE domiciliario_id = $1 AND activa = true`, [domiciliarioId]);
        const ciudadId = dto.ciudad_id ?? dom.ciudad_id;
        const insert = await this.database.consultarUno(`INSERT INTO domiciliarios_sesiones (
         domiciliario_id, lat_actual, lng_actual, ciudad_id, disponible, activa
       ) VALUES ($1,$2,$3,$4,true,true)
       RETURNING id`, [domiciliarioId, dto.lat, dto.lng, ciudadId]);
        return { sesion_id: insert?.id, disponible: true };
    }
    async actualizarUbicacion(domiciliarioId, dto) {
        const sesion = await this.obtenerSesionActiva(domiciliarioId);
        await this.database.consultar(`UPDATE domiciliarios_sesiones
       SET lat_actual = $1, lng_actual = $2
       WHERE id = $3`, [dto.lat, dto.lng, sesion.id]);
        const params = [domiciliarioId];
        let filtroPedido = '';
        if (dto.pedido_id) {
            filtroPedido = ' AND ad.pedido_id = $2';
            params.push(dto.pedido_id);
        }
        const asignacion = await this.database.consultarUno(`SELECT ad.id, ad.pedido_id
       FROM asignaciones_domicilio ad
       WHERE ad.domiciliario_independiente_id = $1
         AND ad.estado = 'en_camino'${filtroPedido}
       ORDER BY ad.asignado_at DESC
       LIMIT 1`, params);
        if (asignacion) {
            await this.database.consultar(`INSERT INTO domiciliarios_ubicaciones_historial (asignacion_id, lat, lng)
         VALUES ($1, $2, $3)`, [asignacion.id, dto.lat, dto.lng]);
            this.pedidosSoporte.emitirUbicacionRepartidor(asignacion.pedido_id, {
                repartidor_lat: dto.lat,
                repartidor_lng: dto.lng,
            });
        }
        return { ok: true, registrado: !!asignacion };
    }
    async cerrarSesion(domiciliarioId) {
        await this.database.consultar(`UPDATE domiciliarios_sesiones
       SET activa = false, disponible = false, cerrada_at = now()
       WHERE domiciliario_id = $1 AND activa = true`, [domiciliarioId]);
        return { ok: true };
    }
    async estadoSesion(domiciliarioId) {
        const sesion = await this.database.consultarUno(`SELECT activa, disponible FROM domiciliarios_sesiones
       WHERE domiciliario_id = $1 AND activa = true
       ORDER BY iniciada_at DESC LIMIT 1`, [domiciliarioId]);
        return {
            activa: !!sesion,
            disponible: sesion?.disponible ?? false,
        };
    }
    async ofertasActivas(domiciliarioId) {
        const filas = await this.database.consultar(`SELECT o.id AS oferta_id,
              o.pedido_id,
              o.radio_busqueda_km,
              o.intento_numero,
              o.expira_at,
              p.numero_pedido,
              p.direccion_entrega,
              p.costo_domicilio,
              p.cliente_nombre,
              p.lat,
              p.lng,
              s.nombre AS sucursal_nombre,
              s.direccion AS sucursal_direccion,
              s.lat AS sucursal_lat,
              s.lng AS sucursal_lng,
              r.id AS respuesta_id
       FROM respuestas_oferta r
       JOIN ofertas_pedido o ON o.id = r.oferta_id
       JOIN pedidos p ON p.id = o.pedido_id
       JOIN sucursales s ON s.id = o.sucursal_id
       WHERE r.domiciliario_id = $1
         AND o.estado = 'activa'
         AND o.expira_at > now()
         AND p.estado = 'listo'
         AND NOT EXISTS (
           SELECT 1 FROM asignaciones_domicilio ad
           WHERE ad.pedido_id = p.id
             AND ad.estado IN ('asignado', 'en_camino')
         )
         AND r.respuesta = 'no_vio'
       ORDER BY o.created_at DESC`, [domiciliarioId]);
        return filas.map((f) => {
            const costo = Number(f.costo_domicilio ?? 0);
            const { comision, ganancia } = this.dispatch.calcularGanancias(costo);
            return {
                ...f,
                comision_foody_pct: costo > 0 ? Math.round((comision / costo) * 100) : 15,
                comision_foody: comision,
                ganancia_estimada: ganancia,
                valor_domicilio: costo,
            };
        });
    }
    async responderOferta(ofertaId, domiciliarioId, dto) {
        return this.database.enTransaccion(async (client) => {
            const oferta = await this.consultarUnoCliente(client, `SELECT id, pedido_id, sucursal_id, estado, expira_at
         FROM ofertas_pedido WHERE id = $1 FOR UPDATE`, [ofertaId]);
            if (!oferta)
                throw new common_1.NotFoundException('Oferta no encontrada');
            if (oferta.estado !== 'activa' ||
                new Date(oferta.expira_at) <= new Date()) {
                throw new common_1.BadRequestException('La oferta expiró o ya no está activa');
            }
            const respuesta = await this.consultarUnoCliente(client, `SELECT id, respuesta FROM respuestas_oferta
         WHERE oferta_id = $1 AND domiciliario_id = $2 FOR UPDATE`, [ofertaId, domiciliarioId]);
            if (!respuesta) {
                throw new common_1.BadRequestException('No fuiste notificado para esta oferta');
            }
            if (respuesta.respuesta !== 'no_vio') {
                throw new common_1.BadRequestException('Ya respondiste esta oferta');
            }
            if (dto.respuesta === 'rechazada') {
                await client.query(`UPDATE respuestas_oferta SET respuesta = 'rechazada', respondido_at = now()
           WHERE id = $1`, [respuesta.id]);
                return { oferta_id: ofertaId, respuesta: 'rechazada' };
            }
            const ocupado = await this.consultarUnoCliente(client, `SELECT id FROM asignaciones_domicilio
         WHERE domiciliario_independiente_id = $1
           AND estado IN ('asignado', 'en_camino')`, [domiciliarioId]);
            if (ocupado) {
                throw new common_1.BadRequestException('Ya tienes un pedido activo');
            }
            const pedido = await this.consultarUnoCliente(client, `SELECT id, estado, costo_domicilio FROM pedidos
         WHERE id = $1 FOR UPDATE`, [oferta.pedido_id]);
            if (!pedido || pedido.estado !== 'listo') {
                throw new common_1.BadRequestException('El pedido ya no está disponible');
            }
            const despacho = await this.dispatch.validarPedidoParaDespacho(oferta.pedido_id, oferta.sucursal_id, client);
            if (!despacho.valido) {
                throw new common_1.BadRequestException(despacho.mensaje);
            }
            const yaAsignado = await this.consultarUnoCliente(client, `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`, [oferta.pedido_id]);
            if (yaAsignado) {
                await client.query(`UPDATE ofertas_pedido SET estado = 'cancelada' WHERE id = $1`, [ofertaId]);
                throw new common_1.BadRequestException('Otro domiciliario ya tomó el pedido');
            }
            await client.query(`UPDATE ofertas_pedido SET estado = 'aceptada' WHERE id = $1`, [ofertaId]);
            await client.query(`UPDATE respuestas_oferta SET respuesta = 'aceptada', respondido_at = now()
         WHERE oferta_id = $1 AND domiciliario_id = $2`, [ofertaId, domiciliarioId]);
            await client.query(`UPDATE respuestas_oferta SET respuesta = 'rechazada', respondido_at = now()
         WHERE oferta_id = $1 AND domiciliario_id != $2 AND respuesta = 'no_vio'`, [ofertaId, domiciliarioId]);
            await client.query(`WITH canceladas AS (
           UPDATE ofertas_pedido
           SET estado = 'cancelada'
           WHERE pedido_id = $1 AND id <> $2 AND estado = 'activa'
           RETURNING id
         )
         UPDATE respuestas_oferta
         SET respuesta = 'rechazada', respondido_at = now()
         WHERE oferta_id IN (SELECT id FROM canceladas)
           AND respuesta = 'no_vio'`, [oferta.pedido_id, ofertaId]);
            const asignacion = await client.query(`INSERT INTO asignaciones_domicilio (
           pedido_id, sucursal_id, domiciliario_independiente_id,
           tipo_domiciliario, estado, distancia_km
         )
         SELECT $1, $2, $3::uuid, 'independiente', 'asignado',
           CASE
             WHEN s.lat IS NOT NULL AND s.lng IS NOT NULL
              AND p.lat IS NOT NULL AND p.lng IS NOT NULL
             THEN ROUND((
               6371 * acos(LEAST(1::float8, GREATEST(-1::float8,
                 cos(radians(s.lat::float8)) * cos(radians(p.lat::float8))
                 * cos(radians(p.lng::float8) - radians(s.lng::float8))
                 + sin(radians(s.lat::float8)) * sin(radians(p.lat::float8))
               )))
             )::numeric, 3)
             ELSE NULL
           END
         FROM pedidos p
         JOIN sucursales s ON s.id = p.sucursal_id
         WHERE p.id = $1 AND p.sucursal_id = $2
         RETURNING id`, [oferta.pedido_id, oferta.sucursal_id, domiciliarioId]);
            const asignacionId = asignacion.rows[0].id;
            await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId: oferta.pedido_id,
                sucursalId: oferta.sucursal_id,
                nuevoEstado: 'asignado',
                origen: 'domiciliario',
                motivo: 'Domiciliario independiente aceptó oferta',
                estadoAnterior: 'listo',
                tipo: 'domicilio',
            });
            await client.query(`UPDATE domiciliarios_sesiones SET disponible = false
         WHERE domiciliario_id = $1 AND activa = true`, [domiciliarioId]);
            const costo = Number(pedido.costo_domicilio ?? 0);
            const { comision, ganancia } = this.dispatch.calcularGanancias(costo);
            if (costo > 0) {
                await client.query(`INSERT INTO ganancias_domiciliario (
             domiciliario_id, asignacion_id, valor_domicilio,
             comision_foody, ganancia_domiciliario
           ) VALUES ($1,$2,$3,$4,$5)`, [domiciliarioId, asignacionId, costo, comision, ganancia]);
            }
            return {
                oferta_id: ofertaId,
                respuesta: 'aceptada',
                pedido_id: oferta.pedido_id,
                asignacion_id: asignacionId,
                estado: 'asignado',
            };
        });
    }
    async pedidosActivos(domiciliarioId) {
        const pedidos = await this.database.consultar(`SELECT p.id,
              p.numero_pedido,
              p.estado,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.subtotal,
              p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado,
              p.metodo_pago,
              p.costo_domicilio,
              p.lat,
              p.lng,
              ad.estado AS estado_asignacion,
              ad.asignado_at,
              s.nombre AS sucursal_nombre,
              s.direccion AS sucursal_direccion,
              s.lat AS sucursal_lat,
              s.lng AS sucursal_lng
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       JOIN sucursales s ON s.id = ad.sucursal_id
       WHERE ad.domiciliario_independiente_id = $1
         AND ad.estado IN ('asignado', 'en_camino')
       ORDER BY ad.asignado_at ASC`, [domiciliarioId]);
        return pedidos.map((pedido) => {
            const cobro = (0, cobro_domicilio_util_1.repartirCobroDomicilio)(Number(pedido.total), Number(pedido.costo_domicilio ?? 0), Number(pedido.monto_pagado ?? 0));
            return {
                ...pedido,
                saldo_pendiente: cobro.saldo,
                requiere_cobro: cobro.saldo > 0.01,
                producto_total: cobro.productoTotal,
                producto_pendiente: cobro.productoPendiente,
                domicilio_pendiente: cobro.domicilioPendiente,
            };
        });
    }
    async marcarEnCamino(pedidoId, domiciliarioId) {
        return this.database.enTransaccion(async (client) => {
            const asignacion = await this.consultarUnoCliente(client, `SELECT id, sucursal_id FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_independiente_id = $2
           AND estado = 'asignado' FOR UPDATE`, [pedidoId, domiciliarioId]);
            if (!asignacion) {
                throw new common_1.BadRequestException('Pedido no asignado a ti');
            }
            await client.query(`UPDATE asignaciones_domicilio SET estado = 'en_camino' WHERE id = $1`, [asignacion.id]);
            await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId: asignacion.sucursal_id,
                nuevoEstado: 'en_camino',
                origen: 'domiciliario',
                motivo: 'Domiciliario independiente en camino',
                estadoAnterior: 'asignado',
                tipo: 'domicilio',
            });
            return { pedido_id: pedidoId, estado: 'en_camino' };
        });
    }
    async confirmarEntrega(pedidoId, domiciliarioId, dto = {}) {
        const result = await this.database.enTransaccion(async (client) => {
            const asignacion = await this.consultarUnoCliente(client, `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_independiente_id = $2
           AND estado = 'en_camino' FOR UPDATE`, [pedidoId, domiciliarioId]);
            if (!asignacion) {
                throw new common_1.BadRequestException('El pedido debe estar en camino');
            }
            const pedidoRow = await this.consultarUnoCliente(client, `SELECT sucursal_id, numero_pedido, total,
                COALESCE(costo_domicilio, 0) AS costo_domicilio,
                COALESCE(monto_pagado, 0) AS monto_pagado, metodo_pago
         FROM pedidos WHERE id = $1 FOR UPDATE`, [pedidoId]);
            if (!pedidoRow) {
                throw new common_1.NotFoundException('Pedido no encontrado');
            }
            const cfg = await this.consultarUnoCliente(client, `SELECT COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
         FROM sucursales WHERE id = $1`, [pedidoRow.sucursal_id]);
            const domicilioEnCaja = cfg?.domicilio_ingresa_a_caja ?? false;
            const { saldo, productoPendiente, domicilioPendiente } = (0, cobro_domicilio_util_1.repartirCobroDomicilio)(Number(pedidoRow.total), Number(pedidoRow.costo_domicilio), Number(pedidoRow.monto_pagado ?? 0));
            const metodoEntrega = dto.metodo_pago?.trim();
            const metodoDomicilio = dto.metodo_pago_domicilio?.trim() || metodoEntrega;
            if (saldo > 0.01) {
                if (!metodoEntrega || metodoEntrega === 'pendiente') {
                    throw new common_1.BadRequestException({
                        error: 'COBRO_REQUERIDO',
                        message: 'Indica método de pago al entregar (efectivo, tarjeta, transferencia o nequi)',
                    });
                }
                if (productoPendiente > 0.01) {
                    await client.query(`INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,$4,NULL,$5)`, [
                        pedidoRow.sucursal_id,
                        pedidoId,
                        productoPendiente,
                        metodoEntrega,
                        'Cobro producto contra entrega (independiente)',
                    ]);
                    await this.cajaAuditoria.registrarVentaEnCaja(client, pedidoRow.sucursal_id, pedidoId, productoPendiente, metodoEntrega, {
                        exigirCaja: true,
                        descripcion: `Domicilio independiente entregado ${pedidoRow.numero_pedido}`,
                    });
                }
                if (domicilioPendiente > 0.01) {
                    await client.query(`INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,$4,NULL,$5)`, [
                        pedidoRow.sucursal_id,
                        pedidoId,
                        domicilioPendiente,
                        metodoDomicilio,
                        domicilioEnCaja
                            ? 'Cobro domicilio contra entrega (independiente)'
                            : 'Domicilio independiente (fuera de caja)',
                    ]);
                    if (domicilioEnCaja) {
                        await this.cajaAuditoria.registrarVentaEnCaja(client, pedidoRow.sucursal_id, pedidoId, domicilioPendiente, metodoDomicilio ?? metodoEntrega, {
                            exigirCaja: true,
                            descripcion: `Domicilio (cobro) ${pedidoRow.numero_pedido}`,
                        });
                    }
                }
                await client.query(`UPDATE pedidos
           SET monto_pagado = $2, metodo_pago = $3
           WHERE id = $1`, [pedidoId, Number(pedidoRow.total), metodoEntrega]);
            }
            else if (metodoEntrega && metodoEntrega !== 'pendiente') {
                await client.query(`UPDATE pedidos SET metodo_pago = $1 WHERE id = $2`, [metodoEntrega, pedidoId]);
            }
            await client.query(`UPDATE asignaciones_domicilio
         SET estado = 'entregado', entregado_at = now()
         WHERE id = $1`, [asignacion.id]);
            await client.query(`UPDATE domiciliarios_independientes
         SET total_entregas = total_entregas + 1
         WHERE id = $1`, [domiciliarioId]);
            await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId: pedidoRow.sucursal_id,
                nuevoEstado: 'entregado',
                origen: 'domiciliario',
                motivo: 'Entrega confirmada por independiente',
                estadoAnterior: 'en_camino',
                tipo: 'domicilio',
            });
            await client.query(`UPDATE domiciliarios_sesiones SET disponible = true
         WHERE domiciliario_id = $1 AND activa = true`, [domiciliarioId]);
            await this.alertasRiesgo.evaluarDemoraEntrega(client, pedidoId, pedidoRow.sucursal_id);
            return {
                pedido_id: pedidoId,
                estado: 'entregado',
                sucursal_id: pedidoRow.sucursal_id,
                numero_pedido: pedidoRow.numero_pedido,
            };
        });
        void this.realtime.pedidoActualizado({
            pedido_id: result.pedido_id,
            sucursal_id: result.sucursal_id,
            estado: result.estado,
            numero_pedido: result.numero_pedido,
        });
        void this.realtime.cajaMovimiento(result.sucursal_id, {
            pedido_id: result.pedido_id,
        });
        return { pedido_id: result.pedido_id, estado: result.estado };
    }
    async ganancias(domiciliarioId, opts) {
        const params = [domiciliarioId];
        let filtroFecha = '';
        if (opts?.desde) {
            params.push(opts.desde);
            filtroFecha += ` AND g.created_at >= $${params.length}::timestamptz`;
        }
        if (opts?.hasta) {
            params.push(opts.hasta);
            filtroFecha += ` AND g.created_at < ($${params.length}::date + interval '1 day')`;
        }
        const filas = await this.database.consultar(`SELECT g.id, g.valor_domicilio, g.comision_foody, g.ganancia_domiciliario,
              g.pagado, g.created_at, ad.pedido_id, ad.estado AS estado_asignacion,
              p.numero_pedido
       FROM ganancias_domiciliario g
       LEFT JOIN asignaciones_domicilio ad ON ad.id = g.asignacion_id
       LEFT JOIN pedidos p ON p.id = ad.pedido_id
       WHERE g.domiciliario_id = $1${filtroFecha}
       ORDER BY g.created_at DESC
       LIMIT 100`, params);
        const totalGanancia = filas.reduce((s, f) => s + Number(f.ganancia_domiciliario ?? 0), 0);
        const totalComision = filas.reduce((s, f) => s + Number(f.comision_foody ?? 0), 0);
        return {
            items: filas,
            resumen: {
                entregas: filas.length,
                total_ganancia: totalGanancia,
                total_comision: totalComision,
            },
        };
    }
    async obtenerActivo(domiciliarioId) {
        const dom = await this.database.consultarUno(`SELECT id, ciudad_id, estado_cuenta
       FROM domiciliarios_independientes WHERE id = $1`, [domiciliarioId]);
        if (!dom || dom.estado_cuenta !== 'activo') {
            throw new common_1.ForbiddenException('Cuenta no activa');
        }
        return dom;
    }
    async obtenerSesionActiva(domiciliarioId) {
        const sesion = await this.database.consultarUno(`SELECT id FROM domiciliarios_sesiones
       WHERE domiciliario_id = $1 AND activa = true
       ORDER BY iniciada_at DESC LIMIT 1`, [domiciliarioId]);
        if (!sesion) {
            throw new common_1.BadRequestException('Inicia tu turno antes de actualizar ubicación');
        }
        return sesion;
    }
    async consultarUnoCliente(client, sql, params) {
        const r = await client.query(sql, params);
        return r.rows[0] ?? null;
    }
};
exports.DomiciliariosIndependientesService = DomiciliariosIndependientesService;
exports.DomiciliariosIndependientesService = DomiciliariosIndependientesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        dispatch_service_1.DispatchService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
        pedidos_estado_command_service_1.PedidosEstadoCommandService,
        pedidos_soporte_service_1.PedidosSoporteService])
], DomiciliariosIndependientesService);
//# sourceMappingURL=domiciliarios-independientes.service.js.map