import { DatabaseService } from '../../core/database/database.service';
import { ConfiguracionGlobalService } from '../../core/config/configuracion-global.module';
import { OnboardingRestauranteService } from '../../core/onboarding/onboarding-restaurante.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { AlmacenamientoService } from '../almacenamiento/almacenamiento.service';
import { ActualizarCiudadDto, ActualizarConfiguracionDto, ActualizarDomiciliarioEstadoDto, ActualizarRestauranteDto, ActualizarSuscripcionDto, ActualizarUsuarioSuperDto, AprobarDocumentoDto, CambiarContrasenaSuperDto, CambiarEstadoUsuarioSuperDto, CrearCiudadDto, CrearRestauranteDto, CrearUsuarioSuperDto, RechazarDocumentoDto } from './dto/super-admin.dto';
export declare class SuperAdminService {
    private readonly database;
    private readonly onboarding;
    private readonly notificaciones;
    private readonly configGlobal;
    private readonly almacenamiento;
    private readonly logger;
    constructor(database: DatabaseService, onboarding: OnboardingRestauranteService, notificaciones: NotificacionesService, configGlobal: ConfiguracionGlobalService, almacenamiento: AlmacenamientoService);
    resumenGlobal(): Promise<{
        ciudades_activas: number;
        restaurantes_activos: number;
        sucursales_activas: number;
        domiciliarios_activos: number;
        suscripciones: import("pg").QueryResultRow[];
    }>;
    crearCiudad(dto: CrearCiudadDto): Promise<import("pg").QueryResultRow | null>;
    actualizarCiudad(id: string, dto: ActualizarCiudadDto): Promise<import("pg").QueryResultRow | null>;
    actualizarRestaurante(id: string, dto: ActualizarRestauranteDto): Promise<import("pg").QueryResultRow | null>;
    listarCiudades(): Promise<import("pg").QueryResultRow[]>;
    listarRestaurantes(): Promise<import("pg").QueryResultRow[]>;
    listarSucursalesRestaurante(restauranteId: string): Promise<import("pg").QueryResultRow[]>;
    listarSuscripciones(): Promise<import("pg").QueryResultRow[]>;
    actualizarSuscripcion(id: string, dto: ActualizarSuscripcionDto): Promise<import("pg").QueryResultRow | null>;
    listarDomiciliarios(): Promise<import("pg").QueryResultRow[]>;
    actualizarEstadoDomiciliario(id: string, dto: ActualizarDomiciliarioEstadoDto): Promise<import("pg").QueryResultRow | null>;
    listarConfiguracion(): Promise<import("pg").QueryResultRow[]>;
    metricasSelfService(): Promise<{
        registros_self_service: number;
        pagos_aprobados_30d: number;
        ingresos_cop_30d: number;
        pagos_pendientes: number;
        tasa_conversion_pagos_pct: number;
        suscripciones_por_plan: {
            plan: string;
            total: number;
        }[];
    }>;
    estadisticas(): Promise<{
        pedidos_hoy: number;
        ingresos_foody_hoy: number;
        self_service: {
            registros_self_service: number;
            pagos_aprobados_30d: number;
            ingresos_cop_30d: number;
            pagos_pendientes: number;
            tasa_conversion_pagos_pct: number;
            suscripciones_por_plan: {
                plan: string;
                total: number;
            }[];
        };
        ciudades_activas: number;
        restaurantes_activos: number;
        sucursales_activas: number;
        domiciliarios_activos: number;
        suscripciones: import("pg").QueryResultRow[];
    }>;
    actualizarConfiguracion(clave: string, dto: ActualizarConfiguracionDto, usuarioId: string): Promise<import("pg").QueryResultRow | null>;
    crearRestaurante(dto: CrearRestauranteDto): Promise<import("../../core/onboarding/onboarding-restaurante.service").OnboardingRestauranteResult>;
    listarUsuarios(): Promise<import("pg").QueryResultRow[]>;
    crearUsuario(dto: CrearUsuarioSuperDto): Promise<{
        id: string;
        nombre: string;
        email: string;
        rol: "cocina" | "gerente_cadena" | "admin" | "domiciliario_planta" | "cajero" | "mesero" | "gerente" | "cocina_principal";
        sucursal_id: string;
        restaurante_id: string;
    }>;
    actualizarUsuario(id: string, dto: ActualizarUsuarioSuperDto): Promise<import("pg").QueryResultRow | null>;
    cambiarContrasenaUsuario(id: string, dto: CambiarContrasenaSuperDto): Promise<{
        id: string;
        actualizado: boolean;
    }>;
    cambiarEstadoUsuario(id: string, dto: CambiarEstadoUsuarioSuperDto): Promise<{
        id: string;
        activo: boolean;
    }>;
    listarDocumentosPendientes(): Promise<{
        url: string;
    }[]>;
    listarDocumentosDomiciliario(domiciliarioId: string): Promise<{
        url: string;
    }[]>;
    aprobarDocumento(domiciliarioId: string, dto: AprobarDocumentoDto, revisorId: string): Promise<{
        documento_id: string;
        estado: "rechazado" | "aprobado";
    }>;
    rechazarDocumento(domiciliarioId: string, dto: RechazarDocumentoDto, revisorId: string): Promise<{
        documento_id: string;
        estado: "rechazado" | "aprobado";
    }>;
    private revisarDocumento;
    private notificarDomiciliario;
}
