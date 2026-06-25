import { DatabaseService } from '../../core/database/database.service';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { CambiarEstadoUsuarioDto } from './dto/crear-usuario.dto';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';
export declare class UsuariosService {
    private readonly database;
    private readonly planFeatures;
    constructor(database: DatabaseService, planFeatures: PlanFeaturesService);
    listarPorSucursal(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearUsuarioDto): Promise<{
        id: string;
        nombre: string;
        email: string;
        rol: "domiciliario_planta" | "cajero" | "mesero" | "gerente";
        activo: boolean;
    }>;
    cambiarEstado(usuarioId: string, sucursalId: string, dto: CambiarEstadoUsuarioDto): Promise<{
        id: string;
        activo: boolean;
    }>;
}
