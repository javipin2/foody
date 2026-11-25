import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { DispatchService } from '../domiciliarios/dispatch.service';
import { ActualizarCocinaDto, ActualizarImpresoraDto, CrearCocinaDto, CrearImpresoraDto } from './dto/cocina.dto';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { PedidosInventarioService } from '../pedidos/pedidos-inventario.service';
import { PedidosSoporteService } from '../pedidos/pedidos-soporte.service';
type EstadoItem = 'pendiente' | 'preparando' | 'listo' | 'no_disponible';
export declare class CocinasService {
    private readonly database;
    private readonly realtime;
    private readonly menuCache;
    private readonly alertasRiesgo;
    private readonly dispatch;
    private readonly pedidosEstadoCommand;
    private readonly pedidosSoporte;
    private readonly pedidosInventario;
    constructor(database: DatabaseService, realtime: RealtimeBroadcastService, menuCache: MenuCacheService, alertasRiesgo: AlertasRiesgoService, dispatch: DispatchService, pedidosEstadoCommand: PedidosEstadoCommandService, pedidosSoporte: PedidosSoporteService, pedidosInventario: PedidosInventarioService);
    listarCocinas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    listarCocinasParaKds(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    exigirAccesoCocinaKds(usuario: JwtPayload, cocinaId: string): Promise<void>;
    exigirAccesoItemKds(usuario: JwtPayload, itemId: string): Promise<void>;
    private cocinaAsignadaUsuario;
    crearCocina(dto: CrearCocinaDto): Promise<import("pg").QueryResultRow | null>;
    actualizarCocina(id: string, sucursalId: string, dto: ActualizarCocinaDto): Promise<{
        id: string;
    }>;
    eliminarCocina(id: string, sucursalId: string): Promise<{
        id: string;
        activa: boolean;
    }>;
    listarImpresoras(sucursalId: string, cocinaId?: string): Promise<import("pg").QueryResultRow[]>;
    crearImpresora(dto: CrearImpresoraDto): Promise<import("pg").QueryResultRow | null>;
    actualizarImpresora(id: string, sucursalId: string, dto: ActualizarImpresoraDto): Promise<{
        id: string;
    }>;
    eliminarImpresora(id: string, sucursalId: string): Promise<{
        id: string;
        activa: boolean;
    }>;
    listarTickets(cocinaId: string, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    cambiarEstadoItem(itemId: string, sucursalId: string, estado: EstadoItem, usuarioId: string | null, motivo?: string, opciones?: {
        falloPreparacion?: boolean;
    }): Promise<{
        item_id: string;
        estado_cocina: EstadoItem;
        pedido_id: string;
        estado_pedido: string;
        cocina_id: string | null;
        numero_pedido: string;
        sucursal_id: string;
        catalogo_off_producto_id: string | null;
    }>;
    falloPreparacion(itemId: string, sucursalId: string, usuarioId: string | null, motivo: string): Promise<{
        item_id: string;
        estado_cocina: EstadoItem;
        pedido_id: string;
        estado_pedido: string;
        cocina_id: string | null;
        numero_pedido: string;
        sucursal_id: string;
        catalogo_off_producto_id: string | null;
    }>;
    private intentarDispatchDomicilioSiListo;
    actualizarObservacionesItem(itemId: string, sucursalId: string, observaciones: string): Promise<{
        item_id: string;
        observaciones: string;
    }>;
    marcarPrioridadItem(itemId: string, sucursalId: string, urgente: boolean): Promise<{
        item_id: string;
        observaciones: string;
    }>;
    private exigirCocina;
    private exigirImpresora;
}
export {};
