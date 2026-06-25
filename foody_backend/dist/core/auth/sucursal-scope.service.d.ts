import { DatabaseService } from '../database/database.service';
import { JwtPayload } from './jwt-payload';
export declare const PERMISO_OPERAR_MULTI_SUCURSAL = "gestionar_sucursales";
export declare const PERMISO_VER_INVENTARIO_HERMANAS = "ver_inventario_otras_sucursales";
export declare class SucursalScopeService {
    private readonly database;
    constructor(database: DatabaseService);
    esCorporativo(usuario: JwtPayload): boolean;
    puedeVerInventarioHermanas(usuario: JwtPayload): boolean;
    resolverSucursalId(usuario: JwtPayload, solicitada?: string | null): string;
    assertPerteneceRestaurante(sucursalId: string, restauranteId: string): Promise<void>;
    validarLecturaOperativa(usuario: JwtPayload, sucursalId: string): Promise<void>;
    validarLecturaInventario(usuario: JwtPayload, sucursalId: string): Promise<void>;
    validarEscritura(usuario: JwtPayload, sucursalId: string): Promise<void>;
    resolverLecturaOperativa(usuario: JwtPayload, solicitada?: string | null): Promise<string>;
    resolverLecturaInventario(usuario: JwtPayload, solicitada?: string | null): Promise<string>;
    resolverEscritura(usuario: JwtPayload, solicitada?: string | null): Promise<string>;
}
