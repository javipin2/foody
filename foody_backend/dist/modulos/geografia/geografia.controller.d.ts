import { BuscarGeografiaDto } from './dto/buscar-geografia.dto';
import { GeografiaService } from './geografia.service';
export declare class GeografiaController {
    private readonly geografia;
    constructor(geografia: GeografiaService);
    buscar(dto: BuscarGeografiaDto): Promise<{
        etiqueta: string;
        lat: number;
        lng: number;
    }[]>;
}
