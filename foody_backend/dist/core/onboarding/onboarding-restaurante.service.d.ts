import { DatabaseService } from '../database/database.service';
export type OrigenRestaurante = 'manual' | 'self_service';
export type PlanOnboarding = 'gratis' | 'basico' | 'pro' | 'enterprise';
export type EstadoSuscripcionOnboarding = 'activa' | 'prueba';
export type ProveedorAuth = 'correo' | 'google';
export interface OnboardingRestauranteInput {
    ciudad_id: string;
    nombre_restaurante: string;
    nombre_sucursal: string;
    direccion_sucursal?: string | null;
    admin_nombre: string;
    admin_email: string;
    hash_contrasena?: string | null;
    proveedor_auth?: ProveedorAuth;
    proveedor_id?: string | null;
    email_verificado?: boolean;
    origen?: OrigenRestaurante;
    plan?: PlanOnboarding;
    estado_suscripcion?: EstadoSuscripcionOnboarding;
    dias_prueba?: number;
}
export interface OnboardingRestauranteResult {
    restaurante_id: string;
    sucursal_id: string;
    admin_id: string;
    admin_email: string;
    suscripcion: {
        estado: string;
        plan: string;
        dias_prueba?: number;
    };
}
export declare class OnboardingRestauranteService {
    private readonly database;
    constructor(database: DatabaseService);
    crear(dto: OnboardingRestauranteInput): Promise<OnboardingRestauranteResult>;
    private completarPostCommit;
    private centroCiudadPorSlug;
}
