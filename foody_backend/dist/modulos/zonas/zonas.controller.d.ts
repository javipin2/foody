import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarZonaDto, CotizarDomicilioDto, CrearZonaDto, UbicacionSucursalDto } from './dto/zona.dto';
import { ZonasService } from './zonas.service';
export declare class ZonasController {
    private readonly zonas;
    private readonly sucursalScope;
    constructor(zonas: ZonasService, sucursalScope: SucursalScopeService);
    cotizar(dto: CotizarDomicilioDto): Promise<{
        costo: number;
        zona_id: string | null;
        zona_nombre: string | null;
        distancia_km: number | null;
        fuente: "zona" | "default";
    }>;
    configuracionMapa(sucursalId: string, usuario: JwtPayload): Promise<{
        sucursal: {
            id: string;
            nombre: string;
            direccion: string | null;
            lat: number | null;
            lng: number | null;
        };
        zonas: import("pg").QueryResultRow[];
    }>;
    ubicacionSucursal(sucursalId: string, dto: UbicacionSucursalDto, usuario: JwtPayload): Promise<{
        id: string;
        lat: number;
        lng: number;
    }>;
    listar(sucursalId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearZonaDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, dto: ActualizarZonaDto, usuario: JwtPayload, sucursalIdQuery?: string): Promise<{
        id: string;
    }>;
    desactivar(id: string, usuario: JwtPayload, sucursalIdQuery?: string): Promise<{
        id: string;
        activa: boolean;
    }>;
}
