export declare class CrearCiudadDto {
    nombre: string;
    slug?: string;
}
export declare class ActualizarCiudadDto {
    nombre?: string;
    activa?: boolean;
}
export declare class ActualizarRestauranteDto {
    activo?: boolean;
    motivo_bloqueo?: string;
}
export declare class ActualizarSuscripcionDto {
    estado?: string;
    plan?: string;
    fecha_vencimiento?: string;
}
export declare class ActualizarDomiciliarioEstadoDto {
    estado_cuenta: string;
    motivo?: string;
}
declare const ROLES_STAFF_SUPER: readonly ["admin", "gerente", "gerente_cadena", "cajero", "mesero", "domiciliario_planta", "cocina", "cocina_principal"];
export declare class CrearRestauranteDto {
    ciudad_id: string;
    nombre_restaurante: string;
    nombre_sucursal: string;
    direccion_sucursal?: string;
    admin_nombre: string;
    admin_email: string;
    admin_contrasena: string;
}
export declare class CrearUsuarioSuperDto {
    nombre: string;
    email: string;
    contrasena: string;
    rol: (typeof ROLES_STAFF_SUPER)[number];
    sucursal_id: string;
}
export declare class ActualizarUsuarioSuperDto {
    nombre?: string;
    email?: string;
    rol?: (typeof ROLES_STAFF_SUPER)[number];
}
export declare class CambiarContrasenaSuperDto {
    contrasena: string;
}
export declare class CambiarEstadoUsuarioSuperDto {
    activo: boolean;
}
export declare class ActualizarConfiguracionDto {
    valor: string;
}
export declare class AprobarDocumentoDto {
    documento_id: string;
}
export declare class RechazarDocumentoDto {
    documento_id: string;
    motivo: string;
}
export {};
