import { JwtPayload } from '../../core/auth/jwt-payload';
import { CocinasService } from './cocinas.service';
import { ActualizarCocinaDto, CrearCocinaDto } from './dto/cocina.dto';
export declare class CocinasController {
    private readonly cocinas;
    constructor(cocinas: CocinasService);
    listar(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearCocinaDto): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, dto: ActualizarCocinaDto, usuario: JwtPayload): Promise<{
        id: string;
    }>;
    eliminar(id: string, usuario: JwtPayload): Promise<{
        id: string;
        activa: boolean;
    }>;
}
