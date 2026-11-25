import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CajaService } from './caja.service';
import { AbrirCajaDto } from './dto/abrir-caja.dto';
import { CerrarCajaDto } from './dto/cerrar-caja.dto';
import { GastoCajaDto } from './dto/gasto-caja.dto';
import { CrearCuentaPorCobrarDto } from './dto/crear-cuenta-por-cobrar.dto';
import { PagarCuentaPorCobrarDto } from './dto/pagar-cuenta-por-cobrar.dto';
import { RetiroCajaDto } from './dto/retiro-caja.dto';
import { DevolucionCajaDto } from './dto/devolucion-caja.dto';
import { CajaMovimientosPedidoQueryDto } from './dto/caja-movimientos-pedido-query.dto';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';
export declare class CajaController {
    private readonly cajaService;
    private readonly sucursalScope;
    constructor(cajaService: CajaService, sucursalScope: SucursalScopeService);
    activa(sucursalId: string, usuario: JwtPayload): Promise<{
        horas_abierta: number;
        total_ventas: number;
        total_gastos: number;
        total_retiros: number;
        saldo_sistema: number;
    } | {
        arqueo_ciego: boolean;
    } | null>;
    abrir(dto: AbrirCajaDto, usuario: JwtPayload): Promise<{
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
    resumenFiados(sucursalId: string, usuario: JwtPayload): Promise<{
        total_pendiente: number;
        cantidad_pendiente: number;
        antiguas_7d: number;
        dias_alerta: number;
    }>;
    listarFiados(sucursalId: string, incluirPagadas: string | undefined, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crearFiado(dto: CrearCuentaPorCobrarDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    pagarFiado(id: string, dto: PagarCuentaPorCobrarDto, usuario: JwtPayload): Promise<{
        id: string;
        estado: string;
        monto: number;
        metodo_pago: string;
        caja_registrada: boolean;
    }>;
    movimientos(cajaId: string, query: PaginacionQueryDto, usuario: JwtPayload): Promise<import("../../compartido/dto/paginacion.dto").ResultadoPaginado<Record<string, unknown>>>;
    movimientosPedido(pedidoId: string, query: CajaMovimientosPedidoQueryDto, usuario: JwtPayload): Promise<import("../../compartido/dto/paginacion.dto").ResultadoPaginado<Record<string, unknown>>>;
    retiro(dto: RetiroCajaDto, usuario: JwtPayload): Promise<{
        ok: boolean;
    }>;
    devolucion(dto: DevolucionCajaDto, usuario: JwtPayload): Promise<{
        registrado: boolean;
        monto: number;
    }>;
    gasto(dto: GastoCajaDto, usuario: JwtPayload): Promise<{
        ok: boolean;
    }>;
}
