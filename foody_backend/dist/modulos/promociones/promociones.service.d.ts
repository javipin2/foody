import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlmacenamientoService } from '../almacenamiento/almacenamiento.service';
import { ActualizarPromocionDto, CrearPromocionDto } from './dto/promocion.dto';
export declare class PromocionesService {
    private readonly database;
    private readonly almacenamiento;
    private readonly logger;
    constructor(database: DatabaseService, almacenamiento: AlmacenamientoService);
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
    eliminar(id: string, sucursalId: string): Promise<{
        eliminado: boolean;
    }>;
    limpiarExpiradas(diasGracia?: number): Promise<{
        filas: number;
        objetos_storage: number;
    }>;
    private exigirProductoDeSucursal;
}
