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
exports.PedidosEstadoService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const costeo_service_1 = require("../costeo/costeo.service");
const pedidos_caja_auditoria_service_1 = require("./pedidos-caja-auditoria.service");
const pedidos_cuenta_mesa_service_1 = require("./pedidos-cuenta-mesa.service");
const pedidos_inventario_service_1 = require("./pedidos-inventario.service");
const pedido_estados_1 = require("./pedido-estados");
const auditoria_service_1 = require("../auditoria/auditoria.service");
const pedidos_soporte_service_1 = require("./pedidos-soporte.service");
const pedidos_estado_command_service_1 = require("./pedidos-estado-command.service");
const pedidos_dispatch_hooks_service_1 = require("./pedidos-dispatch-hooks.service");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
const cobro_domicilio_util_1 = require("../domiciliarios/cobro-domicilio.util");
const ESTADOS_KANBAN = [
    'pendiente',
    'confirmado',
    'en_cocina',
    'listo',
    'pagando',
    'asignado',
    'en_camino',
    'entregado',
];
const ESTADOS_PERMITIDOS_MESERO = new Set(['pagando', 'cancelado']);
let PedidosEstadoService = class PedidosEstadoService {
    database;
    dispatchHooks;
    alertasRiesgo;
    costeo;
    cajaAuditoria;
    cuentaMesa;
    soporte;
    estadoCommand;
    inventario;
    auditoria;
    notificaciones;
    constructor(database, dispatchHooks, alertasRiesgo, costeo, cajaAuditoria, cuentaMesa, soporte, estadoCommand, inventario, auditoria, notificaciones) {
        this.database = database;
        this.dispatchHooks = dispatchHooks;
        this.alertasRiesgo = alertasRiesgo;
        this.costeo = costeo;
        this.cajaAuditoria = cajaAuditoria;
        this.cuentaMesa = cuentaMesa;
        this.soporte = soporte;
        this.estadoCommand = estadoCommand;
        this.inventario = inventario;
        this.auditoria = auditoria;
        this.notificaciones = notificaciones;
    }
    async cambiarEstado(pedidoId, sucursalId, usuarioId, nuevoEstado, motivo, contexto) {
        if (!ESTADOS_KANBAN.includes(nuevoEstado) &&
            nuevoEstado !== 'pendiente_aprobacion' &&
            nuevoEstado !== 'cancelado' &&
            nuevoEstado !== 'rechazado') {
            throw new common_1.BadRequestException('Estado no válido');
        }
        let catalogoCambios = [];
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, tipo, mesa_id, stock_descontado, created_at, total,
                COALESCE(costo_domicilio, 0) AS costo_domicilio,
                COALESCE(monto_pagado, 0) AS monto_pagado, metodo_pago, numero_pedido,
                mesera_id
         FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido) {
                throw new common_1.NotFoundException('Pedido no encontrado');
            }
            if (contexto?.rol === 'mesero' &&
                !ESTADOS_PERMITIDOS_MESERO.has(nuevoEstado)) {
                throw new common_1.ForbiddenException({
                    error: 'ESTADO_ROL_NO_PERMITIDO',
                    message: 'El mesero solo puede presentar cuenta (pagando) o cancelar el pedido',
                });
            }
            if (nuevoEstado === 'cancelado' && contexto) {
                if (contexto.rol === 'cliente') {
                    this.soporte.validarCancelacionCliente(pedido, motivo);
                }
                else {
                    this.soporte.validarCancelacion(pedido, contexto.rol, contexto.permisos, motivo);
                }
            }
            const anterior = pedido.estado;
            if (anterior === nuevoEstado) {
                return {
                    id: pedidoId,
                    estado: nuevoEstado,
                    estado_anterior: anterior,
                    tipo: pedido.tipo,
                    mesa_id: pedido.mesa_id,
                    mesera_id: pedido.mesera_id,
                    numero_pedido: pedido.numero_pedido,
                };
            }
            if (!(0, pedido_estados_1.transicionEstadoPermitida)(anterior, nuevoEstado, pedido.tipo, pedido.mesa_id)) {
                throw new common_1.BadRequestException({
                    error: 'TRANSICION_ESTADO_INVALIDA',
                    message: `No se puede pasar de «${anterior}» a «${nuevoEstado}»`,
                });
            }
            if (nuevoEstado === 'entregado' && pedido.tipo !== 'domicilio') {
                throw new common_1.BadRequestException({
                    error: 'ENTREGADO_SOLO_DOMICILIO',
                    message: 'Los pedidos de mesa o para llevar se cierran con cobro en caja (estado pagado), no como entregado.',
                });
            }
            if (nuevoEstado === 'pagando' &&
                !(0, pedido_estados_1.puedeMarcarPagando)(pedido.tipo, pedido.mesa_id)) {
                throw new common_1.BadRequestException({
                    error: 'PAGANDO_NO_APLICA',
                    message: 'Solo pedidos de mesa o para llevar pueden marcarse como pagando',
                });
            }
            if ((0, pedido_estados_1.estadoActivaCocina)(nuevoEstado) && !pedido.stock_descontado) {
                const lineas = await this.inventario.lineasDesdePedido(client, pedidoId, sucursalId);
                const stock = await this.inventario.descontarStockPedido(client, sucursalId, pedidoId, lineas, { incluirEmpaques: pedido.tipo === 'domicilio' });
                catalogoCambios.push(...stock.catalogo);
                await client.query(`UPDATE pedidos SET stock_descontado = true WHERE id = $1`, [pedidoId]);
            }
            if (nuevoEstado === 'cancelado' && pedido.stock_descontado) {
                const requiereMerma = await this.inventario.pedidoRequiereMermaAlCancelar(client, pedidoId, anterior);
                if (requiereMerma) {
                    await this.inventario.registrarMermaPedidoCompleto(client, sucursalId, pedidoId, motivo ?? 'Cancelación de pedido ya en cocina o listo');
                    await this.alertasRiesgo.registrarEnTransaccion(client, {
                        sucursalId,
                        tipo: 'merma_cancelacion_pedido',
                        nivel: 'medio',
                        descripcion: `Merma por cancelación de pedido en estado ${anterior}`,
                        referenciaId: pedidoId,
                        referenciaTipo: 'pedido',
                        deduplicar: false,
                    });
                }
                else {
                    const restaurado = await this.inventario.restaurarStockPedido(client, sucursalId, pedidoId);
                    catalogoCambios.push(...restaurado);
                    await client.query(`UPDATE pedidos SET stock_descontado = false WHERE id = $1`, [pedidoId]);
                }
            }
            await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId,
                nuevoEstado,
                origen: 'kanban',
                usuarioId,
                motivo: motivo ?? null,
                estadoAnterior: anterior,
                tipo: pedido.tipo,
            });
            if (nuevoEstado === 'entregado' && pedido.tipo === 'domicilio') {
                const totalPedido = Number(pedido.total);
                const pagado = Number(pedido.monto_pagado ?? 0);
                const metodo = pedido.metodo_pago?.trim() && pedido.metodo_pago !== 'pendiente'
                    ? pedido.metodo_pago.trim()
                    : 'efectivo';
                const sucursalCfg = await this.soporte.consultarUnoCliente(client, `SELECT COALESCE(domicilio_ingresa_a_caja, false) AS domicilio_ingresa_a_caja
           FROM sucursales WHERE id = $1`, [sucursalId]);
                const domicilioEnCaja = sucursalCfg?.domicilio_ingresa_a_caja ?? false;
                const montoCaja = (0, cobro_domicilio_util_1.montoVentaCajaEntregaDomicilio)(totalPedido, Number(pedido.costo_domicilio), pagado, domicilioEnCaja);
                if (montoCaja > 0.01 &&
                    pedidos_caja_auditoria_service_1.METODOS_CON_CAJA.includes(metodo)) {
                    await client.query(`INSERT INTO pagos_pedido (
               sucursal_id, pedido_id, monto, propina, metodo_pago, usuario_id, referencia
             ) VALUES ($1,$2,$3,0,$4,$5,$6)`, [
                        sucursalId,
                        pedidoId,
                        montoCaja,
                        metodo,
                        usuarioId,
                        `Cobro producto domicilio ${pedido.numero_pedido}`,
                    ]);
                    await this.cajaAuditoria.registrarVentaEnCaja(client, sucursalId, pedidoId, montoCaja, metodo, {
                        exigirCaja: true,
                        descripcion: `Domicilio entregado ${pedido.numero_pedido}`,
                        usuarioId,
                    });
                    await client.query(`UPDATE pedidos SET monto_pagado = $2, metodo_pago = $3 WHERE id = $1`, [pedidoId, totalPedido, metodo]);
                }
            }
            if (nuevoEstado === 'en_cocina' &&
                pedido.mesa_id &&
                usuarioId &&
                ['pendiente_aprobacion', 'pendiente', 'confirmado'].includes(anterior)) {
                await this.soporte.assertMeseraPuedeTomarMesa(client, sucursalId, pedido.mesa_id, usuarioId);
                await client.query(`UPDATE pedidos SET mesera_id = COALESCE(mesera_id, $1), aprobado_at = COALESCE(aprobado_at, now())
           WHERE id = $2`, [usuarioId, pedidoId]);
                await this.soporte.asignarMeseraAMesa(client, sucursalId, pedido.mesa_id, usuarioId);
            }
            if (nuevoEstado === 'pagando' && pedido.mesa_id) {
                await this.cuentaMesa.marcarEstadoOperativoMesa(client, pedido.mesa_id, sucursalId, 'pagando');
            }
            if (['pagado', 'cancelado', 'rechazado'].includes(nuevoEstado) &&
                pedido.mesa_id) {
                await this.cuentaMesa.liberarMesaSiSinPedidosActivos(client, pedido.mesa_id, sucursalId);
            }
            if (nuevoEstado === 'cancelado') {
                const reversa = await this.cajaAuditoria.revertirVentasPedido(client, pedidoId, sucursalId, usuarioId, motivo ?? 'Pedido cancelado');
                await client.query(`UPDATE pedidos SET monto_pagado = 0 WHERE id = $1`, [pedidoId]);
                const domiciliariosDesasignados = await client.query(`SELECT DISTINCT dp.usuario_id,
                  ad.domiciliario_independiente_id AS independiente_id
           FROM asignaciones_domicilio ad
           LEFT JOIN domiciliarios_planta dp ON dp.id = ad.domiciliario_planta_id
           WHERE ad.pedido_id = $1
             AND ad.estado IN ('asignado', 'en_camino')`, [pedidoId]);
                await client.query(`UPDATE asignaciones_domicilio SET estado = 'cancelado'
           WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`, [pedidoId]);
                await client.query(`UPDATE ofertas_pedido SET estado = 'cancelada'
           WHERE pedido_id = $1 AND estado = 'activa'`, [pedidoId]);
                await client.query(`UPDATE domiciliarios_sesiones ds
           SET disponible = NOT EXISTS (
             SELECT 1 FROM asignaciones_domicilio activas
             WHERE activas.domiciliario_independiente_id = ad.domiciliario_independiente_id
               AND activas.estado IN ('asignado', 'en_camino')
               AND activas.pedido_id <> $1
           )
           FROM asignaciones_domicilio ad
           WHERE ad.pedido_id = $1
             AND ad.tipo_domiciliario = 'independiente'
             AND ad.domiciliario_independiente_id = ds.domiciliario_id
             AND ds.activa = true`, [pedidoId]);
                await this.alertasRiesgo.evaluarCancelacionesFrecuentes(client, sucursalId, usuarioId, pedidoId);
                return {
                    id: pedidoId,
                    estado: nuevoEstado,
                    estado_anterior: anterior,
                    tipo: pedido.tipo,
                    mesa_id: pedido.mesa_id,
                    caja: {
                        devolucion_automatica: reversa.monto_total,
                        ventas_revertidas: reversa.movimientos,
                    },
                    domiciliarios_desasignados: domiciliariosDesasignados.rows
                        .map((r) => r.usuario_id)
                        .filter((id) => Boolean(id)),
                    domiciliarios_independientes_desasignados: domiciliariosDesasignados.rows
                        .map((r) => r.independiente_id)
                        .filter((id) => Boolean(id)),
                };
            }
            return {
                id: pedidoId,
                estado: nuevoEstado,
                estado_anterior: anterior,
                tipo: pedido.tipo,
                mesa_id: pedido.mesa_id,
                mesera_id: pedido.mesera_id,
                numero_pedido: pedido.numero_pedido,
            };
        });
        if (nuevoEstado === 'listo' && result.tipo === 'domicilio') {
            try {
                const dispatchResult = await this.dispatchHooks.intentarDispatchAutomatico(pedidoId, sucursalId);
                const asignado = dispatchResult.iniciado &&
                    (dispatchResult.motivo === 'planta_asignada_auto' ||
                        dispatchResult.motivo === 'ya_asignado');
                if (!asignado) {
                    const detalle = dispatchResult.mensaje ??
                        'No hubo asignación automática. Revisa el panel de domiciliarios.';
                    void this.alertasRiesgo.registrar({
                        sucursalId,
                        tipo: 'domicilio_listo_sin_asignar',
                        nivel: 'medio',
                        descripcion: `Pedido ${pedidoId}: ${detalle}`,
                        referenciaId: pedidoId,
                        referenciaTipo: 'pedido',
                        deduplicar: true,
                    });
                    void this.notificaciones.enviar({
                        sucursal_id: sucursalId,
                        tipo: 'domicilio_requiere_asignacion',
                        titulo: 'Domicilio listo — asignar repartidor',
                        cuerpo: detalle,
                        roles: ['admin', 'gerente', 'domiciliario_planta'],
                        datos: {
                            pedido_id: pedidoId,
                            ruta: '/admin/domiciliarios',
                        },
                    });
                }
            }
            catch {
            }
        }
        if (nuevoEstado === 'en_cocina' && result.estado_anterior !== 'en_cocina') {
            void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);
        }
        if (nuevoEstado === 'pagando' &&
            result.mesera_id) {
            const meseraId = result.mesera_id;
            const num = result.numero_pedido;
            const mesaId = result.mesa_id;
            void this.notificaciones.enviar({
                sucursal_id: sucursalId,
                tipo: 'pedido_a_cobrar',
                titulo: 'Pedido listo para entregar / cobrar',
                cuerpo: `Pedido ${num ? `#${num}` : ''} listo: llévalo a la mesa y gestiona el cobro.`,
                destinatario_usuario_id: meseraId,
                datos: {
                    pedido_id: pedidoId,
                    sucursal_id: sucursalId,
                    mesa_id: mesaId ?? '',
                    ruta: mesaId
                        ? `/admin/mesero?mesa_id=${mesaId}&pedido_id=${pedidoId}&tab=pedidos`
                        : `/admin/mesero?pedido_id=${pedidoId}&tab=pedidos`,
                },
            });
        }
        const { tipo: _tipo, domiciliarios_desasignados: _domiOff, domiciliarios_independientes_desasignados: _domiIndepOff, mesera_id: _mesera, numero_pedido: _num, ...respuesta } = result;
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
        this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
        if (nuevoEstado === 'cancelado' &&
            (_domiOff?.length || _domiIndepOff?.length)) {
            this.soporte.notificarDesasignacionesDomicilio(_domiOff ?? [], pedidoId, _domiIndepOff ?? []);
        }
        return respuesta;
    }
    async aprobarMesa(pedidoId, sucursalId, usuarioId, opciones) {
        const esMesero = opciones?.rolLlamador === 'mesero';
        const meseraBody = opciones?.meseraId?.trim() || undefined;
        if (!esMesero && !meseraBody) {
            throw new common_1.BadRequestException('Debes asignar un mesero');
        }
        const meseraEfectiva = meseraBody ?? usuarioId;
        let catalogoCambios = [];
        let numeroPedido;
        let mesaId = null;
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, mesa_id, tipo, stock_descontado, numero_pedido
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (pedido.estado !== 'pendiente_aprobacion') {
                throw new common_1.BadRequestException('El pedido no está pendiente de aprobación');
            }
            const meseraOk = await this.soporte.consultarUnoCliente(client, `SELECT id, rol, activo FROM usuarios
         WHERE id = $1 AND sucursal_id = $2`, [meseraEfectiva, sucursalId]);
            if (!meseraOk || !meseraOk.activo || meseraOk.rol !== 'mesero') {
                throw new common_1.BadRequestException('El mesero indicado no es válido o no está activo en esta sucursal');
            }
            if (pedido.mesa_id && !meseraBody) {
                await this.soporte.assertMeseraPuedeTomarMesa(client, sucursalId, pedido.mesa_id, meseraEfectiva);
            }
            if (!pedido.stock_descontado) {
                const lineas = await this.inventario.lineasDesdePedido(client, pedidoId, sucursalId);
                await this.inventario.validarStockDisponible(client, sucursalId, lineas, {
                    incluirEmpaques: pedido.tipo === 'domicilio',
                    excluirPedidoIdReservaQr: pedidoId,
                });
                const stock = await this.inventario.descontarStockPedido(client, sucursalId, pedidoId, lineas, { incluirEmpaques: pedido.tipo === 'domicilio' });
                catalogoCambios.push(...stock.catalogo);
                await client.query(`UPDATE pedidos SET stock_descontado = true WHERE id = $1`, [pedidoId]);
            }
            await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId,
                nuevoEstado: 'en_cocina',
                origen: 'aprobacion_qr',
                usuarioId,
                estadoAnterior: 'pendiente_aprobacion',
                tipo: pedido.tipo,
            });
            if (pedido.mesa_id) {
                await this.soporte.asignarMeseraAMesa(client, sucursalId, pedido.mesa_id, meseraEfectiva);
            }
            await client.query(`UPDATE pedidos SET mesera_id = $1, aprobado_at = now() WHERE id = $2`, [meseraEfectiva, pedidoId]);
            numeroPedido = pedido.numero_pedido;
            mesaId = pedido.mesa_id;
            return {
                id: pedidoId,
                estado: 'en_cocina',
                mesera_id: meseraEfectiva,
            };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, 'en_cocina');
        this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
        void this.soporte.notificarCocinasPorPedido(pedidoId, sucursalId);
        const num = numeroPedido ? `#${numeroPedido}` : '';
        void this.notificaciones.enviar({
            sucursal_id: sucursalId,
            tipo: 'pedido_asignado_mesero',
            titulo: 'Pedido asignado a tu mesa',
            cuerpo: `Quedaste a cargo del pedido ${num}. Prepárate para atender y cobrar.`,
            destinatario_usuario_id: meseraEfectiva,
            datos: {
                pedido_id: pedidoId,
                sucursal_id: sucursalId,
                mesa_id: mesaId ?? '',
                ruta: mesaId
                    ? `/admin/mesero?mesa_id=${mesaId}&pedido_id=${pedidoId}`
                    : `/admin/mesero?pedido_id=${pedidoId}`,
            },
        });
        return result;
    }
    async rechazarMesa(pedidoId, sucursalId, usuarioId, motivo) {
        return this.cambiarEstadoDesde(pedidoId, sucursalId, usuarioId, 'pendiente_aprobacion', 'rechazado', motivo);
    }
    async cambiarEstadoDesde(pedidoId, sucursalId, usuarioId, estadoEsperado, nuevoEstado, motivo) {
        let catalogoCambios = [];
        const result = await this.database.enTransaccion(async (client) => {
            const pedido = await this.soporte.consultarUnoCliente(client, `SELECT id, estado, mesa_id, stock_descontado, tipo
         FROM pedidos WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [pedidoId, sucursalId]);
            if (!pedido)
                throw new common_1.NotFoundException('Pedido no encontrado');
            if (pedido.estado !== estadoEsperado) {
                throw new common_1.BadRequestException('El pedido no está pendiente de aprobación');
            }
            if (nuevoEstado === 'rechazado' && pedido.stock_descontado) {
                const restaurado = await this.inventario.restaurarStockPedido(client, sucursalId, pedidoId);
                catalogoCambios.push(...restaurado);
                await client.query(`UPDATE pedidos SET stock_descontado = false WHERE id = $1`, [pedidoId]);
            }
            if (nuevoEstado === 'rechazado') {
                const reversa = await this.cajaAuditoria.revertirVentasPedido(client, pedidoId, sucursalId, usuarioId, motivo ?? 'Pedido rechazado');
                await client.query(`UPDATE pedidos SET monto_pagado = 0 WHERE id = $1`, [pedidoId]);
                await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
                    pedidoId,
                    sucursalId,
                    nuevoEstado,
                    origen: 'kanban',
                    usuarioId,
                    motivo: motivo ?? null,
                    estadoAnterior: estadoEsperado,
                    tipo: pedido.tipo,
                });
                if (pedido.mesa_id) {
                    await this.cuentaMesa.liberarMesaSiSinPedidosActivos(client, pedido.mesa_id, sucursalId);
                }
                return {
                    id: pedidoId,
                    estado: nuevoEstado,
                    caja: {
                        devolucion_automatica: reversa.monto_total,
                        ventas_revertidas: reversa.movimientos,
                    },
                };
            }
            await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId,
                sucursalId,
                nuevoEstado,
                origen: 'kanban',
                usuarioId,
                motivo: motivo ?? null,
                estadoAnterior: estadoEsperado,
                tipo: pedido.tipo,
            });
            return { id: pedidoId, estado: nuevoEstado };
        });
        this.soporte.notificarPedidoRealtime(sucursalId, pedidoId, nuevoEstado);
        this.soporte.notificarCatalogoDisponibilidad(sucursalId, catalogoCambios);
        return result;
    }
    async expirarQrPendientesAlCierreEnTransaccion(client, sucursalId, usuarioId) {
        const minutos = alertas_riesgo_service_1.UMBRALES_ALERTA.qrPendienteAprobacionMinutos;
        const expirados = await client.query(`SELECT id, mesa_id, numero_pedido, stock_descontado FROM pedidos
       WHERE sucursal_id = $1
         AND estado = 'pendiente_aprobacion'
         AND created_at < now() - ($2::text || ' minutes')::interval
       FOR UPDATE`, [sucursalId, String(minutos)]);
        for (const p of expirados.rows) {
            if (p.stock_descontado) {
                const restaurado = await this.inventario.restaurarStockPedido(client, sucursalId, p.id);
                await client.query(`UPDATE pedidos SET stock_descontado = false WHERE id = $1`, [p.id]);
                void restaurado;
            }
            await this.estadoCommand.aplicarEstadoEnTransaccion(client, {
                pedidoId: p.id,
                sucursalId,
                nuevoEstado: 'rechazado',
                origen: 'sistema',
                usuarioId,
                motivo: `QR expirado (>${minutos} min sin aprobación) al cierre de caja`,
                estadoAnterior: 'pendiente_aprobacion',
            });
            if (p.mesa_id) {
                await this.cuentaMesa.liberarMesaSiSinPedidosActivos(client, p.mesa_id, sucursalId);
            }
        }
        if (expirados.rows.length > 0) {
            await this.alertasRiesgo.registrarEnTransaccion(client, {
                sucursalId,
                tipo: 'qr_pendiente_expirado_cierre',
                nivel: 'medio',
                descripcion: `${expirados.rows.length} pedido(s) QR rechazados por expiración al cierre de caja (>${minutos} min)`,
                referenciaTipo: 'sucursal',
                deduplicar: false,
            });
        }
        return expirados.rows.length;
    }
    async cancelarPorCliente(pedidoId, deviceId, motivo) {
        const pedido = await this.database.consultarUno(`SELECT id, sucursal_id, estado, created_at
       FROM pedidos
       WHERE id = $1 AND device_id = $2`, [pedidoId, deviceId]);
        if (!pedido) {
            throw new common_1.NotFoundException('Pedido no encontrado');
        }
        this.soporte.validarCancelacionCliente(pedido, motivo);
        return this.cambiarEstado(pedidoId, pedido.sucursal_id, 'cliente', 'cancelado', motivo.trim(), { rol: 'cliente', permisos: [] });
    }
    async llamarMesera(pedidoId, deviceId, mensaje) {
        const pedido = await this.database.consultarUno(`SELECT id, sucursal_id, mesa_id, estado, numero_pedido
       FROM pedidos
       WHERE id = $1 AND device_id = $2`, [pedidoId, deviceId]);
        if (!pedido) {
            throw new common_1.NotFoundException('Pedido no encontrado');
        }
        this.soporte.validarLlamadaMesera(pedido);
        const ultima = await this.database.consultarUno(`SELECT created_at FROM auditoria_logs
       WHERE accion = 'LLAMAR_MESERA' AND registro_id = $1
       ORDER BY created_at DESC
       LIMIT 1`, [pedidoId]);
        if (ultima) {
            const segundos = (Date.now() - new Date(ultima.created_at).getTime()) / 1000;
            if (segundos < 90) {
                throw new common_1.BadRequestException({
                    error: 'LLAMADA_MESERA_COOLDOWN',
                    message: `Espera ${Math.ceil(90 - segundos)} s antes de volver a llamar`,
                });
            }
        }
        const mesa = pedido.mesa_id
            ? await this.database.consultarUno(`SELECT nombre FROM mesas WHERE id = $1`, [pedido.mesa_id])
            : null;
        await this.auditoria.registrar({
            sucursalId: pedido.sucursal_id,
            accion: 'LLAMAR_MESERA',
            tablaAfectada: 'pedidos',
            registroId: pedidoId,
            datosDespues: {
                mesa_id: pedido.mesa_id,
                mensaje: mensaje?.trim() || null,
            },
        });
        this.soporte.notificarLlamadaMesera(pedido.sucursal_id, pedidoId, pedido.numero_pedido, pedido.mesa_id, mesa?.nombre, mensaje);
        return {
            pedido_id: pedidoId,
            mesa_id: pedido.mesa_id,
            mensaje: 'Avisamos a la mesera. Te atenderán en breve.',
        };
    }
    async calificarDomicilio(pedidoId, deviceId, calificacion, comentario) {
        const pedido = await this.database.consultarUno(`SELECT id, tipo, estado FROM pedidos
       WHERE id = $1 AND device_id = $2`, [pedidoId, deviceId]);
        if (!pedido) {
            throw new common_1.NotFoundException('Pedido no encontrado');
        }
        if (pedido.tipo !== 'domicilio') {
            throw new common_1.BadRequestException({
                error: 'TIPO_PEDIDO_INVALIDO',
                message: 'Solo puedes calificar pedidos a domicilio',
            });
        }
        if (pedido.estado !== 'entregado' && pedido.estado !== 'pagado') {
            throw new common_1.BadRequestException({
                error: 'PEDIDO_NO_ENTREGADO',
                message: 'Califica cuando el pedido esté entregado',
            });
        }
        const asignacion = await this.database.consultarUno(`SELECT id FROM asignaciones_domicilio
       WHERE pedido_id = $1 AND estado = 'entregado'
       ORDER BY entregado_at DESC NULLS LAST
       LIMIT 1`, [pedidoId]);
        if (!asignacion) {
            throw new common_1.BadRequestException('Sin asignación de domicilio entregada');
        }
        const ya = await this.database.consultarUno(`SELECT id FROM calificaciones_domiciliario
       WHERE asignacion_id = $1 AND device_id = $2`, [asignacion.id, deviceId]);
        if (ya) {
            throw new common_1.BadRequestException({
                error: 'CALIFICACION_YA_REGISTRADA',
                message: 'Ya calificaste este pedido',
            });
        }
        await this.database.consultar(`INSERT INTO calificaciones_domiciliario
         (asignacion_id, device_id, calificacion, comentario)
       VALUES ($1, $2, $3, $4)`, [asignacion.id, deviceId, calificacion, comentario?.trim() || null]);
        return {
            pedido_id: pedidoId,
            calificacion,
            mensaje: 'Gracias por tu calificación',
        };
    }
};
exports.PedidosEstadoService = PedidosEstadoService;
exports.PedidosEstadoService = PedidosEstadoService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        pedidos_dispatch_hooks_service_1.PedidosDispatchHooksService,
        alertas_riesgo_service_1.AlertasRiesgoService,
        costeo_service_1.CosteoService,
        pedidos_caja_auditoria_service_1.PedidosCajaAuditoriaService,
        pedidos_cuenta_mesa_service_1.PedidosCuentaMesaService,
        pedidos_soporte_service_1.PedidosSoporteService,
        pedidos_estado_command_service_1.PedidosEstadoCommandService,
        pedidos_inventario_service_1.PedidosInventarioService,
        auditoria_service_1.AuditoriaService,
        notificaciones_service_1.NotificacionesService])
], PedidosEstadoService);
//# sourceMappingURL=pedidos-estado.service.js.map