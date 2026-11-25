import { PoolClient } from 'pg';
import { CajaMovimientosService, ReversaVentasPedidoResultado } from '../../core/caja/caja-movimientos.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
export declare const METODOS_CON_CAJA: readonly ["efectivo", "tarjeta", "transferencia", "nequi"];
export declare function esPagoDiferidoMesa(tipo: string, mesaId: string | null | undefined): boolean;
export declare class PedidosCajaAuditoriaService {
    private readonly cajaMovimientos;
    private readonly auditoria;
    constructor(cajaMovimientos: CajaMovimientosService, auditoria: AuditoriaService);
    debeRegistrarVentaAlCrear(estadoInicial: string, tipo: string, mesaId: string | null | undefined, metodoPago: string): boolean;
    obtenerCajaAbiertaId(client: PoolClient, sucursalId: string): Promise<string | null>;
    registrarVentaEnCaja(client: PoolClient, sucursalId: string, pedidoId: string, total: number, metodoPago: string, opciones?: {
        exigirCaja?: boolean;
        descripcion?: string;
        usuarioId?: string;
    }): Promise<boolean>;
    revertirVentasPedido(client: PoolClient, pedidoId: string, sucursalId: string, usuarioId?: string, motivo?: string): Promise<ReversaVentasPedidoResultado>;
    registrarAuditoria(client: PoolClient, sucursalId: string, pedidoId: string, datos: Record<string, unknown>): Promise<void>;
    registrarAuditoriaCobroMesa(client: PoolClient, sucursalId: string, mesaId: string, usuarioId: string, datos: Record<string, unknown>): Promise<void>;
}
