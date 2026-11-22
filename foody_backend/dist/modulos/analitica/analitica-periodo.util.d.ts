import { PresetAnalitica } from './dto/filtro-analitica.dto';
export type PeriodoResuelto = {
    preset: string;
    desde: string;
    hasta: string;
    label: string;
};
export type PeriodoConComparativa = {
    periodo: PeriodoResuelto;
    anterior?: {
        desde: string;
        hasta: string;
    };
};
export declare function hoyBogota(): string;
export declare function diasEntre(desde: string, hasta: string): number;
export declare function resolverPeriodoAnalitica(preset?: PresetAnalitica, desde?: string, hasta?: string, comparar?: string, compararDesde?: string, compararHasta?: string): PeriodoConComparativa;
