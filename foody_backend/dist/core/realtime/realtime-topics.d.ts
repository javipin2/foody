export type TipoCanalStaff = 'sucursal' | 'cocina' | 'restaurante' | 'domiciliario' | 'domiciliario_indep';
export declare function pepperRealtime(env: {
    get: (clave: string) => string | undefined;
}): string;
export declare function firmaCanal(pepper: string, tipo: TipoCanalStaff, id: string): string;
export declare function topicStaff(pepper: string, tipo: TipoCanalStaff, id: string): string;
export declare function topicCatalogoPublico(sucursalId: string): string;
export declare function esTopicPublico(nombre: string): boolean;
