import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { PedidosCajaAuditoriaService } from './pedidos-caja-auditoria.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosInventarioService } from './pedidos-inventario.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { PedidosSoporteService } from './pedidos-soporte.service';
import { PedidosEstadoCommandService } from './pedidos-estado-command.service';
import { PedidosDispatchHooksService } from './pedidos-dispatch-hooks.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
export declare class PedidosEstadoService {
    private readonly database;
    private readonly dispatchHooks;
    private readonly alertasRiesgo;
    private readonly costeo;
    private readonly cajaAuditoria;
    private readonly cuentaMesa;
    private readonly soporte;
    private readonly estadoCommand;
    private readonly inventario;
    private readonly auditoria;
    private readonly notificaciones;
    constructor(database: DatabaseService, dispatchHooks: PedidosDispatchHooksService, alertasRiesgo: AlertasRiesgoService, costeo: CosteoService, cajaAuditoria: PedidosCajaAuditoriaService, cuentaMesa: PedidosCuentaMesaService, soporte: PedidosSoporteService, estadoCommand: PedidosEstadoCommandService, inventario: PedidosInventarioService, auditoria: AuditoriaService, notificaciones: NotificacionesService);
    cambiarEstado(pedidoId: string, sucursalId: string, usuarioId: string | null, nuevoEstado: string, motivo?: string, contexto?: {
        rol: string;
        permisos: string[];
    }): Promise<{
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
        caja?: undefined;
    } | {
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
        caja: {
            devolucion_automatica: number;
            ventas_revertidas: number;
        };
    }>;
    aprobarMesa(pedidoId: string, sucursalId: string, usuarioId: string, opciones?: {
        meseraId?: string;
        rolLlamador?: string;
    }): Promise<{
        id: string;
        estado: string;
        mesera_id: string;
    }>;
    rechazarMesa(pedidoId: string, sucursalId: string, usuarioId: string, motivo: string): Promise<{
        id: string;
        estado: string;
        caja: {
            devolucion_automatica: number;
            ventas_revertidas: number;
        };
    } | {
        id: string;
        estado: string;
        caja?: undefined;
    }>;
    private cambiarEstadoDesde;
    expirarQrPendientesAlCierreEnTransaccion(client: PoolClient, sucursalId: string, usuarioId: string | null): Promise<number>;
    cancelarPorCliente(pedidoId: string, deviceId: string, motivo: string): Promise<{
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
        caja?: undefined;
    } | {
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
        caja: {
            devolucion_automatica: number;
            ventas_revertidas: number;
        };
    }>;
    llamarMesera(pedidoId: string, deviceId: string, mensaje?: string): Promise<{
        pedido_id: string;
        mesa_id: string | null;
        mensaje: string;
    }>;
    calificarDomicilio(pedidoId: string, deviceId: string, calificacion: number, comentario?: string): Promise<{
        pedido_id: string;
        calificacion: number;
        mensaje: string;
    }>;
}
