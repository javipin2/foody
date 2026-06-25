import { JwtService } from '@nestjs/jwt';
import { DatabaseService } from '../database/database.service';
import { JwtPayload } from './jwt-payload';
import { RegistroDomiciliarioDto } from './dto/registro-domiciliario.dto';
import { RegistroRestauranteDto } from './dto/registro-restaurante.dto';
import { PlanFeaturesService } from './plan-features.service';
import { OnboardingRestauranteService } from '../onboarding/onboarding-restaurante.service';
import { SupabaseAuthService } from './supabase-auth.service';
export declare class AuthService {
    private readonly database;
    private readonly jwtService;
    private readonly planFeatures;
    private readonly onboarding;
    private readonly supabaseAuth;
    constructor(database: DatabaseService, jwtService: JwtService, planFeatures: PlanFeaturesService, onboarding: OnboardingRestauranteService, supabaseAuth: SupabaseAuthService);
    login(email: string, contrasena: string): Promise<{
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
    loginGoogle(accessToken: string): Promise<{
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
    registrarRestaurante(dto: RegistroRestauranteDto): Promise<{
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
    private emitirSesionStaff;
    loginDomiciliarioIndependiente(email: string, contrasena: string): Promise<{
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
    registrarDomiciliarioIndependiente(dto: RegistroDomiciliarioDto): Promise<{
        id: string;
        mensaje: string;
        estado_cuenta: string;
    }>;
    perfil(jwt: JwtPayload): Promise<Record<string, unknown>>;
    resumenSuscripcion(restauranteId: string | null | undefined): Promise<{
        estado: string;
        plan: string;
        fecha_vencimiento: Date;
        dias_restantes: number;
        nivel_aviso: "ok" | "proximo" | "hoy" | "vencida" | "bloqueada";
        mostrar_banner: boolean;
    } | null>;
    permisosDelRol(rol: string): Promise<string[]>;
    private esRolCocina;
    private resolverDashboard;
    registrarFcm(usuario: JwtPayload, fcmToken: string, plataforma?: string): Promise<{
        registrado: boolean;
        tipo: string;
    }>;
    desactivarFcm(usuario: JwtPayload, fcmToken?: string): Promise<{
        desactivado: boolean;
        tipo: string;
    }>;
}
