import { JwtPayload } from '../../core/auth/jwt-payload';
import { ActualizarHorarioDto } from './dto/actualizar-horario.dto';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';
import { RestaurantesService } from './restaurantes.service';
export declare class SucursalesStaffController {
    private readonly restaurantes;
    constructor(restaurantes: RestaurantesService);
    listarMiRestaurante(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crear(usuario: JwtPayload, dto: CrearSucursalDto): Promise<{
        id: string;
        nombre: string;
        restaurante_id: string;
        ciudad_id: string;
    }>;
    listarHorarios(usuario: JwtPayload, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    actualizarHorario(usuario: JwtPayload, horarioId: string, dto: ActualizarHorarioDto): Promise<{
        id: string;
        dia_semana: number;
        hora_apertura: string;
        hora_cierre: string;
        activo: boolean;
    }>;
}
