import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { ImpresionService } from '../../core/impresion/impresion.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
export type OpcionesStaffPedido = {
    creadoPorStaff?: boolean;
    usuarioId?: string;
    rol?: string;
    puedeCobrar?: boolean;
    soloEstimar?: boolean;
};
export declare class PedidosSoporteService {
    private readonly database;
    private readonly realtime;
    private readonly notificaciones;
    private readonly impresion;
    private readonly logger;
    constructor(database: DatabaseService, realtime: RealtimeBroadcastService, notificaciones: NotificacionesService, impresion: ImpresionService);
    obtenerSeguimientoToken(pedidoId: string): Promise<string | null>;
    emitirSeguimientoPedido(pedidoId: string, payload: Record<string, unknown>): void;
    emitirUbicacionRepartidor(pedidoId: string, payload: Record<string, unknown>): void;
    consultarUnoCliente<T extends QueryResultRow>(client: PoolClient, sql: string, parametros: unknown[]): Promise<T | null>;
    esRolMesero(rol?: string): boolean;
    assertMeseraPuedeTomarMesa(client: PoolClient, sucursalId: string, mesaId: string, meseraId: string): Promise<void>;
    asignarMeseraAMesa(client: PoolClient, sucursalId: string, mesaId: string, meseraId: string): Promise<void>;
    resolverEstadoInicial(dto: CrearPedidoDto, creadoPorStaff?: boolean): string;
    generarNumeroPedido(client: PoolClient, sucursalId: string): Promise<string>;
    precioVentaProducto(producto: {
        precio: string;
        precio_para_llevar: string | null;
    }, tipoPedido: string): number;
    validarCancelacion(pedido: {
        estado: string;
        created_at: Date;
    }, rol: string, _permisos: string[], motivo?: string): void;
    validarCancelacionCliente(pedido: {
        estado: string;
        created_at: Date;
    }, motivo?: string): void;
    validarLlamadaMesera(pedido: {
        mesa_id: string | null;
        estado: string;
    }): void;
    notificarLlamadaMesera(sucursalId: string, pedidoId: string, numeroPedido: string, mesaId: string | null, mesaNombre?: string | null, mensajeCliente?: string): void;
    notificarDesasignacionesDomicilio(usuarioIds: string[], pedidoId: string, independientesIds?: string[]): void;
    notificarPedidoRealtime(sucursalId: string, pedidoId: string, estado: string, numeroPedido?: string, opciones?: {
        mesaId?: string | null;
        creadoAt?: Date | string;
    }): void;
    private notificarPushPedido;
    private notificarPushCliente;
    notificarCatalogoDisponibilidad(sucursalId: string, cambios: {
        producto_id: string;
        disponible: boolean;
    }[]): void;
    notificarCocinasPorPedido(pedidoId: string, sucursalId: string): Promise<void>;
    private errorTexto;
}
