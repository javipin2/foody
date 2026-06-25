import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CajaService } from './caja.service';
import { AbrirCajaDto } from './dto/abrir-caja.dto';
import { CerrarCajaDto } from './dto/cerrar-caja.dto';
import { GastoCajaDto } from './dto/gasto-caja.dto';
import { CrearCuentaPorCobrarDto } from './dto/crear-cuenta-por-cobrar.dto';
import { RetiroCajaDto } from './dto/retiro-caja.dto';
import { DevolucionCajaDto } from './dto/devolucion-caja.dto';
export declare class CajaController {
    private readonly cajaService;
    private readonly sucursalScope;
    constructor(cajaService: CajaService, sucursalScope: SucursalScopeService);
    activa(sucursalId: string, usuario: JwtPayload): Promise<{
        total_ventas: number;
        total_gastos: number;
        total_retiros: number;
        saldo_sistema: number;
    } | {
        arqueo_ciego: boolean;
    } | null>;
    abrir(dto: AbrirCajaDto, usuario: JwtPayload): Promise<{
        total_ventas: number;
        total_gastos: number;
        total_retiros: number;
        saldo_sistema: number;
    } | {
        arqueo_ciego: boolean;
    } | null>;
    cerrar(dto: CerrarCajaDto, usuario: JwtPayload): Promise<{
        caja_id: string;
        monto_final_sistema: number;
        monto_final_contado: number;
        diferencia: number;
        estado: string;
        advertencias: string[];
    }>;
    listarFiados(sucursalId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
    crearFiado(dto: CrearCuentaPorCobrarDto, usuario: JwtPayload): Promise<import("pg").QueryResultRow | null>;
    pagarFiado(id: string, usuario: JwtPayload): Promise<{
        id: string;
        estado: string;
        monto: number;
        caja_registrada: boolean;
    }>;
    movimientos(cajaId: string, usuario: JwtPayload): Promise<import("pg").QueryResultRow[]>;
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
