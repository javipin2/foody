import { DatabaseService } from '../../core/database/database.service';
import { DispatchService } from '../domiciliarios/dispatch.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { PedidosCajaAuditoriaService } from './pedidos-caja-auditoria.service';
import { PedidosCuentaMesaService } from './pedidos-cuenta-mesa.service';
import { PedidosSoporteService } from './pedidos-soporte.service';
export declare class PedidosEstadoService {
    private readonly database;
    private readonly dispatch;
    private readonly alertasRiesgo;
    private readonly costeo;
    private readonly cajaAuditoria;
    private readonly cuentaMesa;
    private readonly soporte;
    private readonly inventario;
    constructor(database: DatabaseService, dispatch: DispatchService, alertasRiesgo: AlertasRiesgoService, costeo: CosteoService, cajaAuditoria: PedidosCajaAuditoriaService, cuentaMesa: PedidosCuentaMesaService, soporte: PedidosSoporteService);
    cambiarEstado(pedidoId: string, sucursalId: string, usuarioId: string, nuevoEstado: string, motivo?: string, contexto?: {
        rol: string;
        permisos: string[];
    }): Promise<{
        id: string;
        estado: string;
        mesa_id: string | null;
        estado_anterior?: undefined;
    } | {
        id: string;
        estado: string;
        estado_anterior: string;
        mesa_id: string | null;
    }>;
    aprobarMesa(pedidoId: string, sucursalId: string, usuarioId: string): Promise<{
        id: string;
        estado: string;
    }>;
    rechazarMesa(pedidoId: string, sucursalId: string, usuarioId: string, motivo: string): Promise<{
        id: string;
        estado: string;
    }>;
    private cambiarEstadoDesde;
}
