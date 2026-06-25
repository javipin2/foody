import { GeografiaService } from './geografia.service';
export declare class GeografiaController {
    private readonly geografia;
    constructor(geografia: GeografiaService);
    buscar(consulta: string, lat?: string, lng?: string, limite?: string): Promise<{
        etiqueta: string;
        lat: number;
        lng: number;
    }[]>;
}
