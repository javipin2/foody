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
exports.DomiciliariosService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const pedidos_caja_auditoria_service_1 = require("../pedidos/pedidos-caja-auditoria.service");
const pedidos_estado_command_service_1 = require("../pedidos/pedidos-estado-command.service");
const pedidos_soporte_service_1 = require("../pedidos/pedidos-soporte.service");
const cobro_domicilio_util_1 = require("./cobro-domicilio.util");
const dispatch_service_1 = require("./dispatch.service");
let DomiciliariosService = class DomiciliariosService {
    database;
    alertasRiesgo;
    realtime;
    cajaAuditoria;
    pedidosEstadoCommand;
    pedidosSoporte;
    dispatch;
    constructor(database, alertasRiesgo, realtime, cajaAuditoria, pedidosEstadoCommand, pedidosSoporte, dispatch) {
        this.database = database;
        this.alertasRiesgo = alertasRiesgo;
        this.realtime = realtime;
        this.cajaAuditoria = cajaAuditoria;
        this.pedidosEstadoCommand = pedidosEstadoCommand;
        this.pedidosSoporte = pedidosSoporte;
        this.dispatch = dispatch;
    }
    async listarPlantaDisponibles(sucursalId) {
        return this.database.consultar(`SELECT dp.id,
              dp.usuario_id,
              u.nombre,
              u.telefono,
              u.foto_url,
              EXISTS (
                SELECT 1 FROM asignaciones_domicilio ad
                INNER JOIN pedidos p ON p.id = ad.pedido_id
                WHERE ad.domiciliario_planta_id = dp.id
                  AND ad.estado IN ('asignado', 'en_camino')
                  AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
              ) AS ocupado
       FROM domiciliarios_planta dp
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE dp.sucursal_id = $1
         AND dp.activo = true
         AND u.activo = true
       ORDER BY u.nombre`, [sucursalId]);
    }
    async asignarPlanta(dto, usuarioAdminId) {
        const result = await this.database.enTransaccion(async (client) => {
            const validacion = await this.dispatch.validarPedidoParaDespacho(dto.pedido_id, dto.sucursal_id, client);
            if (!validacion.valido) {
                if (validacion.motivo === 'PEDIDO_NO_ENCONTRADO') {
                    throw new common_1.NotFoundException(validacion.mensaje);
                }
                throw new common_1.BadRequestException({
                    error: validacion.motivo,
                    message: validacion.mensaje,
                });
            }
            const pedido = validacion.pedido;
            const domiciliario = await this.consultarUno(client, `SELECT dp.id, dp.sucursal_id, dp.usuario_id FROM domiciliarios_planta dp
         WHERE dp.id = $1 AND dp.activo = true
         FOR UPDATE`, [dto.domiciliario_planta_id]);
            if (!domiciliario || domiciliario.sucursal_id !== dto.sucursal_id) {
                throw new common_1.BadRequestException('Domiciliario no válido para esta sucursal');
            }
            const ocupado = await this.consultarUno(client, `SELECT ad.id FROM asignaciones_domicilio ad
         INNER JOIN pedidos p ON p.id = ad.pedido_id
         WHERE ad.domiciliario_planta_id = $1
           AND ad.estado IN ('asignado', 'en_camino')
           AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
         LIMIT 1`, [dto.domiciliario_planta_id]);
            if (ocupado) {
                throw new common_1.BadRequestException('El domiciliario ya tiene un pedido activo');
            }
            const previa = await this.consultarUno(client, `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')
         LIMIT 1`, [dto.pedido_id]);
            if (previa) {
                throw new common_1.BadRequestException('El pedido ya tiene domiciliario asignado');
            }
            await client.query(`INSERT INTO asignaciones_domicilio
           (pedido_id, sucursal_id, domiciliario_planta_id, tipo_domiciliario, estado, distancia_km)
         SELECT $1, $2, $3::uuid, 'planta', 'asignado',
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
         WHERE p.id = $1 AND p.sucursal_id = $2`, [dto.pedido_id, dto.sucursal_id, dto.domiciliario_planta_id]);
            await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId: dto.pedido_id,
                sucursalId: dto.sucursal_id,
                nuevoEstado: 'asignado',
                origen: 'domiciliario',
                usuarioId: usuarioAdminId,
                motivo: 'Domiciliario de planta asignado',
                estadoAnterior: 'listo',
                tipo: 'domicilio',
            });
            return {
                pedido_id: dto.pedido_id,
                estado: 'asignado',
                sucursal_id: dto.sucursal_id,
                domiciliario_usuario_id: domiciliario.usuario_id,
            };
        });
        void this.realtime.domiciliarioPlantaActualizado(result.domiciliario_usuario_id, {
            pedido_id: result.pedido_id,
            sucursal_id: result.sucursal_id,
            accion: 'asignado',
        });
        void this.realtime.pedidoActualizado({
            pedido_id: result.pedido_id,
            sucursal_id: result.sucursal_id,
            estado: result.estado,
        });
        return {
            pedido_id: result.pedido_id,
            estado: result.estado,
        };
    }
    async reasignarPlanta(dto, usuarioAdminId) {
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.consultarUno(client, `SELECT id, tipo, estado FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`, [dto.pedido_id, dto.sucursal_id]);
            if (!pedido) {
                throw new common_1.NotFoundException('Pedido no encontrado');
            }
            if (pedido.tipo !== 'domicilio') {
                throw new common_1.BadRequestException('Solo pedidos de domicilio admiten reasignación');
            }
            if (!['asignado', 'en_camino'].includes(pedido.estado)) {
                throw new common_1.BadRequestException('Solo se puede cambiar domiciliario en asignado o en camino');
            }
            const domiciliario = await this.consultarUno(client, `SELECT dp.id, dp.sucursal_id, dp.usuario_id FROM domiciliarios_planta dp
         WHERE dp.id = $1 AND dp.activo = true
         FOR UPDATE`, [dto.domiciliario_planta_id]);
            if (!domiciliario || domiciliario.sucursal_id !== dto.sucursal_id) {
                throw new common_1.BadRequestException('Domiciliario no válido para esta sucursal');
            }
            const asignacionActiva = await this.consultarUno(client, `SELECT id, domiciliario_planta_id::text AS domiciliario_planta_id
         FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')
         ORDER BY asignado_at DESC
         LIMIT 1
         FOR UPDATE`, [dto.pedido_id]);
            if (!asignacionActiva) {
                throw new common_1.BadRequestException('El pedido no tiene domiciliario activo');
            }
            if (asignacionActiva.domiciliario_planta_id === dto.domiciliario_planta_id) {
                throw new common_1.BadRequestException('Ya está asignado a ese domiciliario');
            }
            const ocupado = await this.consultarUno(client, `SELECT ad.id FROM asignaciones_domicilio ad
         INNER JOIN pedidos p ON p.id = ad.pedido_id
         WHERE ad.domiciliario_planta_id = $1
           AND ad.estado IN ('asignado', 'en_camino')
           AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
           AND ad.pedido_id <> $2
         LIMIT 1`, [dto.domiciliario_planta_id, dto.pedido_id]);
            if (ocupado) {
                throw new common_1.BadRequestException('El domiciliario ya tiene un pedido activo');
            }
            await client.query(`UPDATE asignaciones_domicilio
         SET estado = 'cancelado'
         WHERE id = $1`, [asignacionActiva.id]);
            await client.query(`INSERT INTO asignaciones_domicilio
           (pedido_id, sucursal_id, domiciliario_planta_id, tipo_domiciliario, estado, distancia_km)
         SELECT $1, $2, $3::uuid, 'planta', $4,
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
         WHERE p.id = $1 AND p.sucursal_id = $2`, [
                dto.pedido_id,
                dto.sucursal_id,
                dto.domiciliario_planta_id,
                pedido.estado === 'en_camino' ? 'en_camino' : 'asignado',
            ]);
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues
         ) VALUES ($1,$2,'REASIGNAR_DOMICILIARIO','asignaciones_domicilio',$3,$4::jsonb)`, [
                dto.sucursal_id,
                usuarioAdminId,
                dto.pedido_id,
                JSON.stringify({
                    anterior: asignacionActiva.domiciliario_planta_id,
                    nuevo: dto.domiciliario_planta_id,
                    estado_pedido: pedido.estado,
                }),
            ]);
            return {
                pedido_id: dto.pedido_id,
                estado: pedido.estado,
                sucursal_id: dto.sucursal_id,
                domiciliario_usuario_id: domiciliario.usuario_id,
                anterior_planta_id: asignacionActiva.domiciliario_planta_id,
            };
        });
        void this.realtime.domiciliarioPlantaActualizado(result.domiciliario_usuario_id, {
            pedido_id: result.pedido_id,
            sucursal_id: result.sucursal_id,
            accion: 'reasignado',
        });
        void this.realtime.pedidoActualizado({
            pedido_id: result.pedido_id,
            sucursal_id: result.sucursal_id,
            estado: result.estado,
        });
        return {
            pedido_id: result.pedido_id,
            estado: result.estado,
            reasignado: true,
        };
    }
    async historialEntregas(usuarioId, opts) {
        const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
        if (!domiciliario) {
            throw new common_1.NotFoundException('No eres domiciliario de planta registrado');
        }
        const limite = opts?.limite ?? 50;
        const params = [domiciliario.id];
        let filtroFecha = '';
        if (opts?.desde) {
            params.push(opts.desde);
            filtroFecha += ` AND ad.entregado_at >= $${params.length}::timestamptz`;
        }
        if (opts?.hasta) {
            params.push(opts.hasta);
            filtroFecha += ` AND ad.entregado_at < ($${params.length}::date + interval '1 day')`;
        }
        params.push(limite);
        return this.database.consultar(`SELECT p.id,
              p.numero_pedido,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.subtotal,
              p.costo_domicilio,
              p.total,
              p.metodo_pago,
              p.estado,
              ad.entregado_at,
              ad.asignado_at
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'entregado'${filtroFecha}
       ORDER BY ad.entregado_at DESC NULLS LAST
       LIMIT $${params.length}`, params);
    }
    async estadisticasPlanta(usuarioId, opts) {
        const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
        if (!domiciliario) {
            throw new common_1.NotFoundException('No eres domiciliario de planta registrado');
        }
        const params = [domiciliario.id];
        let filtroRango = '';
        if (opts?.desde) {
            params.push(opts.desde);
            filtroRango += ` AND ad.entregado_at >= $${params.length}::timestamptz`;
        }
        if (opts?.hasta) {
            params.push(opts.hasta);
            filtroRango += ` AND ad.entregado_at < ($${params.length}::date + interval '1 day')`;
        }
        const fila = await this.database.consultarUno(`SELECT
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('day', now()))::text AS hoy,
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('week', now()))::text AS semana,
         COUNT(*) FILTER (WHERE ad.entregado_at >= date_trunc('month', now()))::text AS mes,
         COUNT(*)::text AS rango,
         COALESCE(SUM(p.total), 0)::text AS cobrado_rango,
         AVG(
           EXTRACT(EPOCH FROM (ad.entregado_at - ad.asignado_at)) / 60
         ) FILTER (WHERE ad.entregado_at IS NOT NULL)::text AS promedio_min,
         (
           SELECT COALESCE(SUM(cxc.monto), 0)::text
           FROM cuentas_por_cobrar cxc
           WHERE cxc.domiciliario_planta_id = $1
             AND cxc.estado = 'pendiente'
         ) AS saldo_liquidar
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'entregado'${filtroRango}`, params);
        return {
            entregas_hoy: Number(fila?.hoy ?? 0),
            entregas_semana: Number(fila?.semana ?? 0),
            entregas_mes: Number(fila?.mes ?? 0),
            entregas_rango: Number(fila?.rango ?? 0),
            total_cobrado_rango: Number(fila?.cobrado_rango ?? 0),
            tiempo_promedio_min: fila?.promedio_min != null
                ? Math.round(Number(fila.promedio_min))
                : null,
            saldo_por_liquidar: Number(fila?.saldo_liquidar ?? 0),
        };
    }
    async pedidosAsignados(usuarioId) {
        const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
        if (!domiciliario) {
            throw new common_1.NotFoundException('No eres domiciliario de planta registrado');
        }
        const pedidos = await this.database.consultar(`SELECT p.id,
              p.numero_pedido,
              p.tipo,
              p.estado,
              p.cliente_nombre,
              p.cliente_telefono,
              p.direccion_entrega,
              p.lat,
              p.lng,
              p.subtotal,
              p.costo_domicilio,
              p.total,
              COALESCE(p.monto_pagado, 0) AS monto_pagado,
              p.metodo_pago,
              p.created_at,
              ad.estado AS estado_asignacion,
              ad.asignado_at,
              COALESCE(s.permite_fiado_domiciliario, false) AS permite_fiado_domiciliario,
              COALESCE(s.domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       JOIN sucursales s ON s.id = p.sucursal_id
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado IN ('asignado', 'en_camino')
         AND p.estado IN ('asignado', 'en_camino')
       ORDER BY ad.asignado_at ASC`, [domiciliario.id]);
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
    async resumenLiquidacion(sucursalId) {
        const sucursal = await this.database.consultarUno(`SELECT COALESCE(permite_fiado_domiciliario, false) AS permite_fiado_domiciliario
       FROM sucursales WHERE id = $1`, [sucursalId]);
        const filas = await this.database.consultar(`SELECT cxc.domiciliario_planta_id,
              u.nombre,
              COUNT(*)::text AS pedidos,
              COALESCE(SUM(cxc.monto), 0)::text AS total_pendiente
       FROM cuentas_por_cobrar cxc
       JOIN domiciliarios_planta dp ON dp.id = cxc.domiciliario_planta_id
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE cxc.sucursal_id = $1
         AND cxc.estado = 'pendiente'
         AND cxc.domiciliario_planta_id IS NOT NULL
       GROUP BY cxc.domiciliario_planta_id, u.nombre
       ORDER BY total_pendiente DESC`, [sucursalId]);
        return {
            permite_fiado_domiciliario: sucursal?.permite_fiado_domiciliario ?? false,
            domiciliarios: filas.map((f) => ({
                domiciliario_planta_id: f.domiciliario_planta_id,
                nombre: f.nombre,
                pedidos: Number(f.pedidos),
                total_pendiente: Number(f.total_pendiente),
            })),
        };
    }
    async resumenDomicilios(sucursalId, desde, hasta) {
        const sucursal = await this.database.consultarUno(`SELECT COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
       FROM sucursales WHERE id = $1`, [sucursalId]);
        const filas = await this.database.consultar(`SELECT ad.domiciliario_planta_id,
              u.nombre,
              COUNT(*)::text AS pedidos_entregados,
              COALESCE(SUM(p.costo_domicilio), 0)::text AS total_domicilios
       FROM asignaciones_domicilio ad
       JOIN pedidos p ON p.id = ad.pedido_id
       JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE ad.sucursal_id = $1
         AND ad.estado = 'entregado'
         AND ad.domiciliario_planta_id IS NOT NULL
         AND ($2::timestamptz IS NULL OR ad.entregado_at >= $2::timestamptz)
         AND ($3::timestamptz IS NULL OR ad.entregado_at <= $3::timestamptz)
       GROUP BY ad.domiciliario_planta_id, u.nombre
       ORDER BY total_domicilios DESC`, [sucursalId, desde ?? null, hasta ?? null]);
        return {
            domicilio_ingresa_a_caja: sucursal?.domicilio_ingresa_a_caja ?? false,
            domiciliarios: filas.map((f) => ({
                domiciliario_planta_id: f.domiciliario_planta_id,
                nombre: f.nombre,
                pedidos_entregados: Number(f.pedidos_entregados),
                total_domicilios: Number(f.total_domicilios),
            })),
        };
    }
    async liquidarDomiciliario(sucursalId, domiciliarioPlantaId, usuarioId) {
        return this.database.enTransaccion(async (client) => {
            const cuentas = await client.query(`SELECT id, pedido_id, monto FROM cuentas_por_cobrar
         WHERE sucursal_id = $1
           AND domiciliario_planta_id = $2
           AND estado = 'pendiente'
         FOR UPDATE`, [sucursalId, domiciliarioPlantaId]);
            if (cuentas.rows.length === 0) {
                throw new common_1.BadRequestException({
                    error: 'SIN_CUENTAS_PENDIENTES',
                    message: 'Este domiciliario no tiene domicilios por liquidar',
                });
            }
            let total = 0;
            for (const cuenta of cuentas.rows) {
                const monto = Number(cuenta.monto);
                total += monto;
                await client.query(`UPDATE cuentas_por_cobrar
           SET estado = 'pagada', pagada_at = now()
           WHERE id = $1`, [cuenta.id]);
                if (cuenta.pedido_id) {
                    await client.query(`INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,'efectivo',$4,$5)`, [
                        sucursalId,
                        cuenta.pedido_id,
                        monto,
                        usuarioId,
                        'Liquidación domiciliario',
                    ]);
                    await this.cajaAuditoria.registrarVentaEnCaja(client, sucursalId, cuenta.pedido_id, monto, 'efectivo', {
                        exigirCaja: true,
                        descripcion: 'Liquidación domicilio a cuenta',
                        usuarioId,
                    });
                    await client.query(`UPDATE pedidos
             SET monto_pagado = total, metodo_pago = 'efectivo'
             WHERE id = $1`, [cuenta.pedido_id]);
                }
            }
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues
         ) VALUES ($1,$2,'LIQUIDAR_DOMICILIARIO','cuentas_por_cobrar',$3,$4::jsonb)`, [
                sucursalId,
                usuarioId,
                domiciliarioPlantaId,
                JSON.stringify({ liquidados: cuentas.rows.length, total }),
            ]);
            return {
                domiciliario_planta_id: domiciliarioPlantaId,
                liquidados: cuentas.rows.length,
                total,
            };
        });
    }
    async configurarFiadoDomiciliario(sucursalId, permitir) {
        await this.database.consultar(`UPDATE sucursales SET permite_fiado_domiciliario = $2 WHERE id = $1`, [sucursalId, permitir]);
        return { sucursal_id: sucursalId, permite_fiado_domiciliario: permitir };
    }
    async configurarDomicilioEnCaja(sucursalId, ingresa) {
        await this.database.consultar(`UPDATE sucursales SET domicilio_ingresa_a_caja = $2 WHERE id = $1`, [sucursalId, ingresa]);
        return { sucursal_id: sucursalId, domicilio_ingresa_a_caja: ingresa };
    }
    async marcarEnCamino(pedidoId, usuarioId) {
        const result = await this.database.enTransaccion(async (client) => {
            const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
            if (!domiciliario) {
                throw new common_1.NotFoundException('No eres domiciliario de planta registrado');
            }
            const asignacion = await this.consultarUno(client, `SELECT id, pedido_id, estado FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_planta_id = $2
           AND estado = 'asignado'
         FOR UPDATE`, [pedidoId, domiciliario.id]);
            if (!asignacion) {
                throw new common_1.BadRequestException('Pedido no asignado a ti o ya en camino');
            }
            await client.query(`UPDATE asignaciones_domicilio SET estado = 'en_camino' WHERE id = $1`, [asignacion.id]);
            const pedido = await this.consultarUno(client, `SELECT sucursal_id FROM pedidos WHERE id = $1`, [pedidoId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId: pedido.sucursal_id,
                nuevoEstado: 'en_camino',
                origen: 'domiciliario',
                usuarioId,
                estadoAnterior: 'asignado',
                tipo: 'domicilio',
            });
            return {
                pedido_id: pedidoId,
                estado: 'en_camino',
                sucursal_id: pedido.sucursal_id,
            };
        });
        void this.realtime.domiciliarioPlantaActualizado(usuarioId, {
            pedido_id: result.pedido_id,
            accion: 'en_camino',
        });
        if (result.sucursal_id) {
            void this.realtime.pedidoActualizado({
                pedido_id: result.pedido_id,
                sucursal_id: result.sucursal_id,
                estado: result.estado,
            });
        }
        return { pedido_id: result.pedido_id, estado: result.estado };
    }
    async registrarUbicacionEntrega(usuarioId, dto) {
        const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
        if (!domiciliario) {
            throw new common_1.NotFoundException('No eres domiciliario de planta registrado');
        }
        const params = [domiciliario.id];
        let filtroPedido = '';
        if (dto.pedido_id) {
            filtroPedido = ' AND ad.pedido_id = $2';
            params.push(dto.pedido_id);
        }
        const asignacion = await this.database.consultarUno(`SELECT ad.id, ad.pedido_id
       FROM asignaciones_domicilio ad
       WHERE ad.domiciliario_planta_id = $1
         AND ad.estado = 'en_camino'${filtroPedido}
       ORDER BY ad.asignado_at DESC
       LIMIT 1`, params);
        if (!asignacion) {
            return { ok: true, registrado: false };
        }
        await this.database.consultar(`INSERT INTO domiciliarios_ubicaciones_historial (asignacion_id, lat, lng)
       VALUES ($1, $2, $3)`, [asignacion.id, dto.lat, dto.lng]);
        this.pedidosSoporte.emitirUbicacionRepartidor(asignacion.pedido_id, {
            repartidor_lat: dto.lat,
            repartidor_lng: dto.lng,
        });
        return { ok: true, registrado: true, pedido_id: asignacion.pedido_id };
    }
    async registrarCobroEntrega(client, p) {
        if (p.productoPendiente > 0.01) {
            await client.query(`INSERT INTO pagos_pedido (
           sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
         ) VALUES ($1,$2,$3,0,$4,$5,$6)`, [
                p.sucursalId,
                p.pedidoId,
                p.productoPendiente,
                p.metodoProducto,
                p.usuarioId,
                'Cobro producto contra entrega',
            ]);
            await this.cajaAuditoria.registrarVentaEnCaja(client, p.sucursalId, p.pedidoId, p.productoPendiente, p.metodoProducto, {
                exigirCaja: true,
                descripcion: `Domicilio entregado ${p.numeroPedido}`,
                usuarioId: p.usuarioId ?? undefined,
            });
        }
        if (p.domicilioPendiente > 0.01) {
            await client.query(`INSERT INTO pagos_pedido (
           sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
         ) VALUES ($1,$2,$3,0,$4,$5,$6)`, [
                p.sucursalId,
                p.pedidoId,
                p.domicilioPendiente,
                p.metodoDomicilio,
                p.usuarioId,
                p.domicilioEnCaja
                    ? 'Cobro domicilio contra entrega'
                    : 'Domicilio (fuera de caja)',
            ]);
            if (p.domicilioEnCaja) {
                await this.cajaAuditoria.registrarVentaEnCaja(client, p.sucursalId, p.pedidoId, p.domicilioPendiente, p.metodoDomicilio, {
                    exigirCaja: true,
                    descripcion: `Domicilio (cobro) ${p.numeroPedido}`,
                    usuarioId: p.usuarioId ?? undefined,
                });
            }
        }
    }
    async confirmarEntrega(pedidoId, usuarioId, dto) {
        const result = await this.database.enTransaccion(async (client) => {
            const domiciliario = await this.obtenerPlantaPorUsuario(usuarioId);
            if (!domiciliario) {
                throw new common_1.NotFoundException('No eres domiciliario de planta registrado');
            }
            const asignacion = await this.consultarUno(client, `SELECT id, estado FROM asignaciones_domicilio
         WHERE pedido_id = $1
           AND domiciliario_planta_id = $2
           AND estado = 'en_camino'
         FOR UPDATE`, [pedidoId, domiciliario.id]);
            if (!asignacion) {
                throw new common_1.BadRequestException('El pedido debe estar en camino y asignado a ti');
            }
            const pedidoRow = await this.consultarUno(client, `SELECT sucursal_id, numero_pedido, total,
                COALESCE(costo_domicilio, 0) AS costo_domicilio,
                COALESCE(monto_pagado, 0) AS monto_pagado, metodo_pago
         FROM pedidos WHERE id = $1 FOR UPDATE`, [pedidoId]);
            if (!pedidoRow) {
                throw new common_1.NotFoundException('Pedido no encontrado');
            }
            const sucursalCfg = await this.consultarUno(client, `SELECT COALESCE(permite_fiado_domiciliario, false) AS permite_fiado_domiciliario,
                COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
         FROM sucursales WHERE id = $1`, [pedidoRow.sucursal_id]);
            const domicilioEnCaja = sucursalCfg?.domicilio_ingresa_a_caja ?? false;
            const { saldo, productoPendiente, domicilioPendiente } = (0, cobro_domicilio_util_1.repartirCobroDomicilio)(Number(pedidoRow.total), Number(pedidoRow.costo_domicilio), Number(pedidoRow.monto_pagado ?? 0));
            const metodoEntrega = dto.metodo_pago?.trim();
            const metodoDomicilio = dto.metodo_pago_domicilio?.trim() || metodoEntrega;
            if (saldo > 0.01 && metodoEntrega === 'pendiente_liquidacion') {
                if (!sucursalCfg?.permite_fiado_domiciliario) {
                    throw new common_1.BadRequestException({
                        error: 'FIADO_DOMICILIARIO_NO_PERMITIDO',
                        message: 'Esta sucursal no permite dejar domicilios a cuenta del domiciliario. Cobra al entregar.',
                    });
                }
                const domiUsuario = await this.consultarUno(client, `SELECT u.nombre FROM domiciliarios_planta dp
           JOIN usuarios u ON u.id = dp.usuario_id
           WHERE dp.id = $1`, [domiciliario.id]);
                const montoCxc = domicilioEnCaja ? saldo : productoPendiente;
                if (montoCxc > 0.01) {
                    await client.query(`INSERT INTO cuentas_por_cobrar (
               sucursal_id, pedido_id, domiciliario_planta_id,
               cliente_nombre, cliente_telefono, monto, usuario_id
             ) VALUES ($1,$2,$3,$4,$5,$6,$7)`, [
                        pedidoRow.sucursal_id,
                        pedidoId,
                        domiciliario.id,
                        `Domiciliario: ${domiUsuario?.nombre ?? 'planta'}`,
                        null,
                        montoCxc,
                        usuarioId,
                    ]);
                }
            }
            else if (saldo > 0.01) {
                if (!metodoEntrega || metodoEntrega === 'pendiente') {
                    throw new common_1.BadRequestException({
                        error: 'COBRO_REQUERIDO',
                        message: 'Indica método de pago al entregar (efectivo, tarjeta, transferencia o nequi)',
                    });
                }
                await this.registrarCobroEntrega(client, {
                    sucursalId: pedidoRow.sucursal_id,
                    pedidoId,
                    numeroPedido: pedidoRow.numero_pedido,
                    usuarioId,
                    productoPendiente,
                    domicilioPendiente,
                    metodoProducto: metodoEntrega,
                    metodoDomicilio: metodoDomicilio ?? metodoEntrega,
                    domicilioEnCaja,
                });
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
            await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId: pedidoRow.sucursal_id,
                nuevoEstado: 'entregado',
                origen: 'domiciliario',
                usuarioId,
                motivo: 'Entrega confirmada por domiciliario de planta',
                estadoAnterior: 'en_camino',
                tipo: 'domicilio',
            });
            await this.alertasRiesgo.evaluarDemoraEntrega(client, pedidoId, pedidoRow.sucursal_id);
            return {
                pedido_id: pedidoId,
                estado: 'entregado',
                sucursal_id: pedidoRow.sucursal_id,
            };
        });
        void this.realtime.domiciliarioPlantaActualizado(usuarioId, {
            pedido_id: result.pedido_id,
            accion: 'entregado',
        });
        if (result.sucursal_id) {
            void this.realtime.pedidoActualizado({
                pedido_id: result.pedido_id,
                sucursal_id: result.sucursal_id,
                estado: result.estado,
            });
        }
        return { pedido_id: result.pedido_id, estado: result.estado };
    }
    async resumenComisionesIndependientes(sucursalId) {
        return this.database.consultar(`SELECT di.id,
              di.nombre,
              COUNT(gd.id)::int AS entregas,
              COALESCE(SUM(gd.valor_domicilio), 0) AS total_domicilios,
              COALESCE(SUM(gd.comision_foody), 0) AS comision_foody,
              COALESCE(SUM(gd.ganancia_domiciliario), 0) AS ganancia_total,
              COALESCE(
                SUM(gd.ganancia_domiciliario) FILTER (WHERE gd.pagado = false),
                0
              ) AS por_pagar
       FROM ganancias_domiciliario gd
       JOIN asignaciones_domicilio ad ON ad.id = gd.asignacion_id
       JOIN domiciliarios_independientes di ON di.id = gd.domiciliario_id
       WHERE ad.sucursal_id = $1
       GROUP BY di.id, di.nombre
       ORDER BY por_pagar DESC, ganancia_total DESC`, [sucursalId]);
    }
    async obtenerPlantaPorUsuario(usuarioId) {
        return this.database.consultarUno(`SELECT id, sucursal_id FROM domiciliarios_planta
       WHERE usuario_id = $1 AND activo = true
       LIMIT 1`, [usuarioId]);
    }
    async consultarUno(client, sql, params) {
        const r = await client.query(sql, params);
        return r.rows[0] ?? null;
    }
};
exports.DomiciliariosService = DomiciliariosService;
exports.DomiciliariosService = DomiciliariosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
        pedidos_estado_command_service_1.PedidosEstadoCommandService,
        pedidos_soporte_service_1.PedidosSoporteService,
        dispatch_service_1.DispatchService])
], DomiciliariosService);
//# sourceMappingURL=domiciliarios.service.js.map