import { DatabaseService } from '../../core/database/database.service';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { ActualizarHorarioDto } from './dto/actualizar-horario.dto';
import { ActualizarMargenesSucursalDto } from './dto/actualizar-margenes-sucursal.dto';
import { ActualizarSucursalDto } from './dto/actualizar-sucursal.dto';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';
export declare class RestaurantesService {
    private readonly database;
    private readonly planFeatures;
    private readonly menuCache;
    constructor(database: DatabaseService, planFeatures: PlanFeaturesService, menuCache: MenuCacheService);
    listarSucursales(restauranteId: string): Promise<import("pg").QueryResultRow[]>;
    listarSucursalesStaff(restauranteId: string, usuarioRestauranteId: string): Promise<import("pg").QueryResultRow[]>;
    crearSucursal(restauranteId: string, usuarioRestauranteId: string, dto: CrearSucursalDto): Promise<{
        id: string;
        nombre: string;
        restaurante_id: string;
        ciudad_id: string;
    }>;
    actualizarSucursal(restauranteId: string, sucursalId: string, dto: ActualizarSucursalDto): Promise<{
        id: string;
        nombre: string;
        direccion: string | null;
        telefono: string | null;
        activa: boolean;
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
    obtenerMarca(restauranteId: string): Promise<{
        id: string;
        nombre: string;
        telefono: string | null;
        descripcion: string | null;
        logo_url: string | null;
        banner_url: string | null;
    }>;
    actualizarMarca(restauranteId: string, dto: {
        nombre?: string;
        telefono?: string | null;
        logo_url?: string | null;
        banner_url?: string | null;
        descripcion?: string | null;
    }): Promise<import("pg").QueryResultRow | {
        id: string;
        nombre: string;
        telefono: string | null;
        descripcion: string | null;
        logo_url: string | null;
        banner_url: string | null;
    }>;
    actualizarMargenesSucursal(restauranteId: string, sucursalId: string, dto: ActualizarMargenesSucursalDto): Promise<{
        margen_objetivo_default: number;
        umbral_alerta_margen: number;
    }>;
}
