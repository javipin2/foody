import { JwtPayload } from '../../core/auth/jwt-payload';
import { CambiarEstadoUsuarioDto, CrearUsuarioDto, ActualizarUsuarioDto } from './dto/crear-usuario.dto';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { UsuariosService } from './usuarios.service';
import { ListarUsuariosQueryDto } from './dto/listar-usuarios-query.dto';
export declare class UsuariosController {
    private readonly usuariosService;
    private readonly sucursalScope;
    constructor(usuariosService: UsuariosService, sucursalScope: SucursalScopeService);
    listar(usuario: JwtPayload, query: ListarUsuariosQueryDto): Promise<import("pg").QueryResultRow[] | import("../../compartido/dto/paginacion.dto").ResultadoPaginado<import("pg").QueryResultRow>>;
    meserosActivos(usuario: JwtPayload, sucursalId?: string): Promise<import("pg").QueryResultRow[]>;
    catalogoRoles(): Promise<{
        roles: {
            rol: "cocina" | "gerente_cadena" | "domiciliario_planta" | "cajero" | "mesero" | "gerente";
            permisos: string[];
        }[];
        permisos_disponibles: string[];
    }>;
    permisosUsuario(usuarioId: string, usuario: JwtPayload, sucursalId?: string): Promise<{
        usuario_id: string;
        rol: string;
        personalizado: boolean;
        permisos: string[];
        plantilla_rol: string[];
    }>;
    crear(usuario: JwtPayload, dto: CrearUsuarioDto): Promise<{
        id: string;
        nombre: string;
        email: string;
        rol: "cocina" | "gerente_cadena" | "domiciliario_planta" | "cajero" | "mesero" | "gerente";
        cocina_id: string | null;
        activo: boolean;
        permisos: string[];
    }>;
    cambiarEstado(usuarioId: string, usuario: JwtPayload, dto: CambiarEstadoUsuarioDto, sucursalId?: string): Promise<{
        id: string;
        activo: boolean;
    }>;
    actualizar(usuarioId: string, usuario: JwtPayload, dto: ActualizarUsuarioDto, sucursalId?: string): Promise<{
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
