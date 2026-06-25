import { QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { PedidosCajaAuditoriaService } from '../pedidos/pedidos-caja-auditoria.service';
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
export declare class DomiciliariosService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly realtime;
    private readonly cajaAuditoria;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, realtime: RealtimeBroadcastService, cajaAuditoria: PedidosCajaAuditoriaService);
    listarPlantaDisponibles(sucursalId: string): Promise<QueryResultRow[]>;
    asignarPlanta(dto: AsignarDomiciliarioDto, usuarioAdminId: string): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    historialEntregas(usuarioId: string, limite?: number): Promise<QueryResultRow[]>;
    estadisticasPlanta(usuarioId: string): Promise<{
        entregas_hoy: number;
        entregas_semana: number;
        entregas_mes: number;
        tiempo_promedio_min: number | null;
    }>;
    pedidosAsignados(usuarioId: string): Promise<QueryResultRow[]>;
    marcarEnCamino(pedidoId: string, usuarioId: string): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    confirmarEntrega(pedidoId: string, usuarioId: string, dto: ConfirmarEntregaDto): Promise<{
        pedido_id: string;
        estado: string;
    }>;
    private obtenerPlantaPorUsuario;
    private consultarUno;
}
