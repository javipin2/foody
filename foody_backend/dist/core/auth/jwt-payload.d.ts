export declare class JwtPayload {
    sub: string;
    email: string;
    rol: string;
    sucursal_id: string | null;
    restaurante_id: string | null;
    permisos: string[];
    ciudad_id?: string | null;
    cocina_id?: string | null;
    plan?: string;
    tv?: number;
}
