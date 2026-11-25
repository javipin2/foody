import { AuthService } from './auth.service';
import { DesactivarFcmDto, RegistrarFcmDto } from './dto/fcm.dto';
import { LoginDto } from './dto/login.dto';
import { LoginGoogleDto } from './dto/login-google.dto';
import { RegistroDomiciliarioDto } from './dto/registro-domiciliario.dto';
import { RegistroRestauranteDto } from './dto/registro-restaurante.dto';
import { JwtPayload } from './jwt-payload';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    login(dto: LoginDto): Promise<{
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        plan: string;
        modulos: import("./plan-features.config").ModuloPlan[];
        realtime_canales: Record<string, string>;
        usuario: {
            id: string;
            nombre: string;
            email: string;
            sucursal_id: string | null;
            restaurante_id: string | null;
            cocina_id: string | null;
        };
    }>;
    loginDomiciliario(dto: LoginDto): Promise<{
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        estado_cuenta: string;
        realtime_canales: {
            domiciliario_indep: string;
        };
        usuario: {
            id: string;
            nombre: string;
            email: string;
            ciudad_id: string | null;
        };
    }>;
    registroDomiciliario(dto: RegistroDomiciliarioDto): Promise<{
        id: string;
        token: string;
        mensaje: string;
        estado_cuenta: string;
        realtime_canales: {
            domiciliario_indep: string;
        };
        usuario: {
            id: string;
            nombre: string;
            email: string;
            ciudad_id: string | null;
        };
    }>;
    registroRestaurante(dto: RegistroRestauranteDto): Promise<{
        onboarding: import("../onboarding/onboarding-restaurante.service").OnboardingRestauranteResult;
        mensaje: string;
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        plan: string;
        modulos: import("./plan-features.config").ModuloPlan[];
        realtime_canales: Record<string, string>;
        usuario: {
            id: string;
            nombre: string;
            email: string;
            sucursal_id: string | null;
            restaurante_id: string | null;
            cocina_id: string | null;
        };
    }>;
    registroEstado(): Promise<{
        abierto: boolean;
        registro_habilitado: boolean;
        cupo_diario: number;
        usados_hoy: number;
        max_por_minuto: number;
        usados_minuto: number;
        mensaje: string;
    }>;
    loginGoogle(dto: LoginGoogleDto): Promise<{
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        plan: string;
        modulos: import("./plan-features.config").ModuloPlan[];
        realtime_canales: Record<string, string>;
        usuario: {
            id: string;
            nombre: string;
            email: string;
            sucursal_id: string | null;
            restaurante_id: string | null;
            cocina_id: string | null;
        };
    } | {
        necesita_registro: boolean;
        email: string;
        nombre: any;
        proveedor_id: string;
    }>;
    refresh(usuario: JwtPayload): Promise<{
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        plan: string;
        modulos: import("./plan-features.config").ModuloPlan[];
        realtime_canales: Record<string, string>;
        usuario: {
            id: string;
            nombre: string;
            email: string;
            sucursal_id: string | null;
            restaurante_id: string | null;
            cocina_id: string | null;
        };
    } | {
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        estado_cuenta: string;
        realtime_canales: {
            domiciliario_indep: string;
        };
        usuario: {
            id: string;
            nombre: string;
            email: string;
            ciudad_id: string | null;
        };
    }>;
    logout(usuario: JwtPayload): Promise<{
        cerrado: boolean;
    }>;
    perfil(usuario: JwtPayload): Promise<Record<string, unknown>>;
    realtimeCanales(usuario: JwtPayload, sucursalId?: string, cocinaId?: string): Promise<{
        realtime_canales: Record<string, string>;
    }>;
    registrarFcm(usuario: JwtPayload, dto: RegistrarFcmDto): Promise<{
        registrado: boolean;
        tipo: string;
    }>;
    desactivarFcm(usuario: JwtPayload, dto: DesactivarFcmDto): Promise<{
        desactivado: boolean;
        tipo: string;
    }>;
}
