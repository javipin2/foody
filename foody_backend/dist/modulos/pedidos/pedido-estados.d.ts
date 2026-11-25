export declare const TRANSICIONES_PEDIDO: Readonly<Record<string, readonly string[]>>;
export declare const ESTADOS_PEDIDO_INMUTABLES_DESDE_COCINA: Set<string>;
export declare function esPedidoEnMesa(tipo: string, mesaId?: string | null): boolean;
export declare function transicionEstadoPermitida(estadoActual: string, estadoNuevo: string, tipo?: string, mesaId?: string | null): boolean;
export declare function estadoActivaCocina(estado: string): boolean;
export declare function puedeMarcarPagando(tipo: string, mesaId: string | null): boolean;
export declare const SQL_WHERE_PEDIDO_BLOQUEA_MESA = "\n  estado NOT IN ('cancelado', 'rechazado', 'pagado')\n  AND (\n    estado <> 'entregado'\n    OR COALESCE(monto_pagado, 0) < total - 0.01\n  )\n";
export declare function saldoPendientePedido(total: number, montoPagado: number | string | null | undefined): number;
export declare function pedidoCobradoCompletamente(total: number, montoPagado: number | string | null | undefined): boolean;
export declare function pedidoTerminalOperativo(pedido: {
    estado: string;
    tipo: string;
    total: number | string;
    monto_pagado?: number | string | null;
}): boolean;
export declare const SQL_WHERE_PEDIDO_OPERACION_ABIERTA = "\n  estado IN (\n    'pendiente_aprobacion', 'pendiente', 'confirmado',\n    'en_cocina', 'listo', 'pagando', 'asignado', 'en_camino'\n  )\n  AND COALESCE(monto_pagado, 0) < total - 0.01\n";
export declare function sqlWherePedidoAbiertoOperativo(alias?: string): string;
export declare const SQL_WHERE_DOMICILIO_ENTREGADO_IMPAGO = "\n  estado = 'entregado'\n  AND COALESCE(monto_pagado, 0) < total - 0.01\n";
export declare const SQL_WHERE_PEDIDO_COMPLETADO = "\n  (\n    estado = 'pagado'\n    OR (\n      tipo = 'domicilio'\n      AND estado = 'entregado'\n      AND COALESCE(monto_pagado, 0) >= total - 0.01\n    )\n  )\n";
export declare const ESTADOS_COCINA_RESUELTOS: readonly ["listo", "no_disponible"];
export declare function esEstadoCocinaResuelto(estado: string): boolean;
export declare function puedeForzarPagadoSinCocinaCompleta(rol: string | null | undefined, motivo?: string | null): boolean;
export declare function pedidoCocinaCompleta(client: {
    query: (sql: string, params?: unknown[]) => Promise<{
        rows: Array<{
            n: string;
            incompletos: string;
        }>;
    }>;
}, pedidoId: string): Promise<boolean>;
export declare function puedeAvanzarCocinaPedidoPagado(params: {
    estadoPedido: string;
    total: number | string;
    montoPagado: number | string;
    estadoItem: string | null | undefined;
    nuevoEstadoItem: string;
}): boolean;
