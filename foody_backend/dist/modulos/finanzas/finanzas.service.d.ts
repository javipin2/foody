import { DatabaseService } from '../../core/database/database.service';
import { ActualizarCostoFijoDto } from './dto/actualizar-costo-fijo.dto';
import { ActualizarEmpleadoDto } from './dto/actualizar-empleado.dto';
import { CrearCostoFijoDto } from './dto/crear-costo-fijo.dto';
import { CrearEmpleadoDto } from './dto/crear-empleado.dto';
import { CrearGastoManualDto } from './dto/crear-gasto-manual.dto';
import { PagarCostoFijoDto } from './dto/pagar-costo-fijo.dto';
import { PagarEmpleadoDto } from './dto/pagar-empleado.dto';
export declare class FinanzasService {
    private readonly database;
    constructor(database: DatabaseService);
    listarCostosFijos(sucursalId: string, incluirInactivos?: boolean): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
        created_at: Date;
    }[]>;
    crearCostoFijo(dto: CrearCostoFijoDto): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
    }>;
    actualizarCostoFijo(id: string, sucursalId: string, dto: ActualizarCostoFijoDto): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
    }>;
    eliminarCostoFijo(id: string, sucursalId: string): Promise<{
        monto_mensual: number;
        id: string;
        concepto: string;
        categoria: string;
        dia_pago: number | null;
        notas: string | null;
        activo: boolean;
    }>;
    pagarCostoFijo(id: string, sucursalId: string, usuarioId: string, dto: PagarCostoFijoDto): Promise<{
        monto: number;
        costo_fijo_id: string;
        id: string;
        concepto: string;
        categoria: string;
        origen: string;
        fecha: string;
    }>;
    listarEmpleados(sucursalId: string, incluirInactivos?: boolean): Promise<{
        sueldo_base: number;
        id: string;
        nombre: string;
        cargo: string | null;
        frecuencia_pago: string;
        usuario_id: string | null;
        activo: boolean;
        created_at: Date;
    }[]>;
    crearEmpleado(dto: CrearEmpleadoDto): Promise<{
        sueldo_base: number;
        id: string;
        nombre: string;
        cargo: string | null;
        frecuencia_pago: string;
        usuario_id: string | null;
        activo: boolean;
    }>;
    actualizarEmpleado(id: string, sucursalId: string, dto: ActualizarEmpleadoDto): Promise<{
        sueldo_base: number;
        id: string;
        nombre: string;
        cargo: string | null;
        frecuencia_pago: string;
        usuario_id: string | null;
        activo: boolean;
    }>;
    pagarEmpleado(id: string, sucursalId: string, usuarioId: string, dto: PagarEmpleadoDto): Promise<{
        monto: number;
        empleado_id: string;
        id: string;
        concepto: string;
        categoria: string;
        origen: string;
        fecha: string;
    }>;
    listarGastos(sucursalId: string, desde?: string, hasta?: string): Promise<{
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
    crearGastoManual(dto: CrearGastoManualDto, usuarioId: string): Promise<{
        monto: number;
        id: string;
        concepto: string;
        categoria: string;
        origen: string;
        fecha: string;
    }>;
    resumen(sucursalId: string): Promise<{
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
    private snapshotPl;
    private construirConsejos;
}
