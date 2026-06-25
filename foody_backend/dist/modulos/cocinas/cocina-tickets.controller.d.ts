import { JwtPayload } from '../../core/auth/jwt-payload';
import { CocinasService } from './cocinas.service';
import { CambiarEstadoItemDto } from './dto/cocina.dto';
export declare class CocinaTicketsController {
    private readonly cocinas;
    constructor(cocinas: CocinasService);
    listarCocinas(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    tickets(cocinaId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    cambiarEstadoItem(itemId: string, dto: CambiarEstadoItemDto, usuario: JwtPayload): Promise<{
        item_id: string;
        estado_cocina: "listo" | "pendiente" | "preparando" | "no_disponible";
        pedido_id: string;
        estado_pedido: string;
        cocina_id: string | null;
        numero_pedido: string;
        sucursal_id: string;
    }>;
    actualizarObservaciones(itemId: string, body: {
        observaciones: string;
    }, usuario: JwtPayload): Promise<{
        item_id: string;
        observaciones: string;
    }>;
    prioridad(itemId: string, body: {
        urgente: boolean;
    }, usuario: JwtPayload): Promise<{
        item_id: string;
        observaciones: string;
    }>;
}
