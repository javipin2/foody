import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
export declare class PedidosCuentaMesaService {
    private readonly database;
    constructor(database: DatabaseService);
    listarActivosPorMesa(sucursalId: string, mesaId: string): Promise<{
        mesa_id: string;
        mesa_nombre: string;
        total_acumulado: number;
        cuenta: {
            modo: string;
            cantidad_tickets: number;
            mesa_grupo: {
                mesas: {
                    id: string;
                    nombre: string;
                    es_actual: boolean;
                }[];
            } | null;
        };
        pagos_abonos: {
            id: string;
            monto: number;
            propina: number;
            metodo_pago: string;
            numero_pedido: string | null;
            created_at: Date;
            referencia: string | null;
            responsable_nombre: string | null;
        }[];
        pedidos: {
            id: string;
            numero_pedido: string;
            tipo: string;
            estado: string;
            total: number;
            monto_pagado: number;
            saldo_pendiente: number;
            created_at: Date;
            cliente_nombre: string | null;
            mesera_nombre: string | null;
            observaciones: string | null;
            items: any[];
        }[];
    }>;
    marcarEstadoOperativoMesa(client: PoolClient, mesaId: string, sucursalId: string, estado: 'ocupada' | 'pagando' | 'libre'): Promise<void>;
    liberarMesaSiSinPedidosActivos(client: PoolClient, mesaId: string, sucursalId: string): Promise<void>;
    private consultarUnoCliente;
}
