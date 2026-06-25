import { JwtPayload } from '../../core/auth/jwt-payload';
import { CocinasService } from './cocinas.service';
import { ActualizarImpresoraDto, CrearImpresoraDto } from './dto/cocina.dto';
export declare class ImpresorasController {
    private readonly cocinas;
    constructor(cocinas: CocinasService);
    listar(sucursalId: string, cocinaId?: string): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearImpresoraDto): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, dto: ActualizarImpresoraDto, usuario: JwtPayload): Promise<{
        id: string;
    }>;
    eliminar(id: string, usuario: JwtPayload): Promise<{
        id: string;
        activa: boolean;
    }>;
}
