import { AuthService } from '../../core/auth/auth.service';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarUsuarioDto, CambiarEstadoUsuarioDto, CrearUsuarioDto } from './dto/crear-usuario.dto';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';
export declare class UsuariosService {
    private readonly database;
    private readonly planFeatures;
    private readonly authService;
    private readonly sucursalScope;
    constructor(database: DatabaseService, planFeatures: PlanFeaturesService, authService: AuthService, sucursalScope: SucursalScopeService);
    listarPorSucursal(sucursalId: string, query?: PaginacionQueryDto): Promise<import("pg").QueryResultRow[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow>>;
    listarMeserosActivos(sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    crear(dto: CrearUsuarioDto, actor: JwtPayload): Promise<{
        id: string;
        nombre: string;
        email: string;
        rol: "cocina" | "gerente_cadena" | "domiciliario_planta" | "cajero" | "mesero" | "gerente";
        cocina_id: string | null;
        activo: boolean;
        permisos: string[];
    }>;
    private resolverCocinaIdParaRol;
    cambiarEstado(usuarioId: string, sucursalId: string, dto: CambiarEstadoUsuarioDto): Promise<{
        id: string;
        activo: boolean;
    }>;
    catalogoRolesPermisos(): Promise<{
        roles: {
            rol: "cocina" | "gerente_cadena" | "domiciliario_planta" | "cajero" | "mesero" | "gerente";
            permisos: string[];
        }[];
        permisos_disponibles: string[];
    }>;
    permisosDeUsuario(usuarioId: string, sucursalId: string): Promise<{
        usuario_id: string;
        rol: string;
        personalizado: boolean;
        permisos: string[];
        plantilla_rol: string[];
    }>;
    actualizar(usuarioId: string, sucursalContexto: string, dto: ActualizarUsuarioDto, actor: JwtPayload): Promise<{
        permisos: string[];
        id: string;
        nombre: string;
        email: string;
        rol: string;
        activo: boolean;
        sucursal_id: string;
        cocina_id: string | null;
    }>;
}
