"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.FinanzasService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const CATEGORIAS_VALIDAS = new Set([
    'arriendo',
    'servicios',
    'nomina',
    'publicidad',
    'mercado',
    'operativo',
    'otros',
]);
function normalizarCategoria(raw) {
    const c = (raw ?? 'otros').trim().toLowerCase();
    return CATEGORIAS_VALIDAS.has(c) ? c : 'otros';
}
function hoyIso() {
    return new Date().toISOString().slice(0, 10);
}
let FinanzasService = class FinanzasService {
    database;
    constructor(database) {
        this.database = database;
    }
    async listarCostosFijos(sucursalId, incluirInactivos = false) {
        const filas = await this.database.consultar(`SELECT id, concepto, monto_mensual::text, COALESCE(categoria, 'otros') AS categoria,
              dia_pago, notas, activo, created_at
       FROM costos_operativos_fijos
       WHERE sucursal_id = $1
         AND ($2::bool OR activo = true)
       ORDER BY activo DESC, concepto ASC`, [sucursalId, incluirInactivos]);
        return filas.map((f) => ({
            ...f,
            monto_mensual: Number(f.monto_mensual),
        }));
    }
    async crearCostoFijo(dto) {
        const fila = await this.database.consultarUno(`INSERT INTO costos_operativos_fijos
         (sucursal_id, concepto, monto_mensual, categoria, dia_pago, notas, activo)
       VALUES ($1, $2, $3, $4, $5, $6, true)
       RETURNING id, concepto, monto_mensual::text, COALESCE(categoria, 'otros') AS categoria,
                 dia_pago, notas, activo`, [
            dto.sucursal_id,
            dto.concepto.trim(),
            dto.monto_mensual,
            normalizarCategoria(dto.categoria),
            dto.dia_pago ?? null,
            dto.notas ?? null,
        ]);
        return {
            ...fila,
            monto_mensual: Number(fila.monto_mensual),
        };
    }
    async actualizarCostoFijo(id, sucursalId, dto) {
        const actual = await this.database.consultarUno(`SELECT id FROM costos_operativos_fijos WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!actual) {
            throw new common_1.NotFoundException({
                error: 'COSTO_FIJO_NO_ENCONTRADO',
                mensaje: 'Costo fijo no encontrado',
            });
        }
        const fila = await this.database.consultarUno(`UPDATE costos_operativos_fijos SET
         concepto = COALESCE($3, concepto),
         monto_mensual = COALESCE($4, monto_mensual),
         categoria = COALESCE($5, categoria),
         dia_pago = COALESCE($6, dia_pago),
         notas = COALESCE($7, notas),
         activo = COALESCE($8, activo)
       WHERE id = $1 AND sucursal_id = $2
       RETURNING id, concepto, monto_mensual::text, COALESCE(categoria, 'otros') AS categoria,
                 dia_pago, notas, activo`, [
            id,
            sucursalId,
            dto.concepto?.trim() ?? null,
            dto.monto_mensual ?? null,
            dto.categoria != null ? normalizarCategoria(dto.categoria) : null,
            dto.dia_pago ?? null,
            dto.notas ?? null,
            dto.activo ?? null,
        ]);
        return {
            ...fila,
            monto_mensual: Number(fila.monto_mensual),
        };
    }
    async eliminarCostoFijo(id, sucursalId) {
        return this.actualizarCostoFijo(id, sucursalId, { activo: false });
    }
    async pagarCostoFijo(id, sucursalId, usuarioId, dto) {
        const fijo = await this.database.consultarUno(`SELECT id, concepto, monto_mensual::text, COALESCE(categoria, 'otros') AS categoria, activo
       FROM costos_operativos_fijos
       WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!fijo) {
            throw new common_1.NotFoundException({
                error: 'COSTO_FIJO_NO_ENCONTRADO',
                mensaje: 'Costo fijo no encontrado',
            });
        }
        if (!fijo.activo) {
            throw new common_1.BadRequestException({
                error: 'COSTO_FIJO_INACTIVO',
                mensaje: 'No se puede pagar un costo fijo inactivo',
            });
        }
        const monto = dto.monto ?? Number(fijo.monto_mensual);
        if (monto <= 0) {
            throw new common_1.BadRequestException({
                error: 'MONTO_INVALIDO',
                mensaje: 'El monto del pago debe ser mayor a cero',
            });
        }
        const fecha = dto.fecha ?? hoyIso();
        const concepto = dto.concepto?.trim() || `Pago ${fijo.concepto}`;
        const gasto = await this.database.consultarUno(`INSERT INTO gastos
         (sucursal_id, caja_id, concepto, monto, categoria, usuario_id,
          origen, fecha, costo_fijo_id, periodo_desde, periodo_hasta, registrado_por)
       VALUES ($1, NULL, $2, $3, $4, $5, 'fijo', $6::date, $7, $8::date, $9::date, $5)
       RETURNING id, concepto, monto::text, categoria, origen, fecha::text`, [
            sucursalId,
            concepto,
            monto,
            normalizarCategoria(fijo.categoria),
            usuarioId,
            fecha,
            fijo.id,
            dto.periodo_desde ?? null,
            dto.periodo_hasta ?? null,
        ]);
        return {
            ...gasto,
            monto: Number(gasto.monto),
            costo_fijo_id: fijo.id,
        };
    }
    async listarEmpleados(sucursalId, incluirInactivos = false) {
        const filas = await this.database.consultar(`SELECT id, nombre, cargo, sueldo_base::text, frecuencia_pago,
              usuario_id, activo, created_at
       FROM empleados
       WHERE sucursal_id = $1
         AND ($2::bool OR activo = true)
       ORDER BY activo DESC, nombre ASC`, [sucursalId, incluirInactivos]);
        return filas.map((f) => ({
            ...f,
            sueldo_base: Number(f.sueldo_base),
        }));
    }
    async crearEmpleado(dto) {
        const frecuencia = dto.frecuencia_pago ?? 'mensual';
        const fila = await this.database.consultarUno(`INSERT INTO empleados
         (sucursal_id, nombre, cargo, sueldo_base, frecuencia_pago, usuario_id, activo)
       VALUES ($1, $2, $3, $4, $5, $6, true)
       RETURNING id, nombre, cargo, sueldo_base::text, frecuencia_pago, usuario_id, activo`, [
            dto.sucursal_id,
            dto.nombre.trim(),
            dto.cargo?.trim() ?? null,
            dto.sueldo_base,
            frecuencia,
            dto.usuario_id ?? null,
        ]);
        return {
            ...fila,
            sueldo_base: Number(fila.sueldo_base),
        };
    }
    async actualizarEmpleado(id, sucursalId, dto) {
        const actual = await this.database.consultarUno(`SELECT id FROM empleados WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!actual) {
            throw new common_1.NotFoundException({
                error: 'EMPLEADO_NO_ENCONTRADO',
                mensaje: 'Empleado no encontrado',
            });
        }
        const fila = await this.database.consultarUno(`UPDATE empleados SET
         nombre = COALESCE($3, nombre),
         cargo = COALESCE($4, cargo),
         sueldo_base = COALESCE($5, sueldo_base),
         frecuencia_pago = COALESCE($6, frecuencia_pago),
         usuario_id = COALESCE($7, usuario_id),
         activo = COALESCE($8, activo)
       WHERE id = $1 AND sucursal_id = $2
       RETURNING id, nombre, cargo, sueldo_base::text, frecuencia_pago, usuario_id, activo`, [
            id,
            sucursalId,
            dto.nombre?.trim() ?? null,
            dto.cargo?.trim() ?? null,
            dto.sueldo_base ?? null,
            dto.frecuencia_pago ?? null,
            dto.usuario_id ?? null,
            dto.activo ?? null,
        ]);
        return {
            ...fila,
            sueldo_base: Number(fila.sueldo_base),
        };
    }
    async pagarEmpleado(id, sucursalId, usuarioId, dto) {
        const emp = await this.database.consultarUno(`SELECT id, nombre, sueldo_base::text, frecuencia_pago, activo
       FROM empleados
       WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!emp) {
            throw new common_1.NotFoundException({
                error: 'EMPLEADO_NO_ENCONTRADO',
                mensaje: 'Empleado no encontrado',
            });
        }
        if (!emp.activo) {
            throw new common_1.BadRequestException({
                error: 'EMPLEADO_INACTIVO',
                mensaje: 'No se puede pagar a un empleado inactivo',
            });
        }
        const monto = dto.monto ?? Number(emp.sueldo_base);
        if (monto <= 0) {
            throw new common_1.BadRequestException({
                error: 'MONTO_INVALIDO',
                mensaje: 'El monto del pago debe ser mayor a cero',
            });
        }
        const fecha = dto.fecha ?? hoyIso();
        const concepto = dto.concepto?.trim() ||
            `Nómina ${emp.nombre} (${emp.frecuencia_pago})`;
        const gasto = await this.database.consultarUno(`INSERT INTO gastos
         (sucursal_id, caja_id, concepto, monto, categoria, usuario_id,
          origen, fecha, empleado_id, periodo_desde, periodo_hasta, registrado_por)
       VALUES ($1, NULL, $2, $3, 'nomina', $4, 'nomina', $5::date, $6, $7::date, $8::date, $4)
       RETURNING id, concepto, monto::text, categoria, origen, fecha::text`, [
            sucursalId,
            concepto,
            monto,
            usuarioId,
            fecha,
            emp.id,
            dto.periodo_desde ?? null,
            dto.periodo_hasta ?? null,
        ]);
        return {
            ...gasto,
            monto: Number(gasto.monto),
            empleado_id: emp.id,
        };
    }
    async listarGastos(sucursalId, desde, hasta) {
        const d = desde ?? hoyIso().slice(0, 8) + '01';
        const h = hasta ?? hoyIso();
        const filas = await this.database.consultar(`SELECT id, concepto, monto::text, categoria, origen, fecha::text,
              caja_id, empleado_id, costo_fijo_id,
              periodo_desde::text, periodo_hasta::text, created_at
       FROM gastos
       WHERE sucursal_id = $1
         AND fecha >= $2::date
         AND fecha <= $3::date
       ORDER BY fecha DESC, created_at DESC`, [sucursalId, d, h]);
        return filas.map((f) => ({
            ...f,
            monto: Number(f.monto),
        }));
    }
    async crearGastoManual(dto, usuarioId) {
        const fecha = dto.fecha ?? hoyIso();
        const gasto = await this.database.consultarUno(`INSERT INTO gastos
         (sucursal_id, caja_id, concepto, monto, categoria, usuario_id,
          origen, fecha, registrado_por, comprobante_url)
       VALUES ($1, NULL, $2, $3, $4, $5, 'manual', $6::date, $5, $7)
       RETURNING id, concepto, monto::text, categoria, origen, fecha::text`, [
            dto.sucursal_id,
            dto.concepto.trim(),
            dto.monto,
            normalizarCategoria(dto.categoria),
            usuarioId,
            fecha,
            dto.comprobante_url ?? null,
        ]);
        return {
            ...gasto,
            monto: Number(gasto.monto),
        };
    }
    async resumen(sucursalId) {
        const hoy = await this.database.consultarUno(`SELECT
         (date_trunc('month', (now() AT TIME ZONE 'America/Bogota')))::date::text AS mes_desde,
         ((now() AT TIME ZONE 'America/Bogota')::date)::text AS mes_hasta,
         (date_trunc('month', (now() AT TIME ZONE 'America/Bogota')) - interval '1 month')::date::text AS ant_desde,
         (date_trunc('month', (now() AT TIME ZONE 'America/Bogota')) - interval '1 day')::date::text AS ant_hasta,
         EXTRACT(DAY FROM (now() AT TIME ZONE 'America/Bogota'))::text AS dia_hoy`);
        const mesDesde = hoy.mes_desde;
        const mesHasta = hoy.mes_hasta;
        const antDesde = hoy.ant_desde;
        const antHasta = hoy.ant_hasta;
        const diaHoy = Number(hoy.dia_hoy);
        const [actual, anterior, fijosPend, empPend] = await Promise.all([
            this.snapshotPl(sucursalId, mesDesde, mesHasta),
            this.snapshotPl(sucursalId, antDesde, antHasta),
            this.database.consultar(`SELECT cf.id, cf.concepto, cf.monto_mensual::text,
                COALESCE(cf.categoria, 'otros') AS categoria, cf.dia_pago
         FROM costos_operativos_fijos cf
         WHERE cf.sucursal_id = $1 AND cf.activo = true
           AND NOT EXISTS (
             SELECT 1 FROM gastos g
             WHERE g.costo_fijo_id = cf.id
               AND g.fecha >= $2::date AND g.fecha <= $3::date
           )
         ORDER BY COALESCE(cf.dia_pago, 99), cf.concepto`, [sucursalId, mesDesde, mesHasta]),
            this.database.consultar(`SELECT e.id, e.nombre, e.cargo, e.sueldo_base::text, e.frecuencia_pago
         FROM empleados e
         WHERE e.sucursal_id = $1 AND e.activo = true
           AND NOT EXISTS (
             SELECT 1 FROM gastos g
             WHERE g.empleado_id = e.id
               AND g.origen = 'nomina'
               AND g.fecha >= $2::date AND g.fecha <= $3::date
           )
         ORDER BY e.nombre`, [sucursalId, mesDesde, mesHasta]),
        ]);
        const fijos = fijosPend.map((f) => {
            const dia = f.dia_pago;
            const vencido = dia != null && diaHoy >= dia;
            return {
                id: f.id,
                tipo: 'fijo',
                concepto: f.concepto,
                monto: Number(f.monto_mensual),
                categoria: f.categoria,
                dia_pago: dia,
                urgente: vencido,
            };
        });
        const empleados = empPend.map((e) => ({
            id: e.id,
            tipo: 'nomina',
            concepto: e.nombre,
            cargo: e.cargo,
            monto: Number(e.sueldo_base),
            frecuencia_pago: e.frecuencia_pago,
            urgente: false,
        }));
        const totalPendiente = fijos.reduce((s, x) => s + x.monto, 0) +
            empleados.reduce((s, x) => s + x.monto, 0);
        const deltaUtilidadPct = anterior.utilidad_neta === 0
            ? actual.utilidad_neta > 0
                ? 100
                : actual.utilidad_neta < 0
                    ? -100
                    : 0
            : Math.round(((actual.utilidad_neta - anterior.utilidad_neta) /
                Math.abs(anterior.utilidad_neta)) *
                1000) / 10;
        const consejos = this.construirConsejos({
            utilidad_neta: actual.utilidad_neta,
            margen_neto_pct: actual.margen_neto_pct,
            cobertura_costo_pct: actual.cobertura_costo_pct,
            ventas_netas: actual.ventas_netas,
            total_gastos: actual.total_gastos,
            pendientes_count: fijos.length + empleados.length,
            delta_utilidad_pct: deltaUtilidadPct,
        });
        return {
            periodo: { desde: mesDesde, hasta: mesHasta, label: 'Mes en curso' },
            mes_actual: actual,
            mes_anterior: {
                ...anterior,
                periodo: { desde: antDesde, hasta: antHasta },
            },
            delta_utilidad_pct: deltaUtilidadPct,
            pendientes: {
                fijos,
                empleados,
                cantidad: fijos.length + empleados.length,
                total_estimado: Math.round(totalPendiente * 100) / 100,
                urgentes: fijos.filter((f) => f.urgente).length,
            },
            consejos,
        };
    }
    async snapshotPl(sucursalId, desde, hasta) {
        const ventas = await this.database.consultarUno(`SELECT COALESCE(SUM(total), 0)::text AS ventas_netas,
              COUNT(*)::text AS pedidos
       FROM pedidos
       WHERE sucursal_id = $1
         AND (created_at AT TIME ZONE 'America/Bogota')::date >= $2::date
         AND (created_at AT TIME ZONE 'America/Bogota')::date <= $3::date
         AND estado NOT IN ('cancelado', 'rechazado')`, [sucursalId, desde, hasta]);
        const cogs = await this.database.consultarUno(`SELECT COALESCE(SUM(pi.cantidad * COALESCE(pi.costo_unitario, 0)), 0)::text AS costo_ventas,
              COUNT(*)::text AS lineas_total,
              COUNT(*) FILTER (WHERE pi.costo_unitario IS NOT NULL)::text AS lineas_con_costo
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       WHERE p.sucursal_id = $1
         AND (p.created_at AT TIME ZONE 'America/Bogota')::date >= $2::date
         AND (p.created_at AT TIME ZONE 'America/Bogota')::date <= $3::date
         AND p.estado NOT IN ('cancelado', 'rechazado')`, [sucursalId, desde, hasta]);
        const gastos = await this.database.consultarUno(`SELECT COALESCE(SUM(monto), 0)::text AS total
       FROM gastos
       WHERE sucursal_id = $1
         AND fecha >= $2::date AND fecha <= $3::date`, [sucursalId, desde, hasta]);
        const ventasNetas = Number(ventas?.ventas_netas ?? 0);
        const costoVentas = Number(cogs?.costo_ventas ?? 0);
        const totalGastos = Number(gastos?.total ?? 0);
        const utilidadBruta = Math.round((ventasNetas - costoVentas) * 100) / 100;
        const utilidadNeta = Math.round((utilidadBruta - totalGastos) * 100) / 100;
        const lineasTotal = Number(cogs?.lineas_total ?? 0);
        const lineasConCosto = Number(cogs?.lineas_con_costo ?? 0);
        const cobertura = lineasTotal > 0
            ? Math.round((lineasConCosto / lineasTotal) * 1000) / 10
            : 100;
        return {
            ventas_netas: ventasNetas,
            pedidos: Number(ventas?.pedidos ?? 0),
            costo_ventas: Math.round(costoVentas * 100) / 100,
            utilidad_bruta: utilidadBruta,
            total_gastos: Math.round(totalGastos * 100) / 100,
            utilidad_neta: utilidadNeta,
            margen_neto_pct: ventasNetas > 0
                ? Math.round((utilidadNeta / ventasNetas) * 1000) / 10
                : 0,
            es_rentable: utilidadNeta >= 0,
            cobertura_costo_pct: cobertura,
        };
    }
    construirConsejos(p) {
        const out = [];
        if (p.utilidad_neta < 0) {
            out.push({
                codigo: 'perdida_mes',
                nivel: 'alerta',
                mensaje: 'Este mes vas en pérdida. Revisa gastos fijos, nómina o márgenes de platos.',
            });
        }
        else if (p.margen_neto_pct > 0 && p.margen_neto_pct < 10) {
            out.push({
                codigo: 'margen_bajo',
                nivel: 'aviso',
                mensaje: 'Ganas poco: el margen neto está bajo el 10%. Sube ticket o baja costos fijos.',
            });
        }
        if (p.cobertura_costo_pct < 80) {
            out.push({
                codigo: 'cobertura_costo',
                nivel: 'aviso',
                mensaje: 'Varias ventas no tienen costo registrado. Completa recetas en Costos y márgenes.',
            });
        }
        if (p.ventas_netas > 0 && p.total_gastos / p.ventas_netas > 0.4) {
            out.push({
                codigo: 'gastos_altos',
                nivel: 'aviso',
                mensaje: 'Los gastos superan el 40% de las ventas. Revisa arriendo, servicios y nómina.',
            });
        }
        if (p.pendientes_count > 0) {
            out.push({
                codigo: 'pagos_pendientes',
                nivel: 'info',
                mensaje: `Tienes ${p.pendientes_count} pago(s) pendiente(s) este mes (fijos o nómina).`,
            });
        }
        if (p.utilidad_neta > 0 &&
            p.delta_utilidad_pct != null &&
            p.delta_utilidad_pct > 0) {
            out.push({
                codigo: 'mejor_que_anterior',
                nivel: 'info',
                mensaje: 'Vas mejor que el mes pasado en utilidad neta. Mantén el ritmo.',
            });
        }
        if (out.length === 0) {
            out.push({
                codigo: 'ok',
                nivel: 'info',
                mensaje: 'Sin alertas fuertes: registra gastos al día y revisa Rentabilidad.',
            });
        }
        return out;
    }
};
exports.FinanzasService = FinanzasService;
exports.FinanzasService = FinanzasService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], FinanzasService);
//# sourceMappingURL=finanzas.service.js.map