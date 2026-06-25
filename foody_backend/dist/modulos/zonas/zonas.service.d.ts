import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { ActualizarZonaDto, CrearZonaDto } from './dto/zona.dto';
export declare class ZonasService {
    private readonly database;
    constructor(database: DatabaseService);
    listar(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    configuracionMapa(sucursalId: string): Promise<{
        sucursal: {
            id: string;
            nombre: string;
            direccion: string | null;
            lat: number | null;
            lng: number | null;
        };
        zonas: import("pg").QueryResultRow[];
    }>;
    actualizarUbicacionSucursal(sucursalId: string, lat: number, lng: number): Promise<{
        id: string;
        lat: number;
        lng: number;
    }>;
    crear(dto: CrearZonaDto): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, sucursalId: string, dto: ActualizarZonaDto): Promise<{
        id: string;
    }>;
    desactivar(id: string, sucursalId: string): Promise<{
        id: string;
        activa: boolean;
    }>;
    cotizarDomicilio(sucursalId: string, lat?: number, lng?: number): Promise<{
        costo: number;
        zona_id: string | null;
        zona_nombre: string | null;
        distancia_km: number | null;
        fuente: "zona" | "default";
    }>;
    calcularCostoDomicilio(client: PoolClient | null, sucursalId: string, lat?: number | null, lng?: number | null): Promise<{
        costo: number;
        zona_id: string | null;
        zona_nombre: string | null;
        distancia_km: number | null;
        fuente: 'zona' | 'default';
    }>;
    private distanciaKm;
    private toRad;
    private exigirZona;
    obtenerSucursalIdDeZona(zonaId: string): Promise<string>;
}
