import { JwtService } from '@nestjs/jwt';
import { DatabaseService } from '../database/database.service';
import { JwtPayload } from './jwt-payload';
import { RegistroDomiciliarioDto } from './dto/registro-domiciliario.dto';
import { RegistroRestauranteDto } from './dto/registro-restaurante.dto';
import { PlanFeaturesService } from './plan-features.service';
import { OnboardingRestauranteService } from '../onboarding/onboarding-restaurante.service';
import { SupabaseAuthService } from './supabase-auth.service';
import { RealtimeBroadcastService } from '../realtime/realtime-broadcast.service';
export declare class AuthService {
    private readonly database;
    private readonly jwtService;
    private readonly planFeatures;
    private readonly onboarding;
    private readonly supabaseAuth;
    private readonly realtime;
    constructor(database: DatabaseService, jwtService: JwtService, planFeatures: PlanFeaturesService, onboarding: OnboardingRestauranteService, supabaseAuth: SupabaseAuthService, realtime: RealtimeBroadcastService);
    canalesRealtimeParaUsuario(usuario: {
        id: string;
        rol: string;
        sucursal_id: string | null;
        restaurante_id: string | null;
        cocina_id?: string | null;
    }, sucursalOverride?: string | null): Record<string, string>;
    login(email: string, contrasena: string): Promise<{
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
    loginGoogle(accessToken: string): Promise<{
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
    estadoRegistroRestaurante(): Promise<{
        abierto: boolean;
        registro_habilitado: boolean;
        cupo_diario: number;
        usados_hoy: number;
        max_por_minuto: number;
        usados_minuto: number;
        mensaje: string;
    }>;
    private contarSelfServiceHoy;
    private contarSelfServiceUltimoMinuto;
    private exigirCupoRegistroSelfService;
    registrarRestaurante(dto: RegistroRestauranteDto): Promise<{
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
    private emitirSesionStaff;
    loginDomiciliarioIndependiente(email: string, contrasena: string): Promise<{
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
    private tokenDomiciliarioIndependiente;
    registrarDomiciliarioIndependiente(dto: RegistroDomiciliarioDto): Promise<{
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
    perfil(jwt: JwtPayload): Promise<Record<string, unknown>>;
    refresh(jwt: JwtPayload): Promise<{
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
    logout(jwt: JwtPayload): Promise<{
        cerrado: boolean;
    }>;
    realtimeCanales(jwt: JwtPayload, sucursalIdQuery?: string): Promise<{
        realtime_canales: Record<string, string>;
    }>;
    resumenSuscripcion(restauranteId: string | null | undefined): Promise<{
        estado: string;
        plan: string;
        fecha_vencimiento: Date;
        dias_restantes: number;
        nivel_aviso: "ok" | "proximo" | "hoy" | "vencida" | "bloqueada";
        mostrar_banner: boolean;
    } | null>;
    permisosDelRol(rol: string): Promise<string[]>;
    permisosEfectivos(usuarioId: string, rol: string): Promise<string[]>;
    tienePermisosPersonalizados(usuarioId: string): Promise<boolean>;
    catalogoPermisosDisponibles(): Promise<string[]>;
    reemplazarPermisosUsuario(usuarioId: string, rol: string, permisos: string[], client?: import('pg').PoolClient): Promise<string[]>;
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
