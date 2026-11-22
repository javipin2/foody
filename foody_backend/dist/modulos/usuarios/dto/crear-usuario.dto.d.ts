declare const ROLES_STAFF: readonly ["gerente", "gerente_cadena", "cajero", "mesero", "domiciliario_planta", "cocina"];
export type RolStaff = (typeof ROLES_STAFF)[number];
export declare const ROLES_STAFF_ASIGNABLES: readonly ["gerente", "gerente_cadena", "cajero", "mesero", "domiciliario_planta", "cocina"];
export declare class CrearUsuarioDto {
    nombre: string;
    email: string;
    contrasena: string;
    rol: (typeof ROLES_STAFF)[number];
    sucursal_id: string;
    cocina_id?: string;
    permisos?: string[];
}
export declare class CambiarEstadoUsuarioDto {
    activo: boolean;
}
export declare class ActualizarUsuarioDto {
    nombre?: string;
    rol?: RolStaff;
    sucursal_id?: string;
    cocina_id?: string | null;
    permisos?: string[];
}
export {};
