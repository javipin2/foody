import { DatabaseService } from '../database/database.service';
import { ModuloPlan } from './plan-features.config';
export declare class PlanFeaturesService {
    private readonly database;
    constructor(database: DatabaseService);
    obtenerPlanRestaurante(restauranteId: string | null | undefined): Promise<string>;
    modulosDelPlan(plan: string | null | undefined): ModuloPlan[];
    incluyeModulo(plan: string | null | undefined, modulo: ModuloPlan): boolean;
    assertLimiteSucursales(restauranteId: string): Promise<void>;
    assertLimiteUsuariosStaff(restauranteId: string): Promise<void>;
    assertLimiteMesas(restauranteId: string, sucursalId: string): Promise<void>;
    assertLimiteProductos(restauranteId: string, sucursalId: string): Promise<void>;
    assertLimiteIngredientes(restauranteId: string, sucursalId: string): Promise<void>;
}
