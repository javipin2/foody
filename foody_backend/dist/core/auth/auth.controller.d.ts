import { AuthService } from './auth.service';
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
        usuario: {
            id: string;
            nombre: string;
            email: string;
            sucursal_id: string | null;
            restaurante_id: string | null;
        };
    }>;
    loginDomiciliario(dto: LoginDto): Promise<{
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        usuario: {
            id: string;
            nombre: string;
            email: string;
            ciudad_id: string | null;
        };
    }>;
    registroDomiciliario(dto: RegistroDomiciliarioDto): Promise<{
        id: string;
        mensaje: string;
        estado_cuenta: string;
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
        usuario: {
            id: string;
            nombre: string;
            email: string;
            sucursal_id: string | null;
            restaurante_id: string | null;
        };
    }>;
    loginGoogle(dto: LoginGoogleDto): Promise<{
        token: string;
        dashboard: string;
        rol: string;
        permisos: string[];
        plan: string;
        modulos: import("./plan-features.config").ModuloPlan[];
        usuario: {
            id: string;
            nombre: string;
            email: string;
            sucursal_id: string | null;
            restaurante_id: string | null;
        };
    } | {
        necesita_registro: boolean;
        email: string;
        nombre: any;
        proveedor_id: string;
    }>;
    perfil(usuario: JwtPayload): Promise<Record<string, unknown>>;
    registrarFcm(usuario: JwtPayload, body: {
        fcm_token: string;
        plataforma?: string;
    }): Promise<{
        registrado: boolean;
        tipo: string;
    }>;
    desactivarFcm(usuario: JwtPayload, body: {
        fcm_token?: string;
    }): Promise<{
        desactivado: boolean;
        tipo: string;
    }>;
}
