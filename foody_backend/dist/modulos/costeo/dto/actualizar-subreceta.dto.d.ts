import { SubrecetaItemDto } from './crear-subreceta.dto';
export declare class ActualizarSubrecetaDto {
    sucursal_id: string;
    nombre: string;
    cantidad_resultado: number;
    unidad_resultado: string;
    margen_error?: number;
    items: SubrecetaItemDto[];
}
