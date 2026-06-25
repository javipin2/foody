export declare class RegistroRestauranteDto {
    ciudad_id: string;
    nombre_restaurante: string;
    nombre_sucursal?: string;
    direccion_sucursal?: string;
    admin_nombre: string;
    admin_email: string;
    contrasena?: string;
    proveedor_auth?: 'correo' | 'google';
    supabase_access_token?: string;
}
