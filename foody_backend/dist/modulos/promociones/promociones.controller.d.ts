import { JwtPayload } from '../../core/auth/jwt-payload';
import { ActualizarPromocionDto, CrearPromocionDto, RegistrarVistaPromocionDto } from './dto/promocion.dto';
import { PromocionesService } from './promociones.service';
export declare class PromocionesController {
    private readonly promociones;
    constructor(promociones: PromocionesService);
    listarActivas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    storiesCiudad(slug: string): Promise<import("pg").QueryResultRow[]>;
    validarCodigo(sucursalId: string, codigo: string, subtotal: string): Promise<{
        promocion_id: string;
        monto: number;
        motivo: string;
    }>;
    registrarVista(id: string, dto: RegistrarVistaPromocionDto): Promise<{
        registrado: boolean;
    }>;
    listarAdmin(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearPromocionDto): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, dto: ActualizarPromocionDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
}
