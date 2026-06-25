export declare const TRANSICIONES_PEDIDO: Readonly<Record<string, readonly string[]>>;
export declare function esPedidoEnMesa(tipo: string, mesaId?: string | null): boolean;
export declare function transicionEstadoPermitida(estadoActual: string, estadoNuevo: string, tipo?: string, mesaId?: string | null): boolean;
export declare function estadoActivaCocina(estado: string): boolean;
export declare function puedeMarcarPagando(tipo: string, mesaId: string | null): boolean;
export declare const SQL_WHERE_PEDIDO_BLOQUEA_MESA = "\n  estado NOT IN ('cancelado', 'rechazado', 'pagado')\n  AND (\n    estado <> 'entregado'\n    OR COALESCE(monto_pagado, 0) < total - 0.01\n  )\n";
