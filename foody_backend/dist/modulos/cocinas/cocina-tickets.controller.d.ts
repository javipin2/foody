import { JwtPayload } from '../../core/auth/jwt-payload';
import { CocinasService } from './cocinas.service';
import { CambiarEstadoItemDto, FalloPreparacionDto } from './dto/cocina.dto';
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
