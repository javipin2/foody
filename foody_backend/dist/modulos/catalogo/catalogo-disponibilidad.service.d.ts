import { PoolClient } from 'pg';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { CosteoService } from '../costeo/costeo.service';
export type CambioDisponibilidadProducto = {
    producto_id: string;
    disponible: boolean;
};
export declare class CatalogoDisponibilidadService {
    private readonly database;
    private readonly costeo;
    private readonly realtime;
    private readonly menuCache;
    constructor(database: DatabaseService, costeo: CosteoService, realtime: RealtimeBroadcastService, menuCache: MenuCacheService);
    sincronizarPorIngrediente(sucursalId: string, ingredienteId: string): Promise<CambioDisponibilidadProducto[]>;
    sincronizarPorIngredienteEnTransaccion(client: PoolClient, sucursalId: string, ingredienteId: string): Promise<CambioDisponibilidadProducto[]>;
    emitirCambios(sucursalId: string, cambios: CambioDisponibilidadProducto[]): void;
    private evaluarDisponibilidadProducto;
}
