import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { ActualizarCocinaDto, ActualizarImpresoraDto, CrearCocinaDto, CrearImpresoraDto } from './dto/cocina.dto';
type EstadoItem = 'pendiente' | 'preparando' | 'listo' | 'no_disponible';
export declare class CocinasService {
    private readonly database;
    private readonly realtime;
    private readonly alertasRiesgo;
    constructor(database: DatabaseService, realtime: RealtimeBroadcastService, alertasRiesgo: AlertasRiesgoService);
    listarCocinas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
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
    cambiarEstadoItem(itemId: string, sucursalId: string, estado: EstadoItem, usuarioId: string | null, motivo?: string): Promise<{
        item_id: string;
        estado_cocina: EstadoItem;
        pedido_id: string;
        estado_pedido: string;
        cocina_id: string | null;
        numero_pedido: string;
        sucursal_id: string;
    }>;
    actualizarObservacionesItem(itemId: string, sucursalId: string, observaciones: string): Promise<{
        item_id: string;
        observaciones: string;
    }>;
    marcarPrioridadItem(itemId: string, sucursalId: string, urgente: boolean): Promise<{
        item_id: string;
        observaciones: string;
    }>;
    private evaluarDemorasEnCocina;
    private exigirCocina;
    private exigirImpresora;
}
export {};
