import { DatabaseService } from '../../core/database/database.service';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { ActualizarHorarioDto } from './dto/actualizar-horario.dto';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';
export declare class RestaurantesService {
    private readonly database;
    private readonly planFeatures;
    constructor(database: DatabaseService, planFeatures: PlanFeaturesService);
    listarSucursales(restauranteId: string): Promise<import("pg").QueryResultRow[]>;
    listarSucursalesStaff(restauranteId: string, usuarioRestauranteId: string): Promise<import("pg").QueryResultRow[]>;
    crearSucursal(restauranteId: string, usuarioRestauranteId: string, dto: CrearSucursalDto): Promise<{
        id: string;
        nombre: string;
        restaurante_id: string;
        ciudad_id: string;
    }>;
    private exigirSucursalDelRestaurante;
    listarHorarios(sucursalId: string, restauranteId: string): Promise<import("pg").QueryResultRow[]>;
    actualizarHorario(horarioId: string, restauranteId: string, dto: ActualizarHorarioDto): Promise<{
        id: string;
        dia_semana: number;
        hora_apertura: string;
        hora_cierre: string;
        activo: boolean;
    }>;
}
