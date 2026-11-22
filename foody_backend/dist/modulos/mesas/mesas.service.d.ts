import { DatabaseService } from '../../core/database/database.service';
import { PedidosCuentaMesaService } from '../pedidos/pedidos-cuenta-mesa.service';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { ActualizarMesaDto } from './dto/crear-mesa.dto';
import { CrearMesaDto } from './dto/crear-mesa.dto';
import { TransferirMesaDto } from './dto/transferir-mesa.dto';
import { AsignarTurnoMesasDto } from './dto/asignar-turno-mesas.dto';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
export declare class MesasService {
    private readonly database;
    private readonly realtime;
    private readonly alertasRiesgo;
    private readonly planFeatures;
    private readonly cuentaMesa;
    private readonly auditoria;
    private readonly estadoPedido;
    constructor(database: DatabaseService, realtime: RealtimeBroadcastService, alertasRiesgo: AlertasRiesgoService, planFeatures: PlanFeaturesService, cuentaMesa: PedidosCuentaMesaService, auditoria: AuditoriaService, estadoPedido: PedidosEstadoCommandService);
    listarConEstado(sucursalId: string, incluirInactivas?: boolean): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearMesaDto, restauranteId?: string): Promise<import("pg").QueryResultRow | null>;
    actualizar(mesaId: string, sucursalId: string, dto: ActualizarMesaDto): Promise<import("pg").QueryResultRow | {
        id: string;
        nombre: string;
        qr_token: string;
        activa: boolean;
        sucursal_id: string;
    } | null>;
    asignarTurno(dto: AsignarTurnoMesasDto): Promise<{
        sucursal_id: string;
        mesas_actualizadas: number;
    }>;
    desactivar(mesaId: string, sucursalId: string): Promise<import("pg").QueryResultRow | {
        id: string;
        nombre: string;
        qr_token: string;
        activa: boolean;
        sucursal_id: string;
    } | null>;
    reservar(mesaId: string, sucursalId: string, dto: {
        cliente_nombre: string;
        cliente_telefono?: string;
        reserva_hasta: string;
    }): Promise<{
        mesa_id: string;
        estado_operativo: string;
    }>;
    cancelarReserva(mesaId: string, sucursalId: string): Promise<{
        mesa_id: string;
        estado_operativo: string;
    }>;
    unirMesas(sucursalId: string, mesaPrincipalId: string, mesasSecundarias: string[], usuarioId: string): Promise<{
        mesa_principal_id: string;
        mesas_unidas: string[];
    }>;
    registrarSalidaSinPagar(mesaId: string, sucursalId: string, usuarioId: string, dto: {
        cliente_nombre: string;
        cliente_telefono?: string;
        motivo: string;
    }, rolUsuario?: string | null): Promise<{
        mesa_id: string;
        mesas_liberadas: string[];
        cuentas_creadas: {
            pedido_id: string;
            monto: number;
        }[];
        pedidos_cerrados: {
            id: string;
            numero_pedido: string;
            estado_anterior: string;
            saldo_cxc: number;
        }[];
    }>;
    transferir(dto: TransferirMesaDto, usuarioId: string): Promise<{
        transferencia_id: string;
        pedido_id: string;
        numero_pedido: string;
        mesa_origen_id: string;
        mesa_destino_id: string;
        total_transferencias: number;
        alerta_transferencias_multiples: boolean;
    }>;
    private normalizarOrigenWeb;
    obtenerQr(mesaId: string, sucursalId: string, baseUrl?: string): Promise<{
        mesa: {
            id: string;
            nombre: string;
            qr_token: string;
            activa: boolean;
            sucursal_id: string;
        };
        url: string;
        html: string;
    }>;
    private resolverIdsMesasGrupo;
    private obtenerMesa;
    private generarQrToken;
    private generarHtmlQr;
}
