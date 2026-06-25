import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { AbrirCajaDto } from './dto/abrir-caja.dto';
import { CerrarCajaDto } from './dto/cerrar-caja.dto';
import { GastoCajaDto } from './dto/gasto-caja.dto';
import { CrearCuentaPorCobrarDto } from './dto/crear-cuenta-por-cobrar.dto';
import { RetiroCajaDto } from './dto/retiro-caja.dto';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
export declare class CajaService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly realtime;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, realtime: RealtimeBroadcastService);
    obtenerActiva(sucursalId: string, opciones?: {
        ocultarSaldo?: boolean;
    }): Promise<{
        total_ventas: number;
        total_gastos: number;
        total_retiros: number;
        saldo_sistema: number;
    } | {
        arqueo_ciego: boolean;
    } | null>;
    abrir(dto: AbrirCajaDto, usuarioId: string): Promise<{
        total_ventas: number;
        total_gastos: number;
        total_retiros: number;
        saldo_sistema: number;
    } | {
        arqueo_ciego: boolean;
    } | null>;
    cerrar(dto: CerrarCajaDto, usuarioId: string): Promise<{
        caja_id: string;
        monto_final_sistema: number;
        monto_final_contado: number;
        diferencia: number;
        estado: string;
        advertencias: string[];
    }>;
    listarMovimientos(cajaId: string, sucursalId: string): Promise<import("pg").QueryResultRow[]>;
    retiroParcial(dto: RetiroCajaDto, usuarioId: string, sucursalId: string): Promise<{
        ok: boolean;
    }>;
    listarCuentasPorCobrar(sucursalId: string, soloPendientes?: boolean): Promise<import("pg").QueryResultRow[]>;
    crearCuentaPorCobrar(dto: CrearCuentaPorCobrarDto, usuarioId: string): Promise<import("pg").QueryResultRow | null>;
    pagarCuentaPorCobrar(cuentaId: string, sucursalId: string, usuarioId: string): Promise<{
        id: string;
        estado: string;
        monto: number;
        caja_registrada: boolean;
    }>;
    registrarDevolucion(params: {
        caja_id: string;
        sucursal_id: string;
        pedido_id?: string;
        monto: number;
        motivo: string;
        metodo_pago?: string;
    }, usuarioId: string): Promise<{
        registrado: boolean;
        monto: number;
    }>;
    registrarGasto(dto: GastoCajaDto, usuarioId: string, sucursalId: string): Promise<{
        ok: boolean;
    }>;
    private exigirCajaAbierta;
    private calcularResumenTurno;
}
