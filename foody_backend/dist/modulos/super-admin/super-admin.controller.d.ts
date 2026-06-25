import { JwtPayload } from '../../core/auth/jwt-payload';
import { ActualizarCiudadDto, ActualizarConfiguracionDto, ActualizarDomiciliarioEstadoDto, ActualizarRestauranteDto, ActualizarSuscripcionDto, ActualizarUsuarioSuperDto, AprobarDocumentoDto, CambiarContrasenaSuperDto, CambiarEstadoUsuarioSuperDto, CrearCiudadDto, CrearRestauranteDto, CrearUsuarioSuperDto, RechazarDocumentoDto } from './dto/super-admin.dto';
import { SuperAdminService } from './super-admin.service';
export declare class SuperAdminController {
    private readonly superAdminService;
    constructor(superAdminService: SuperAdminService);
    resumen(): Promise<{
        ciudades_activas: number;
        restaurantes_activos: number;
        sucursales_activas: number;
        domiciliarios_activos: number;
        suscripciones: import("pg").QueryResultRow[];
    }>;
    estadisticas(): Promise<{
        pedidos_hoy: number;
        ingresos_foody_hoy: number;
        ciudades_activas: number;
        restaurantes_activos: number;
        sucursales_activas: number;
        domiciliarios_activos: number;
        suscripciones: import("pg").QueryResultRow[];
    }>;
    ciudades(): Promise<import("pg").QueryResultRow[]>;
    crearCiudad(dto: CrearCiudadDto): Promise<import("pg").QueryResultRow | null>;
    actualizarCiudad(id: string, dto: ActualizarCiudadDto): Promise<import("pg").QueryResultRow | null>;
    restaurantes(): Promise<import("pg").QueryResultRow[]>;
    crearRestaurante(dto: CrearRestauranteDto): Promise<import("../../core/onboarding/onboarding-restaurante.service").OnboardingRestauranteResult>;
    actualizarRestaurante(id: string, dto: ActualizarRestauranteDto): Promise<import("pg").QueryResultRow | null>;
    sucursalesRestaurante(restauranteId: string): Promise<import("pg").QueryResultRow[]>;
    suscripciones(): Promise<import("pg").QueryResultRow[]>;
    actualizarSuscripcion(id: string, dto: ActualizarSuscripcionDto): Promise<import("pg").QueryResultRow | null>;
    usuarios(): Promise<import("pg").QueryResultRow[]>;
    crearUsuario(dto: CrearUsuarioSuperDto): Promise<{
        id: string;
        nombre: string;
        email: string;
        rol: "domiciliario_planta" | "cajero" | "mesero" | "admin" | "gerente" | "cocina_principal";
        sucursal_id: string;
        restaurante_id: string;
    }>;
    actualizarUsuario(id: string, dto: ActualizarUsuarioSuperDto): Promise<import("pg").QueryResultRow | null>;
    cambiarContrasena(id: string, dto: CambiarContrasenaSuperDto): Promise<{
        id: string;
        actualizado: boolean;
    }>;
    usuarioEstado(id: string, dto: CambiarEstadoUsuarioSuperDto): Promise<{
        id: string;
        activo: boolean;
    }>;
    domiciliarios(): Promise<import("pg").QueryResultRow[]>;
    domiciliarioEstado(id: string, dto: ActualizarDomiciliarioEstadoDto): Promise<import("pg").QueryResultRow | null>;
    documentosPendientes(): Promise<import("pg").QueryResultRow[]>;
    aprobarDocumento(id: string, dto: AprobarDocumentoDto, usuario: JwtPayload): Promise<{
        documento_id: string;
        estado: "rechazado" | "aprobado";
    }>;
    rechazarDocumento(id: string, dto: RechazarDocumentoDto, usuario: JwtPayload): Promise<{
        documento_id: string;
        estado: "rechazado" | "aprobado";
    }>;
    configuracion(): Promise<import("pg").QueryResultRow[]>;
    actualizarConfiguracion(clave: string, dto: ActualizarConfiguracionDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
}
