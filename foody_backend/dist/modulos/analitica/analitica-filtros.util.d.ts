import { FiltroAnaliticaDto } from './dto/filtro-analitica.dto';
export declare const ANALITICA_CLIENTE_FRECUENTE_MIN = 3;
export type FiltrosAnalitica = {
    meseraIds?: string[];
    cocinaIds?: string[];
    productoIds?: string[];
    categoriaIds?: string[];
    estados?: string[];
    sinEstadosOperativos?: boolean;
    itemEstadosCocina?: string[];
    horaDesde?: number;
    horaHasta?: number;
    soloPendientePago?: boolean;
    soloFacturados?: boolean;
    metodosPago?: string[];
    cajeroIds?: string[];
    cajaIds?: string[];
    clienteTelefono?: string;
    deviceId?: string;
    clienteSegmento?: 'frecuente' | 'nuevo';
    domiciliarioIds?: string[];
};
export declare function parseFiltrosDesdeDto(dto: FiltroAnaliticaDto): FiltrosAnalitica;
export declare function filtrosActivos(f: FiltrosAnalitica): boolean;
export declare function filtrosSumanPorLinea(f: FiltrosAnalitica): boolean;
export declare class SqlParams {
    readonly list: unknown[];
    add(value: unknown): string;
}
export type ClausulasOpts = {
    alias?: string;
    excluirCanceladosPorDefecto?: boolean;
    frecuenteMin?: number;
};
export declare function clausulasPedidos(params: SqlParams, filtros: FiltrosAnalitica, opts?: ClausulasOpts): string;
export declare function clausulasItemsYaJoineados(params: SqlParams, filtros: FiltrosAnalitica): string;
