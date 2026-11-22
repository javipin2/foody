import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarCostoFijoDto } from './dto/actualizar-costo-fijo.dto';
import { ActualizarEmpleadoDto } from './dto/actualizar-empleado.dto';
import { CrearCostoFijoDto } from './dto/crear-costo-fijo.dto';
import { CrearEmpleadoDto } from './dto/crear-empleado.dto';
import { CrearGastoManualDto } from './dto/crear-gasto-manual.dto';
import { PagarCostoFijoDto } from './dto/pagar-costo-fijo.dto';
import { PagarEmpleadoDto } from './dto/pagar-empleado.dto';
import { FinanzasService } from './finanzas.service';
export declare class FinanzasController {
    private readonly finanzasService;
    private readonly sucursalScope;
    constructor(finanzasService: FinanzasService, sucursalScope: SucursalScopeService);
    listarCostosFijos(sucursalId: string, incluirInactivos: string | undefined, usuario: JwtPayload): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
        created_at: Date;
    }[]>;
    crearCostoFijo(dto: CrearCostoFijoDto, usuario: JwtPayload): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
    }>;
    actualizarCostoFijo(id: string, dto: ActualizarCostoFijoDto, sucursalId: string | undefined, usuario: JwtPayload): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
    }>;
    eliminarCostoFijo(id: string, sucursalId: string | undefined, usuario: JwtPayload): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
    }>;
    pagarCostoFijo(id: string, dto: PagarCostoFijoDto, sucursalId: string | undefined, usuario: JwtPayload): Promise<{
        monto: number;
        costo_fijo_id: string;
        id: string;
        concepto: string;
        categoria: string;
        origen: string;
        fecha: string;
    }>;
    listarEmpleados(sucursalId: string, incluirInactivos: string | undefined, usuario: JwtPayload): Promise<{
        sueldo_base: number;
        id: string;
        nombre: string;
        cargo: string | null;
        frecuencia_pago: string;
        usuario_id: string | null;
        activo: boolean;
        created_at: Date;
    }[]>;
    crearEmpleado(dto: CrearEmpleadoDto, usuario: JwtPayload): Promise<{
        sueldo_base: number;
        id: string;
        nombre: string;
        cargo: string | null;
        frecuencia_pago: string;
        usuario_id: string | null;
        activo: boolean;
    }>;
    actualizarEmpleado(id: string, dto: ActualizarEmpleadoDto, sucursalId: string | undefined, usuario: JwtPayload): Promise<{
        sueldo_base: number;
        id: string;
        nombre: string;
        cargo: string | null;
        frecuencia_pago: string;
        usuario_id: string | null;
        activo: boolean;
    }>;
    pagarEmpleado(id: string, dto: PagarEmpleadoDto, sucursalId: string | undefined, usuario: JwtPayload): Promise<{
        monto: number;
        empleado_id: string;
        id: string;
        concepto: string;
        categoria: string;
        origen: string;
        fecha: string;
    }>;
    resumen(sucursalId: string, usuario: JwtPayload): Promise<{
        periodo: {
            desde: string;
            hasta: string;
            label: string;
        };
        mes_actual: {
            ventas_netas: number;
            pedidos: number;
            costo_ventas: number;
            utilidad_bruta: number;
            total_gastos: number;
            utilidad_neta: number;
            margen_neto_pct: number;
            es_rentable: boolean;
            cobertura_costo_pct: number;
        };
        mes_anterior: {
            periodo: {
                desde: string;
                hasta: string;
            };
            ventas_netas: number;
            pedidos: number;
            costo_ventas: number;
            utilidad_bruta: number;
            total_gastos: number;
            utilidad_neta: number;
            margen_neto_pct: number;
            es_rentable: boolean;
            cobertura_costo_pct: number;
        };
        delta_utilidad_pct: number;
        pendientes: {
            fijos: {
                id: string;
                tipo: "fijo";
                concepto: string;
                monto: number;
                categoria: string;
                dia_pago: number | null;
                urgente: boolean;
            }[];
            empleados: {
                id: string;
                tipo: "nomina";
                concepto: string;
                cargo: string | null;
                monto: number;
                frecuencia_pago: string;
                urgente: boolean;
            }[];
            cantidad: number;
            total_estimado: number;
            urgentes: number;
        };
        consejos: {
            codigo: string;
            nivel: "info" | "aviso" | "alerta";
            mensaje: string;
        }[];
    }>;
    listarGastos(sucursalId: string, desde: string | undefined, hasta: string | undefined, usuario: JwtPayload): Promise<{
        monto: number;
        id: string;
        concepto: string;
        categoria: string | null;
        origen: string;
        fecha: string;
        caja_id: string | null;
        empleado_id: string | null;
        costo_fijo_id: string | null;
        periodo_desde: string | null;
        periodo_hasta: string | null;
        created_at: Date;
    }[]>;
    crearGastoManual(dto: CrearGastoManualDto, usuario: JwtPayload): Promise<{
        monto: number;
        id: string;
        concepto: string;
        categoria: string;
        origen: string;
        fecha: string;
    }>;
}
