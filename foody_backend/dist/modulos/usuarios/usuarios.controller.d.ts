import { JwtPayload } from '../../core/auth/jwt-payload';
import { CambiarEstadoUsuarioDto, CrearUsuarioDto } from './dto/crear-usuario.dto';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { UsuariosService } from './usuarios.service';
export declare class UsuariosController {
    private readonly usuariosService;
    private readonly sucursalScope;
    constructor(usuariosService: UsuariosService, sucursalScope: SucursalScopeService);
    listar(usuario: JwtPayload, sucursalId?: string): Promise<import("pg").QueryResultRow[]>;
    crear(usuario: JwtPayload, dto: CrearUsuarioDto): Promise<{
        id: string;
        nombre: string;
        email: string;
        rol: "domiciliario_planta" | "cajero" | "mesero" | "gerente";
        activo: boolean;
    }>;
    cambiarEstado(usuarioId: string, usuario: JwtPayload, dto: CambiarEstadoUsuarioDto, sucursalId?: string): Promise<{
        id: string;
        activo: boolean;
    }>;
}
