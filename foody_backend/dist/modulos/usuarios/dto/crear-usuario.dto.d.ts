declare const ROLES_STAFF: readonly ["gerente", "cajero", "mesero", "domiciliario_planta"];
export declare class CrearUsuarioDto {
    nombre: string;
    email: string;
    contrasena: string;
    rol: (typeof ROLES_STAFF)[number];
    sucursal_id: string;
}
export declare class CambiarEstadoUsuarioDto {
    activo: boolean;
}
export {};
