import { JwtPayload } from '../../core/auth/jwt-payload';
import { ActualizarHorarioDto } from './dto/actualizar-horario.dto';
import { ActualizarMarcaRestauranteDto } from './dto/actualizar-marca-restaurante.dto';
import { ActualizarMargenesSucursalDto } from './dto/actualizar-margenes-sucursal.dto';
import { ActualizarSucursalDto } from './dto/actualizar-sucursal.dto';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';
import { RestaurantesService } from './restaurantes.service';
export declare class SucursalesStaffController {
    private readonly restaurantes;
    constructor(restaurantes: RestaurantesService);
    listarMiRestaurante(usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    obtenerMarca(usuario: JwtPayload): Promise<{
        id: string;
        nombre: string;
        telefono: string | null;
        descripcion: string | null;
        logo_url: string | null;
        banner_url: string | null;
    }>;
    actualizarMarca(usuario: JwtPayload, dto: ActualizarMarcaRestauranteDto): Promise<import("pg").QueryResultRow | {
        id: string;
        nombre: string;
        telefono: string | null;
        descripcion: string | null;
        logo_url: string | null;
        banner_url: string | null;
    }>;
    crear(usuario: JwtPayload, dto: CrearSucursalDto): Promise<{
        id: string;
        nombre: string;
        restaurante_id: string;
        ciudad_id: string;
    }>;
    actualizarMargenesSucursal(usuario: JwtPayload, sucursalId: string, dto: ActualizarMargenesSucursalDto): Promise<{
        margen_objetivo_default: number;
        umbral_alerta_margen: number;
    }>;
    actualizarSucursal(usuario: JwtPayload, sucursalId: string, dto: ActualizarSucursalDto): Promise<{
        id: string;
        nombre: string;
        direccion: string | null;
        telefono: string | null;
        activa: boolean;
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
