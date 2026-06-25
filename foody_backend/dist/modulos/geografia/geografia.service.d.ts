type ResultadoBusqueda = {
    etiqueta: string;
    lat: number;
    lng: number;
};
export declare class GeografiaService {
    private readonly cache;
    private readonly maxCache;
    buscarDirecciones(consulta: string, opciones?: {
        lat?: number;
        lng?: number;
        limite?: number;
    }): Promise<ResultadoBusqueda[]>;
    private claveCache;
    private guardarCache;
}
export {};
