import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarPromocionDto, CrearPromocionDto, RegistrarVistaPromocionDto, ValidarCodigoPromocionDto } from './dto/promocion.dto';
import { PromocionesService } from './promociones.service';
export declare class PromocionesController {
    private readonly promociones;
    private readonly sucursalScope;
    constructor(promociones: PromocionesService, sucursalScope: SucursalScopeService);
    listarActivas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    storiesCiudad(slug: string): Promise<import("pg").QueryResultRow[]>;
    validarCodigo(dto: ValidarCodigoPromocionDto): Promise<{
        promocion_id: string;
        monto: number;
        motivo: string;
    }>;
    registrarVista(id: string, dto: RegistrarVistaPromocionDto): Promise<{
        registrado: boolean;
    }>;
    crear(usuario: JwtPayload, dto: CrearPromocionDto): Promise<import("pg").QueryResultRow | null>;
    limpiarExpiradas(): Promise<{
        filas: number;
        objetos_storage: number;
    }>;
    listarAdmin(usuario: JwtPayload, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    actualizar(id: string, dto: ActualizarPromocionDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    eliminar(id: string, usuario: JwtPayload): Promise<{
        eliminado: boolean;
    }>;
}
