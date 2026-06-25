import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { ActualizarPromocionDto, CrearPromocionDto } from './dto/promocion.dto';
export declare class PromocionesService {
    private readonly database;
    constructor(database: DatabaseService);
    listarActivas(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    listarStoriesPorCiudad(slug: string): Promise<import("pg").QueryResultRow[]>;
    listarAdmin(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearPromocionDto): Promise<import("pg").QueryResultRow | null>;
    actualizar(id: string, sucursalId: string, dto: ActualizarPromocionDto): Promise<import("pg").QueryResultRow | null>;
    previewCodigo(sucursalId: string, codigo: string, subtotal: number): Promise<{
        promocion_id: string;
        monto: number;
        motivo: string;
    }>;
    resolverDescuentoPorCodigo(client: PoolClient, sucursalId: string, codigo: string, subtotal: number): Promise<{
        promocion_id: string;
        monto: number;
        motivo: string;
    }>;
    resolverMejorAutomatica(client: PoolClient, sucursalId: string, subtotal: number): Promise<{
        promocion_id: string;
        monto: number;
        motivo: string;
    } | null>;
    private validarDescuentoDto;
    registrarVista(promocionId: string, deviceId: string): Promise<{
        registrado: boolean;
    }>;
    private exigirPromocion;
}
