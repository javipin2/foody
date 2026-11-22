declare const PRESETS: readonly ["hoy", "ayer", "semana", "mes", "mes_anterior", "7d", "30d", "rango"];
export declare class FiltroPopularidadQueryDto {
    preset?: (typeof PRESETS)[number];
    desde?: string;
    hasta?: string;
}
export {};
