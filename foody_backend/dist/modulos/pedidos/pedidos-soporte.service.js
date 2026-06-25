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
exports.PedidosSoporteService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const impresion_service_1 = require("../../core/impresion/impresion.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const notificaciones_service_1 = require("../notificaciones/notificaciones.service");
let PedidosSoporteService = class PedidosSoporteService {
    database;
    realtime;
    notificaciones;
    impresion;
    constructor(database, realtime, notificaciones, impresion) {
        this.database = database;
        this.realtime = realtime;
        this.notificaciones = notificaciones;
        this.impresion = impresion;
    }
    async consultarUnoCliente(client, sql, parametros) {
        const resultado = await client.query(sql, parametros);
        return resultado.rows[0] ?? null;
    }
    esRolMesero(rol) {
        return rol === 'mesero';
    }
    async assertMeseraPuedeTomarMesa(client, sucursalId, mesaId, meseraId) {
        const mesa = await this.consultarUnoCliente(client, `SELECT mesera_asignada_id FROM mesas
       WHERE id = $1 AND sucursal_id = $2 AND activa = true`, [mesaId, sucursalId]);
        if (!mesa)
            throw new common_1.BadRequestException('MESA_NO_ENCONTRADA');
        if (mesa.mesera_asignada_id != null &&
            mesa.mesera_asignada_id !== meseraId) {
            throw new common_1.BadRequestException({
                error: 'MESA_ASIGNADA_OTRA_MESERA',
                message: 'Esta mesa está siendo atendida por otra mesera. Pide transferencia al admin.',
            });
        }
    }
    async asignarMeseraAMesa(client, sucursalId, mesaId, meseraId) {
        await client.query(`UPDATE mesas
       SET mesera_asignada_id = $1, mesera_asignada_at = now()
       WHERE id = $2 AND sucursal_id = $3`, [meseraId, mesaId, sucursalId]);
    }
    resolverEstadoInicial(dto, creadoPorStaff) {
        if (creadoPorStaff) {
            if (dto.tipo === 'mesa' && !dto.mesa_id) {
                throw new common_1.BadRequestException('MESA_REQUERIDA');
            }
            if (dto.tipo === 'domicilio') {
                return 'pendiente';
            }
            return 'en_cocina';
        }
        if (dto.tipo === 'mesa') {
            return 'pendiente_aprobacion';
        }
        return 'pendiente';
    }
    async generarNumeroPedido(client, sucursalId) {
        const anio = new Date().getFullYear();
        const fila = await this.consultarUnoCliente(client, `SELECT COUNT(*)::int AS n FROM pedidos
       WHERE sucursal_id = $1
         AND EXTRACT(YEAR FROM created_at) = $2`, [sucursalId, anio]);
        const secuencia = (fila?.n ?? 0) + 1;
        return `FDY-${anio}-${String(secuencia).padStart(4, '0')}`;
    }
    precioVentaProducto(producto, tipoPedido) {
        const local = Number(producto.precio);
        if (tipoPedido === 'para_llevar' || tipoPedido === 'domicilio') {
            return producto.precio_para_llevar != null
                ? Number(producto.precio_para_llevar)
                : local;
        }
        return local;
    }
    validarCancelacion(pedido, rol, _permisos, motivo) {
        if (!motivo?.trim()) {
            throw new common_1.BadRequestException('Se requiere un motivo para cancelar el pedido');
        }
        const esElevado = rol === 'admin' || rol === 'gerente';
        const estadosRestringidos = [
            'en_cocina',
            'listo',
            'asignado',
            'en_camino',
            'entregado',
            'pagado',
        ];
        if (estadosRestringidos.includes(pedido.estado) && !esElevado) {
            throw new common_1.BadRequestException('Solo admin o gerente puede cancelar un pedido en esta etapa');
        }
        const minutos = (Date.now() - new Date(pedido.created_at).getTime()) / 60000;
        if (minutos > 2 && !esElevado) {
            throw new common_1.BadRequestException('Solo admin o gerente puede cancelar después de 2 minutos');
        }
    }
    notificarPedidoRealtime(sucursalId, pedidoId, estado, numeroPedido, opciones = {}) {
        void this.realtime.pedidoActualizado({
            pedido_id: pedidoId,
            sucursal_id: sucursalId,
            estado,
            numero_pedido: numeroPedido,
        });
        void this.realtime.pedidoSeguimiento(pedidoId, { pedido_id: pedidoId, estado });
        if (estado === 'pendiente_aprobacion') {
            void this.realtime.mesasActualizadas(sucursalId);
            void this.realtime.qrAprobacionUrgente(sucursalId, {
                pedido_id: pedidoId,
                mesa_id: opciones.mesaId ?? null,
                numero_pedido: numeroPedido,
                creado_at: opciones.creadoAt != null
                    ? new Date(opciones.creadoAt).toISOString()
                    : new Date().toISOString(),
                nivel: 'nuevo',
            });
        }
        void this.notificarPushPedido(sucursalId, pedidoId, estado, numeroPedido, opciones.mesaId);
    }
    notificarPushPedido(sucursalId, pedidoId, estado, numeroPedido, mesaId) {
        const num = numeroPedido ? `#${numeroPedido}` : 'nuevo';
        const base = {
            sucursal_id: sucursalId,
            datos: {
                pedido_id: pedidoId,
                sucursal_id: sucursalId,
                mesa_id: mesaId ?? '',
            },
        };
        if (estado === 'pendiente_aprobacion') {
            void this.notificaciones.enviar({
                ...base,
                tipo: 'qr_pendiente_aprobacion',
                titulo: 'Aprobar pedido de mesa',
                cuerpo: `Pedido ${num} espera aprobación QR`,
                roles: ['mesero', 'admin', 'gerente', 'cajero'],
                datos: {
                    ...base.datos,
                    ruta: '/admin/mesero',
                },
            });
            return;
        }
        if (estado === 'pendiente') {
            void this.notificaciones.enviar({
                ...base,
                tipo: 'pedido_nuevo',
                titulo: 'Nuevo pedido',
                cuerpo: `Pedido ${num} por confirmar`,
                roles: ['cajero', 'admin', 'mesero'],
                datos: {
                    ...base.datos,
                    ruta: '/admin/panel?tab=pedidos',
                },
            });
            return;
        }
        if (estado === 'confirmado' || estado === 'en_cocina') {
            void this.notificaciones.enviar({
                ...base,
                tipo: 'pedido_cocina',
                titulo: 'Nuevo pedido en cocina',
                cuerpo: `Pedido ${num} para preparar`,
                roles: ['cocina', 'admin'],
                datos: {
                    ...base.datos,
                    ruta: '/admin/cocina',
                },
            });
            if (estado === 'en_cocina' || estado === 'confirmado') {
                void this.notificarPushCliente(pedidoId, 'Pedido en preparación', `Tu pedido ${num} está en cocina`);
            }
            return;
        }
        if (estado === 'listo') {
            void this.notificaciones.enviar({
                ...base,
                tipo: 'pedido_listo',
                titulo: 'Pedido listo',
                cuerpo: `Pedido ${num} listo para servir`,
                roles: ['mesero', 'cajero', 'admin', 'domiciliario_planta'],
                datos: {
                    ...base.datos,
                    ruta: '/admin/panel?tab=pedidos',
                },
            });
            void this.notificarPushCliente(pedidoId, 'Tu pedido está listo', `Pedido ${num}`);
            return;
        }
        if (estado === 'en_camino' || estado === 'asignado') {
            void this.notificarPushCliente(pedidoId, 'Pedido en camino', `Tu pedido ${num} va hacia ti`);
            return;
        }
        if (estado === 'entregado') {
            void this.notificarPushCliente(pedidoId, 'Pedido entregado', `Pedido ${num} entregado. ¡Buen provecho!`);
            return;
        }
        if (estado === 'cancelado' || estado === 'rechazado') {
            void this.notificarPushCliente(pedidoId, 'Pedido cancelado', `Tu pedido ${num} fue cancelado`);
        }
    }
    async notificarPushCliente(pedidoId, titulo, cuerpo) {
        const pedido = await this.database.consultarUno(`SELECT device_id, sucursal_id FROM pedidos WHERE id = $1`, [pedidoId]);
        if (!pedido?.device_id)
            return;
        await this.notificaciones.enviar({
            sucursal_id: pedido.sucursal_id,
            tipo: 'pedido_cliente',
            titulo,
            cuerpo,
            device_id: pedido.device_id,
            datos: {
                pedido_id: pedidoId,
                ruta: `/pedidos/${pedidoId}/seguimiento`,
            },
        });
    }
    notificarCatalogoDisponibilidad(sucursalId, cambios) {
        if (!cambios.length)
            return;
        const agotados = cambios
            .filter((c) => !c.disponible)
            .map((c) => c.producto_id);
        const reactivados = cambios
            .filter((c) => c.disponible)
            .map((c) => c.producto_id);
        if (agotados.length) {
            void this.realtime.catalogoDisponibilidad(sucursalId, {
                producto_ids: agotados,
                disponible: false,
            });
        }
        if (reactivados.length) {
            void this.realtime.catalogoDisponibilidad(sucursalId, {
                producto_ids: reactivados,
                disponible: true,
            });
        }
    }
    async notificarCocinasPorPedido(pedidoId, sucursalId) {
        const filas = await this.database.consultar(`SELECT DISTINCT pi.cocina_id
       FROM pedido_items pi
       INNER JOIN pedidos p ON p.id = pi.pedido_id
       WHERE pi.pedido_id = $1 AND p.sucursal_id = $2 AND pi.cocina_id IS NOT NULL`, [pedidoId, sucursalId]);
        for (const f of filas) {
            void this.realtime.cocinaActualizada(f.cocina_id, {
                pedido_id: pedidoId,
                sucursal_id: sucursalId,
            });
        }
        void this.impresion.encolarPorPedido(pedidoId, sucursalId);
    }
};
exports.PedidosSoporteService = PedidosSoporteService;
exports.PedidosSoporteService = PedidosSoporteService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        notificaciones_service_1.NotificacionesService,
        impresion_service_1.ImpresionService])
], PedidosSoporteService);
//# sourceMappingURL=pedidos-soporte.service.js.map