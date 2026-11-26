import { JwtPayload } from '../../core/auth/jwt-payload';
import { CocinasService } from './cocinas.service';
import { CambiarEstadoItemDto, FalloPreparacionDto, NoDisponibleTareaComboDto } from './dto/cocina.dto';
import { ActualizarObservacionesItemDto, PrioridadItemCocinaDto } from './dto/item-kds-mutacion.dto';
export declare class CocinaTicketsController {
    private readonly cocinas;
    constructor(cocinas: CocinasService);
    listarCocinas(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    tickets(cocinaId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    cambiarEstadoItem(itemId: string, dto: CambiarEstadoItemDto, usuario: JwtPayload): Promise<{
        item_id: string;
        estado_cocina: "pendiente" | "listo" | "no_disponible" | "preparando";
        pedido_id: string;
        estado_pedido: string;
        cocina_id: string | null;
        numero_pedido: string;
        sucursal_id: string;
        catalogo_off_producto_id: string | null;
    }>;
    cambiarEstadoTareaCombo(tareaId: string, dto: CambiarEstadoItemDto, usuario: JwtPayload): Promise<{
        tarea_id: string;
        pedido_item_id: string;
        estado_cocina: "pendiente" | "listo" | "preparando";
        estado_linea: string;
        pedido_id: string;
        estado_pedido: string;
        cocina_id: string;
        numero_pedido: string;
        sucursal_id: string;
    }>;
    marcarTareaComboNoDisponible(tareaId: string, dto: NoDisponibleTareaComboDto, usuario: JwtPayload): Promise<{
        pedido_id: string;
        pedido_item_id: string;
        tarea_id: string;
        decision_id: string;
        estado_linea: string;
        idempotente: boolean;
    }>;
    falloPreparacion(itemId: string, dto: FalloPreparacionDto, usuario: JwtPayload): Promise<{
        item_id: string;
        estado_cocina: "pendiente" | "listo" | "no_disponible" | "preparando";
        pedido_id: string;
        estado_pedido: string;
        cocina_id: string | null;
        numero_pedido: string;
        sucursal_id: string;
        catalogo_off_producto_id: string | null;
    }>;
    actualizarObservaciones(itemId: string, body: ActualizarObservacionesItemDto, usuario: JwtPayload): Promise<{
        item_id: string;
        observaciones: string;
    }>;
    prioridad(itemId: string, body: PrioridadItemCocinaDto, usuario: JwtPayload): Promise<{
        item_id: string;
        observaciones: string;
    }>;
}
