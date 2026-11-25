import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { AbrirCajaDto } from './dto/abrir-caja.dto';
import { CerrarCajaDto } from './dto/cerrar-caja.dto';
import { GastoCajaDto } from './dto/gasto-caja.dto';
import { CrearCuentaPorCobrarDto } from './dto/crear-cuenta-por-cobrar.dto';
import { RetiroCajaDto } from './dto/retiro-caja.dto';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { CajaMovimientosService } from '../../core/caja/caja-movimientos.service';
import { PedidosEstadoService } from '../pedidos/pedidos-estado.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { ResultadoPaginado } from '../../compartido/dto/paginacion.dto';
export declare class CajaService {
    private readonly database;
    private readonly alertasRiesgo;
    private readonly realtime;
    private readonly pedidosEstado;
    private readonly cajaMovimientos;
    private readonly auditoria;
    private readonly sucursalScope;
    constructor(database: DatabaseService, alertasRiesgo: AlertasRiesgoService, realtime: RealtimeBroadcastService, pedidosEstado: PedidosEstadoService, cajaMovimientos: CajaMovimientosService, auditoria: AuditoriaService, sucursalScope: SucursalScopeService);
    obtenerActiva(sucursalId: string, opciones?: {
        ocultarSaldo?: boolean;
    }): Promise<{
        horas_abierta: number;
        total_ventas: number;
        total_gastos: number;
        total_retiros: number;
        saldo_sistema: number;
    } | {
        arqueo_ciego: boolean;
    } | null>;
    abrir(dto: AbrirCajaDto, usuarioId: string): Promise<{
        horas_abierta: number;
        total_ventas: number;
        total_gastos: number;
        total_retiros: number;
        saldo_sistema: number;
    } | {
        arqueo_ciego: boolean;
    } | null>;
    cerrar(dto: CerrarCajaDto, usuario: JwtPayload): Promise<{
        caja_id: string;
        sucursal_id: string;
        monto_final_sistema: number;
        monto_final_contado: number;
        diferencia: number;
        propinas_turno: number;
        estado: string;
    }>;
    listarMovimientos(cajaId: string, sucursalId: string, page?: number, limit?: number): Promise<ResultadoPaginado<Record<string, unknown>>>;
    listarMovimientosPedido(pedidoId: string, sucursalId: string, page?: number, limit?: number): Promise<ResultadoPaginado<Record<string, unknown>>>;
    retiroParcial(dto: RetiroCajaDto, usuarioId: string, sucursalId: string): Promise<{
        ok: boolean;
    }>;
    listarCuentasPorCobrar(sucursalId: string, incluirPagadas?: boolean): Promise<import("pg").QueryResultRow[]>;
    resumenCuentasPorCobrar(sucursalId: string): Promise<{
        total_pendiente: number;
        cantidad_pendiente: number;
        antiguas_7d: number;
        dias_alerta: number;
    }>;
    crearCuentaPorCobrar(dto: CrearCuentaPorCobrarDto, usuarioId: string): Promise<import("pg").QueryResultRow | null>;
    pagarCuentaPorCobrar(cuentaId: string, sucursalId: string, usuarioId: string, metodoPago?: string): Promise<{
        id: string;
        estado: string;
        monto: number;
        metodo_pago: string;
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
