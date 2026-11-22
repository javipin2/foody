export declare const LIMITE_LISTADO_SIN_PAGINA = 200;
export declare class PaginacionQueryDto {
    page?: number;
    limit?: number;
}
export interface ResultadoPaginado<T> {
    items: T[];
    total: number;
    page: number;
    limit: number;
    totalPages: number;
}
export declare function resolverPaginacion(page?: number, limit?: number, limitPorDefecto?: number): {
    page: number;
    limit: number;
    offset: number;
};
export declare function envolverPaginado<T>(items: T[], total: number, page: number, limit: number): ResultadoPaginado<T>;
export declare function opcionesListado(query: PaginacionQueryDto, limitPorDefectoPagina?: number): {
    paginar: boolean;
    page?: number;
    limite: number;
};
