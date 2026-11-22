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
exports.AnaliticaService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const sucursal_scope_service_1 = require("../../core/auth/sucursal-scope.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const analitica_filtros_util_1 = require("./analitica-filtros.util");
const analitica_periodo_util_1 = require("./analitica-periodo.util");
const ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
const analitica_sql_const_1 = require("./analitica-sql.const");
const sql_venta_linea_item_1 = require("../pedidos/sql-venta-linea-item");
const ESTADOS_POST_COCINA = [
    'en_cocina',
    'listo',
    'pagando',
    'asignado',
    'en_camino',
    'entregado',
];
let AnaliticaService = class AnaliticaService {
    database;
    sucursalScope;
    constructor(database, sucursalScope) {
        this.database = database;
        this.sucursalScope = sucursalScope;
    }
    async resolverContexto(usuario, query) {
        const sucursalId = await this.sucursalScope.resolverLecturaOperativa(usuario, query.sucursal_id);
        const { periodo, anterior } = (0, analitica_periodo_util_1.resolverPeriodoAnalitica)(query.preset, query.desde, query.hasta, query.comparar, query.comparar_desde, query.comparar_hasta);
        return {
            sucursalId,
            periodo,
            anterior,
            filtros: (0, analitica_filtros_util_1.parseFiltrosDesdeDto)(query),
        };
    }
    async comparativaSedesParaUsuario(usuario, query) {
        if (!usuario.restaurante_id) {
            throw new common_1.ForbiddenException('Usuario sin restaurante asignado');
        }
        if (!this.sucursalScope.esCorporativo(usuario)) {
            throw new common_1.ForbiddenException('Solo usuarios corporativos pueden comparar sedes');
        }
        const { periodo } = (0, analitica_periodo_util_1.resolverPeriodoAnalitica)(query.preset, query.desde, query.hasta, query.comparar, query.comparar_desde, query.comparar_hasta);
        return this.comparativaSedes(usuario.restaurante_id, periodo);
    }
    inicio(sucursalId, desde, hasta, filtros = {}, alias, opts) {
        const params = new analitica_filtros_util_1.SqlParams();
        const suc = params.add(sucursalId);
        const d = params.add(desde);
        const h = params.add(hasta);
        const col = alias ? `${alias}.created_at` : 'pedidos.created_at';
        const fecha = (0, ventas_metricas_sql_1.sqlFechaRango)(col, d, h);
        const extra = (0, analitica_filtros_util_1.clausulasPedidos)(params, filtros, {
            alias: alias && alias.length > 0 ? alias : 'pedidos',
            excluirCanceladosPorDefecto: opts?.excluirCanceladosPorDefecto ?? !filtros.estados?.length,
        });
        return { params, suc, fecha, extra };
    }
    inicioCaja(sucursalId, desde, hasta, filtros = {}) {
        const params = new analitica_filtros_util_1.SqlParams();
        const suc = params.add(sucursalId);
        const d = params.add(desde);
        const h = params.add(hasta);
        const fecha = (0, ventas_metricas_sql_1.sqlFechaRango)('COALESCE(p.created_at, m.created_at)', d, h);
        const extra = (0, analitica_filtros_util_1.clausulasPedidos)(params, filtros, {
            alias: 'p',
            excluirCanceladosPorDefecto: !filtros.estados?.length,
        });
        return { params, suc, fecha, extra };
    }
    async consultarVentasKpi(sucursalId, desde, hasta, filtros) {
        const usaLineas = (0, analitica_filtros_util_1.filtrosSumanPorLinea)(filtros);
        const { params, suc, fecha, extra } = this.inicio(sucursalId, desde, hasta, filtros, usaLineas ? 'p' : undefined);
        if (!usaLineas) {
            return this.database.consultarUno(`SELECT COALESCE(SUM(total), 0)::text AS ventas_netas,
                COUNT(*)::text AS pedidos,
                COALESCE(AVG(total), 0)::text AS ticket_promedio
         FROM pedidos
         WHERE sucursal_id = ${suc}
           AND ${fecha}${extra}`, params.list);
        }
        const extraItems = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(params, filtros);
        return this.database.consultarUno(`SELECT COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)::text AS ventas_netas,
              COUNT(DISTINCT p.id)::text AS pedidos,
              COALESCE(
                SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}) / NULLIF(COUNT(DISTINCT p.id), 0),
                0
              )::text AS ticket_promedio
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       LEFT JOIN productos pr ON pr.id = pi.producto_id
       WHERE p.sucursal_id = ${suc}
         AND ${fecha}${extra}${extraItems}`, params.list);
    }
    async resumen(sucursalId, periodo, anterior, filtros = {}) {
        const kpis = await this.kpisPeriodo(sucursalId, periodo.desde, periodo.hasta, filtros);
        let comparativa;
        if (anterior) {
            const prev = await this.ventasNetasPeriodo(sucursalId, anterior.desde, anterior.hasta, filtros);
            const deltaPct = prev === 0
                ? kpis.ventas_netas > 0
                    ? 100
                    : 0
                : Math.round(((kpis.ventas_netas - prev) / prev) * 1000) / 10;
            comparativa = {
                anterior: {
                    desde: anterior.desde,
                    hasta: anterior.hasta,
                    ventas_netas: prev,
                },
                delta: {
                    ventas_netas_pct: deltaPct,
                    tendencia: deltaPct > 0 ? 'sube' : deltaPct < 0 ? 'baja' : 'igual',
                },
            };
        }
        const alertasAbiertas = await this.database.consultar(`SELECT id::text, tipo, nivel, descripcion, created_at::text
       FROM alertas_riesgo
       WHERE sucursal_id = $1 AND revisada = false
       ORDER BY CASE nivel
         WHEN 'critico' THEN 1 WHEN 'alto' THEN 2 WHEN 'medio' THEN 3 ELSE 4 END,
         created_at DESC
       LIMIT 10`, [sucursalId]);
        return {
            periodo,
            sucursal_id: sucursalId,
            kpis,
            comparativa,
            alertas_abiertas_lista: alertasAbiertas.map((a) => ({
                id: a.id,
                tipo: a.tipo,
                nivel: a.nivel,
                descripcion: a.descripcion,
                created_at: a.created_at,
            })),
        };
    }
    async ventasNetasPeriodo(sucursalId, desde, hasta, filtros = {}) {
        const fila = await this.consultarVentasKpi(sucursalId, desde, hasta, filtros);
        return Number(fila?.ventas_netas ?? 0);
    }
    async kpisPeriodo(sucursalId, desde, hasta, filtros = {}) {
        const ventas = await this.consultarVentasKpi(sucursalId, desde, hasta, filtros);
        const { params: pMargen, suc: sucM, fecha: fechaM, extra: extraM } = this.inicio(sucursalId, desde, hasta, filtros, 'p');
        const extraItems = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(pMargen, filtros);
        const margen = await this.database.consultarUno(`SELECT COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)::text AS ingreso,
              COALESCE(SUM(pi.cantidad * COALESCE(pi.costo_unitario, 0)), 0)::text AS costo,
              COUNT(*)::text AS lineas_total,
              COUNT(*) FILTER (WHERE pi.costo_unitario IS NOT NULL)::text AS lineas_con_costo
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       LEFT JOIN productos pr ON pr.id = pi.producto_id
       WHERE p.sucursal_id = ${sucM}
         AND ${fechaM}${extraM}${extraItems}`, pMargen.list);
        const { params: pCancel, suc: sucC, fecha: fechaC, extra: extraC } = this.inicio(sucursalId, desde, hasta, filtros, undefined, {
            excluirCanceladosPorDefecto: false,
        });
        const cancelacion = await this.database.consultarUno(`SELECT COUNT(*)::text AS total,
              COUNT(*) FILTER (
                WHERE estado IN ('cancelado', 'rechazado')
              )::text AS cancelados
       FROM pedidos
       WHERE sucursal_id = ${sucC}
         AND ${fechaC}${extraC}`, pCancel.list);
        const { params: pPagos, suc: sucP, fecha: fechaP, extra: extraP } = this.inicioCaja(sucursalId, desde, hasta, filtros);
        const pagos = await this.database.consultarUno(`SELECT COALESCE(SUM(
                ${ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA}
              ) FILTER (WHERE m.metodo_pago = 'efectivo'), 0)::text AS efectivo,
              COALESCE(SUM(
                ${ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA}
              ) FILTER (
                WHERE m.metodo_pago IS DISTINCT FROM 'efectivo'
              ), 0)::text AS digital
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = ${sucP}
         AND ${ventas_metricas_sql_1.SQL_TIPOS_MOV_CAJA_VENTA}
         AND ${fechaP}${extraP}`, pPagos.list);
        const alertas = await this.database.consultarUno(`SELECT COUNT(*)::text AS abiertas
       FROM alertas_riesgo
       WHERE sucursal_id = $1 AND revisada = false`, [sucursalId]);
        const ingreso = Number(margen?.ingreso ?? 0);
        const costo = Number(margen?.costo ?? 0);
        const margenBruto = ingreso - costo;
        const lineasTotal = Number(margen?.lineas_total ?? 0);
        const lineasConCosto = Number(margen?.lineas_con_costo ?? 0);
        const efectivo = Number(pagos?.efectivo ?? 0);
        const digital = Number(pagos?.digital ?? 0);
        const totalPagos = efectivo + digital;
        const totalPedidos = Number(cancelacion?.total ?? 0);
        const cancelados = Number(cancelacion?.cancelados ?? 0);
        return {
            ventas_netas: Number(ventas?.ventas_netas ?? 0),
            pedidos: Number(ventas?.pedidos ?? 0),
            ticket_promedio: Math.round(Number(ventas?.ticket_promedio ?? 0) * 100) / 100,
            margen_bruto_estimado: Math.round(margenBruto * 100) / 100,
            margen_bruto_pct: ingreso > 0
                ? Math.round((margenBruto / ingreso) * 1000) / 10
                : 0,
            cobertura_costo_pct: lineasTotal > 0
                ? Math.round((lineasConCosto / lineasTotal) * 1000) / 10
                : 100,
            pct_cancelacion: totalPedidos > 0
                ? Math.round((cancelados / totalPedidos) * 1000) / 10
                : 0,
            efectivo_vs_digital: {
                efectivo: totalPagos > 0
                    ? Math.round((efectivo / totalPagos) * 1000) / 1000
                    : 0,
                digital: totalPagos > 0
                    ? Math.round((digital / totalPagos) * 1000) / 1000
                    : 0,
            },
            alertas_abiertas: Number(alertas?.abiertas ?? 0),
        };
    }
    async adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, datos) {
        if (!anterior)
            return datos;
        const actual = await this.kpisPeriodo(sucursalId, periodo.desde, periodo.hasta, filtros);
        const prev = await this.kpisPeriodo(sucursalId, anterior.desde, anterior.hasta, filtros);
        const delta = (a, b) => b === 0 ? (a > 0 ? 100 : 0) : Math.round(((a - b) / b) * 1000) / 10;
        const pct = delta(actual.ventas_netas, prev.ventas_netas);
        return {
            ...datos,
            comparativa: {
                anterior: {
                    desde: anterior.desde,
                    hasta: anterior.hasta,
                    ventas_netas: prev.ventas_netas,
                    pedidos: prev.pedidos,
                },
                delta: {
                    ventas_netas_pct: pct,
                    pedidos_pct: delta(actual.pedidos, prev.pedidos),
                    tendencia: pct > 0 ? 'sube' : pct < 0 ? 'baja' : 'igual',
                },
            },
        };
    }
    async ventas(sucursalId, periodo, filtros = {}, anterior) {
        const { desde, hasta } = periodo;
        const usaLineas = (0, analitica_filtros_util_1.filtrosSumanPorLinea)(filtros);
        const { params, suc, fecha, extra } = this.inicio(sucursalId, desde, hasta, filtros, usaLineas ? 'p' : undefined);
        const extraItems = usaLineas
            ? (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(params, filtros)
            : '';
        const fromWhere = usaLineas
            ? `FROM pedido_items pi
         JOIN pedidos p ON p.id = pi.pedido_id
         LEFT JOIN productos pr ON pr.id = pi.producto_id
         WHERE p.sucursal_id = ${suc} AND ${fecha}${extra}${extraItems}`
            : `FROM pedidos
         WHERE sucursal_id = ${suc} AND ${fecha}${extra}`;
        const sumVentas = usaLineas
            ? `COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)`
            : 'COALESCE(SUM(total), 0)';
        const countPed = usaLineas ? 'COUNT(DISTINCT p.id)' : 'COUNT(*)';
        const diaExpr = usaLineas ? ventas_metricas_sql_1.SQL_DIA_LOCAL_P : ventas_metricas_sql_1.SQL_DIA_LOCAL;
        const horaExpr = usaLineas
            ? `EXTRACT(HOUR FROM p.created_at AT TIME ZONE '${ventas_metricas_sql_1.SQL_TZ_NEGOCIO}')`
            : `EXTRACT(HOUR FROM created_at AT TIME ZONE '${ventas_metricas_sql_1.SQL_TZ_NEGOCIO}')`;
        const tipoCol = usaLineas ? 'p.tipo' : 'tipo';
        const porDia = await this.database.consultar(`SELECT ${diaExpr}::text AS dia,
              ${countPed}::text AS pedidos,
              ${sumVentas}::text AS ventas
       ${fromWhere}
       GROUP BY ${diaExpr}
       ORDER BY dia ASC`, params.list);
        const incluirHora = (0, analitica_periodo_util_1.diasEntre)(desde, hasta) <= 7;
        let porHora = [];
        if (incluirHora) {
            const filas = await this.database.consultar(`SELECT ${horaExpr}::int::text AS hora,
                ${countPed}::text AS pedidos,
                ${sumVentas}::text AS ventas
         ${fromWhere}
         GROUP BY ${horaExpr}
         ORDER BY hora ASC`, params.list);
            porHora = filas.map((f) => ({
                hora: Number(f.hora),
                pedidos: Number(f.pedidos),
                ventas: Number(f.ventas),
            }));
        }
        const porTipo = await this.database.consultar(`SELECT ${tipoCol} AS tipo,
              ${countPed}::text AS pedidos,
              ${sumVentas}::text AS ventas
       ${fromWhere}
       GROUP BY ${tipoCol}
       ORDER BY ventas DESC`, params.list);
        const { params: pCaja, suc: sucCaja, fecha: fechaCaja, extra: extraCaja, } = this.inicioCaja(sucursalId, desde, hasta, filtros);
        const porMetodo = await this.database.consultar(`SELECT COALESCE(m.metodo_pago, 'sin_metodo') AS metodo_pago,
              COALESCE(SUM(${ventas_metricas_sql_1.SQL_NETO_MOVIMIENTO_CAJA}), 0)::text AS total,
              COUNT(*) FILTER (WHERE m.tipo = 'venta')::text AS movimientos
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = ${sucCaja}
         AND ${ventas_metricas_sql_1.SQL_TIPOS_MOV_CAJA_VENTA}
         AND ${fechaCaja}${extraCaja}
       GROUP BY m.metodo_pago
       ORDER BY total DESC`, pCaja.list);
        const { params: pCat, suc: sucCat, fecha: fechaCat, extra: extraCat } = this.inicio(sucursalId, desde, hasta, filtros, 'p');
        const extraItemsCat = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(pCat, filtros);
        const porCategoria = await this.database.consultar(`SELECT COALESCE(cat.id::text, 'sin_categoria') AS categoria_id,
              COALESCE(cat.nombre, 'Sin categoría') AS nombre,
              COALESCE(SUM(pi.cantidad), 0)::text AS unidades,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)::text AS ventas
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       JOIN productos pr ON pr.id = pi.producto_id
       LEFT JOIN categorias cat ON cat.id = pr.categoria_id
       WHERE p.sucursal_id = ${sucCat}
         AND ${fechaCat}${extraCat}${extraItemsCat}
       GROUP BY cat.id, cat.nombre
       ORDER BY ventas DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, pCat.list);
        return this.adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, {
            periodo,
            sucursal_id: sucursalId,
            por_dia: porDia.map((f) => ({
                dia: f.dia,
                pedidos: Number(f.pedidos),
                ventas: Number(f.ventas),
            })),
            por_hora: porHora,
            por_tipo: porTipo.map((f) => ({
                tipo: f.tipo,
                pedidos: Number(f.pedidos),
                ventas: Number(f.ventas),
            })),
            por_metodo: porMetodo.map((f) => ({
                metodo_pago: f.metodo_pago,
                total: Number(f.total),
                movimientos: Number(f.movimientos),
            })),
            por_categoria: porCategoria.map((f) => ({
                categoria_id: f.categoria_id,
                nombre: f.nombre,
                unidades: Number(f.unidades),
                ventas: Number(f.ventas),
            })),
        });
    }
    async productos(sucursalId, periodo, filtros = {}, anterior) {
        const { desde, hasta } = periodo;
        const { params, suc, fecha, extra } = this.inicio(sucursalId, desde, hasta, filtros, 'p');
        const extraItems = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(params, filtros);
        const baseJoin = `
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       JOIN productos pr ON pr.id = pi.producto_id
       WHERE p.sucursal_id = ${suc}
         AND ${fecha}${extra}${extraItems}`;
        const mapRanking = (filas) => filas.map((f) => ({
            producto_id: f.producto_id,
            nombre: f.nombre,
            cantidad: Number(f.cantidad),
            ventas: Number(f.ventas),
            margen: Number(f.margen),
        }));
        const porCantidad = await this.database.consultar(`SELECT pr.id AS producto_id,
              pr.nombre,
              COALESCE(SUM(pi.cantidad), 0)::text AS cantidad,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)::text AS ventas,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM} - pi.cantidad * COALESCE(pi.costo_unitario, 0)), 0)::text AS margen
       ${baseJoin}
       GROUP BY pr.id, pr.nombre
       ORDER BY cantidad DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, params.list);
        const porIngresos = await this.database.consultar(`SELECT pr.id AS producto_id,
              pr.nombre,
              COALESCE(SUM(pi.cantidad), 0)::text AS cantidad,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)::text AS ventas,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM} - pi.cantidad * COALESCE(pi.costo_unitario, 0)), 0)::text AS margen
       ${baseJoin}
       GROUP BY pr.id, pr.nombre
       ORDER BY ventas DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, params.list);
        const porMargen = await this.database.consultar(`SELECT pr.id AS producto_id,
              pr.nombre,
              COALESCE(SUM(pi.cantidad), 0)::text AS cantidad,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)::text AS ventas,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM} - pi.cantidad * COALESCE(pi.costo_unitario, 0)), 0)::text AS margen
       ${baseJoin}
       GROUP BY pr.id, pr.nombre
       HAVING SUM(pi.cantidad) > 0
       ORDER BY margen DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, params.list);
        const sinRotacion = await this.database.consultar(`SELECT pr.id AS producto_id, pr.nombre
       FROM productos pr
       WHERE pr.sucursal_id = ${suc}
         AND pr.disponible = true
         AND NOT EXISTS (
           SELECT 1
           FROM pedido_items pi
           JOIN pedidos p ON p.id = pi.pedido_id
           WHERE pi.producto_id = pr.id
             AND p.sucursal_id = ${suc}
             AND ${fecha}${extra}${extraItems}
         )
       ORDER BY pr.nombre ASC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, params.list);
        return this.adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, {
            periodo,
            sucursal_id: sucursalId,
            por_cantidad: mapRanking(porCantidad),
            por_ingresos: mapRanking(porIngresos),
            por_margen: mapRanking(porMargen),
            sin_rotacion: sinRotacion.map((f) => ({
                producto_id: f.producto_id,
                nombre: f.nombre,
            })),
        });
    }
    async cocinas(sucursalId, periodo, filtros = {}, anterior) {
        const { desde, hasta } = periodo;
        const { params, suc, fecha, extra } = this.inicio(sucursalId, desde, hasta, filtros, 'p');
        const extraItems = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(params, filtros);
        const resumen = await this.database.consultar(`WITH items_cocina AS (
         SELECT ${analitica_sql_const_1.ANALITICA_COCINA_ITEM} AS cocina_id,
                SUM(pi.cantidad) AS unidades,
                SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}) AS ingresos,
                SUM(pi.cantidad * COALESCE(pi.costo_unitario, 0)) AS costo
         FROM pedido_items pi
         JOIN pedidos p ON p.id = pi.pedido_id
         JOIN productos pr ON pr.id = pi.producto_id
         WHERE p.sucursal_id = ${suc}
           AND ${fecha}${extra}${extraItems}
         GROUP BY ${analitica_sql_const_1.ANALITICA_COCINA_ITEM}
       )
       SELECT c.id AS cocina_id,
              c.nombre,
              COALESCE(ic.unidades, 0)::text AS unidades,
              COALESCE(ic.ingresos, 0)::text AS ingresos,
              COALESCE(ic.costo, 0)::text AS costo
       FROM cocinas c
       LEFT JOIN items_cocina ic ON ic.cocina_id = c.id
       WHERE c.sucursal_id = ${suc} AND c.activa = true
       ORDER BY ingresos DESC`, params.list);
        const tiempos = await this.database.consultar(`SELECT cocina_id,
              COALESCE(AVG(duracion_seg / 60.0), 0)::text AS tiempo_prep_minutos,
              COALESCE(MIN(duracion_seg / 60.0), 0)::text AS tiempo_prep_min,
              COALESCE(MAX(duracion_seg / 60.0), 0)::text AS tiempo_prep_max
       FROM (
         SELECT DISTINCT ON (${analitica_sql_const_1.ANALITICA_COCINA_ITEM}, p.id)
           ${analitica_sql_const_1.ANALITICA_COCINA_ITEM} AS cocina_id,
           p.id AS pedido_id,
           h.duracion_estado_anterior_seg::float AS duracion_seg
         FROM estados_pedido_historial h
         JOIN pedidos p ON p.id = h.pedido_id
         JOIN pedido_items pi ON pi.pedido_id = p.id
         JOIN productos pr ON pr.id = pi.producto_id
         WHERE p.sucursal_id = ${suc}
           AND ${fecha}${extra}${extraItems}
           AND h.estado_anterior = 'en_cocina'
           AND h.estado_nuevo = 'listo'
           AND h.duracion_estado_anterior_seg IS NOT NULL
       ) prep
       GROUP BY cocina_id`, params.list);
        const topProductos = await this.database.consultar(`SELECT cocina_id, producto_id, nombre, unidades, ingresos, rn::text
       FROM (
         SELECT ${analitica_sql_const_1.ANALITICA_COCINA_ITEM} AS cocina_id,
                pr.id AS producto_id,
                pr.nombre,
                SUM(pi.cantidad)::text AS unidades,
                SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM})::text AS ingresos,
                ROW_NUMBER() OVER (
                  PARTITION BY ${analitica_sql_const_1.ANALITICA_COCINA_ITEM}
                  ORDER BY SUM(pi.cantidad) DESC
                ) AS rn
         FROM pedido_items pi
         JOIN pedidos p ON p.id = pi.pedido_id
         JOIN productos pr ON pr.id = pi.producto_id
         WHERE p.sucursal_id = ${suc}
           AND ${fecha}${extra}${extraItems}
         GROUP BY ${analitica_sql_const_1.ANALITICA_COCINA_ITEM}, pr.id, pr.nombre
       ) ranked
       WHERE rn <= 5
       ORDER BY cocina_id, rn`, params.list);
        const tiempoPorCocina = new Map(tiempos.map((t) => [
            t.cocina_id,
            {
                avg: Number(t.tiempo_prep_minutos),
                min: Number(t.tiempo_prep_min),
                max: Number(t.tiempo_prep_max),
            },
        ]));
        const topsPorCocina = new Map();
        for (const row of topProductos) {
            const lista = topsPorCocina.get(row.cocina_id) ?? [];
            lista.push({
                producto_id: row.producto_id,
                nombre: row.nombre,
                unidades: Number(row.unidades),
                ingresos: Number(row.ingresos),
            });
            topsPorCocina.set(row.cocina_id, lista);
        }
        return this.adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, {
            periodo,
            sucursal_id: sucursalId,
            cocinas: resumen.map((c) => {
                const ingresos = Number(c.ingresos);
                const costo = Number(c.costo);
                const margen = ingresos - costo;
                const tiemposC = tiempoPorCocina.get(c.cocina_id);
                return {
                    cocina_id: c.cocina_id,
                    nombre: c.nombre,
                    unidades: Number(c.unidades),
                    ingresos,
                    costo,
                    margen: Math.round(margen * 100) / 100,
                    margen_pct: ingresos > 0 ? Math.round((margen / ingresos) * 1000) / 10 : 0,
                    tiempo_prep_minutos: Math.round((tiemposC?.avg ?? 0) * 10) / 10,
                    tiempo_prep_min: Math.round((tiemposC?.min ?? 0) * 10) / 10,
                    tiempo_prep_max: Math.round((tiemposC?.max ?? 0) * 10) / 10,
                    top_productos: topsPorCocina.get(c.cocina_id) ?? [],
                };
            }),
        });
    }
    async inventario(sucursalId, periodo, filtros = {}, anterior) {
        void filtros;
        const { desde, hasta } = periodo;
        const params = new analitica_filtros_util_1.SqlParams();
        const suc = params.add(sucursalId);
        const d = params.add(desde);
        const h = params.add(hasta);
        const resumen = await this.database.consultarUno(`SELECT
         COALESCE(SUM(ABS(m.cantidad)) FILTER (WHERE m.tipo = 'venta'), 0)::text AS consumo_unidades,
         COALESCE(SUM(ABS(m.cantidad) * i.costo_unitario_actual) FILTER (WHERE m.tipo = 'venta'), 0)::text AS consumo_valor,
         COALESCE(SUM(ABS(m.cantidad) * i.costo_unitario_actual) FILTER (WHERE m.tipo = 'merma'), 0)::text AS merma_valor,
         COALESCE(SUM(m.stock_posterior - m.stock_anterior) FILTER (WHERE m.tipo = 'ajuste'), 0)::text AS ajuste_neto,
         (
           SELECT COALESCE(SUM(ci.diferencia), 0)::text
           FROM conteo_items ci
           JOIN conteos_inventario c ON c.id = ci.conteo_id
           WHERE c.sucursal_id = ${suc}
             AND c.estado = 'cerrado'
             AND c.cerrado_at >= ${d}::timestamptz
             AND c.cerrado_at < (${h}::date + interval '1 day')
         ) AS diferencia_conteo,
         (
           SELECT COALESCE(SUM(stock_actual * costo_unitario_actual), 0)::text
           FROM ingredientes
           WHERE sucursal_id = ${suc} AND activo = true
         ) AS valor_inventario_actual
       FROM movimientos_ingrediente m
       JOIN ingredientes i ON i.id = m.ingrediente_id
       WHERE m.sucursal_id = ${suc}
         AND m.created_at >= ${d}::timestamptz
         AND m.created_at < (${h}::date + interval '1 day')`, params.list);
        const topConsumo = await this.database.consultar(`SELECT i.id AS ingrediente_id,
              i.nombre,
              COALESCE(SUM(ABS(m.cantidad)), 0)::text AS unidades,
              COALESCE(SUM(ABS(m.cantidad) * i.costo_unitario_actual), 0)::text AS valor
       FROM movimientos_ingrediente m
       JOIN ingredientes i ON i.id = m.ingrediente_id
       WHERE m.sucursal_id = ${suc}
         AND m.tipo = 'venta'
         AND m.created_at >= ${d}::timestamptz
         AND m.created_at < (${h}::date + interval '1 day')
       GROUP BY i.id, i.nombre
       ORDER BY valor DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, params.list);
        const bajoMinimo = await this.database.consultar(`SELECT id AS ingrediente_id, nombre,
              stock_actual::text, stock_minimo::text
       FROM ingredientes
       WHERE sucursal_id = $1
         AND activo = true
         AND stock_minimo > 0
         AND stock_actual <= stock_minimo
       ORDER BY (stock_actual / NULLIF(stock_minimo, 0)) ASC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, [sucursalId]);
        return this.adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, {
            periodo,
            sucursal_id: sucursalId,
            fuentes_cogs: {
                consumo_inventario: 'ingredientes.costo_unitario_actual',
                cogs_ventas: 'pedido_items.costo_unitario',
                ledger_margen: 'margenes_venta.costo_al_momento',
                nota: 'consumo_valor/merma_valor ≈ costo actual del insumo. ' +
                    'No comparar 1:1 con COGS de ventas (snapshot al crear/editar ítem).',
            },
            resumen: {
                consumo_unidades: Number(resumen?.consumo_unidades ?? 0),
                consumo_valor: Number(resumen?.consumo_valor ?? 0),
                merma_valor: Number(resumen?.merma_valor ?? 0),
                ajuste_neto: Number(resumen?.ajuste_neto ?? 0),
                diferencia_conteo: Number(resumen?.diferencia_conteo ?? 0),
                valor_inventario_actual: Number(resumen?.valor_inventario_actual ?? 0),
            },
            top_consumo: topConsumo.map((f) => ({
                ingrediente_id: f.ingrediente_id,
                nombre: f.nombre,
                unidades: Number(f.unidades),
                valor: Number(f.valor),
            })),
            bajo_minimo: bajoMinimo.map((f) => ({
                ingrediente_id: f.ingrediente_id,
                nombre: f.nombre,
                stock_actual: Number(f.stock_actual),
                stock_minimo: Number(f.stock_minimo),
            })),
        });
    }
    async domiciliarios(sucursalId, periodo, filtros = {}, anterior) {
        const { desde, hasta } = periodo;
        const params = new analitica_filtros_util_1.SqlParams();
        const suc = params.add(sucursalId);
        const d = params.add(desde);
        const h = params.add(hasta);
        const extra = (0, analitica_filtros_util_1.clausulasPedidos)(params, filtros, {
            alias: 'p',
            excluirCanceladosPorDefecto: !filtros.estados?.length,
        });
        const umbralTardia = alertas_riesgo_service_1.UMBRALES_ALERTA.demoraEntregaMultiplo;
        const ranking = await this.database.consultar(`WITH entregas AS (
         SELECT a.id,
                a.tipo_domiciliario AS tipo,
                COALESCE(a.domiciliario_planta_id::text, a.domiciliario_independiente_id::text) AS repartidor_id,
                COALESCE(u.nombre, di.nombre, 'Repartidor') AS nombre,
                EXTRACT(EPOCH FROM (a.entregado_at - a.asignado_at)) / 60.0 AS minutos,
                COALESCE(p.tiempo_estimado_minutos, 45) AS estimado,
                COALESCE(p.costo_domicilio, 0) AS ingreso_domi,
                a.distancia_km
         FROM asignaciones_domicilio a
         JOIN pedidos p ON p.id = a.pedido_id
         LEFT JOIN domiciliarios_planta dp ON dp.id = a.domiciliario_planta_id
         LEFT JOIN usuarios u ON u.id = dp.usuario_id
         LEFT JOIN domiciliarios_independientes di ON di.id = a.domiciliario_independiente_id
         WHERE a.sucursal_id = ${suc}
           AND a.estado = 'entregado'
           AND a.entregado_at IS NOT NULL
           AND a.entregado_at >= ${d}::timestamptz
           AND a.entregado_at < (${h}::date + interval '1 day')${extra}
       )
       SELECT repartidor_id,
              nombre,
              tipo,
              COUNT(*)::text AS entregas,
              COALESCE(AVG(minutos), 0)::text AS tiempo_promedio_min,
              (COUNT(*) FILTER (WHERE minutos > estimado * ${umbralTardia})::float
                / NULLIF(COUNT(*), 0) * 100)::text AS pct_tardias,
              COALESCE(SUM(ingreso_domi), 0)::text AS ingresos_domicilio,
              COALESCE(AVG(distancia_km) FILTER (WHERE distancia_km IS NOT NULL), 0)::text AS distancia_promedio_km
       FROM entregas
       GROUP BY repartidor_id, nombre, tipo
       ORDER BY entregas DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, params.list);
        const totales = await this.database.consultarUno(`SELECT COUNT(*)::text AS entregas,
              COALESCE(AVG(EXTRACT(EPOCH FROM (a.entregado_at - a.asignado_at)) / 60.0), 0)::text AS tiempo_promedio_min
       FROM asignaciones_domicilio a
       JOIN pedidos p ON p.id = a.pedido_id
       WHERE a.sucursal_id = ${suc}
         AND a.estado = 'entregado'
         AND a.entregado_at >= ${d}::timestamptz
         AND a.entregado_at < (${h}::date + interval '1 day')${extra}`, params.list);
        return this.adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, {
            periodo,
            sucursal_id: sucursalId,
            umbrales: { demora_entrega_multiplo: umbralTardia },
            totales: {
                entregas: Number(totales?.entregas ?? 0),
                tiempo_promedio_min: Math.round(Number(totales?.tiempo_promedio_min ?? 0) * 10) / 10,
            },
            ranking: ranking.map((r) => ({
                repartidor_id: r.repartidor_id,
                nombre: r.nombre,
                tipo: r.tipo,
                entregas: Number(r.entregas),
                tiempo_promedio_min: Math.round(Number(r.tiempo_promedio_min) * 10) / 10,
                pct_tardias: Math.round(Number(r.pct_tardias) * 10) / 10,
                ingresos_domicilio: Number(r.ingresos_domicilio),
                distancia_promedio_km: Math.round(Number(r.distancia_promedio_km) * 100) / 100,
            })),
        });
    }
    async caja(sucursalId, periodo, filtros = {}, anterior) {
        const { desde, hasta } = periodo;
        const ventasPedidos = await this.ventasNetasPeriodo(sucursalId, desde, hasta, filtros);
        const { params, suc, fecha, extra } = this.inicioCaja(sucursalId, desde, hasta, filtros);
        const movimientos = await this.database.consultarUno(`SELECT (COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'venta'), 0)
                - COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'devolucion'), 0)
              )::text AS ventas_caja,
              COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'retiro'), 0)::text AS retiros,
              COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'gasto'), 0)::text AS gastos_mov
       FROM movimientos_caja m
       LEFT JOIN pedidos p ON p.id = m.pedido_id
       WHERE m.sucursal_id = ${suc} AND ${fecha}${extra}`, params.list);
        const paramsGastos = new analitica_filtros_util_1.SqlParams();
        const sucG = paramsGastos.add(sucursalId);
        const dG = paramsGastos.add(desde);
        const hG = paramsGastos.add(hasta);
        const gastosPorCategoria = await this.database.consultar(`SELECT COALESCE(categoria, 'sin_categoria') AS categoria,
              COALESCE(SUM(monto), 0)::text AS total,
              COUNT(*)::text AS cantidad
       FROM gastos
       WHERE sucursal_id = ${sucG}
         AND created_at >= ${dG}::timestamptz
         AND created_at < (${hG}::date + interval '1 day')
       GROUP BY categoria
       ORDER BY total DESC`, paramsGastos.list);
        const cxc = await this.database.consultarUno(`SELECT COALESCE(SUM(monto), 0)::text AS pendiente,
              COUNT(*)::text AS cantidad
       FROM cuentas_por_cobrar
       WHERE sucursal_id = $1 AND estado = 'pendiente'`, [sucursalId]);
        const cierres = await this.database.consultar(`SELECT id AS caja_id,
              COALESCE(diferencia, 0)::text AS diferencia,
              cierre_at::text
       FROM cajas
       WHERE sucursal_id = ${sucG}
         AND estado = 'cerrada'
         AND cierre_at >= ${dG}::timestamptz
         AND cierre_at < (${hG}::date + interval '1 day')
       ORDER BY cierre_at DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, paramsGastos.list);
        const ventasCaja = Number(movimientos?.ventas_caja ?? 0);
        const diferenciaCuadre = ventasPedidos - ventasCaja;
        return this.adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, {
            periodo,
            sucursal_id: sucursalId,
            cuadre: {
                ventas_pedidos: ventasPedidos,
                ventas_movimientos_caja: ventasCaja,
                diferencia: Math.round(diferenciaCuadre * 100) / 100,
                umbral_relevante_cop: alertas_riesgo_service_1.UMBRALES_ALERTA.cuadreCajaCOP,
                descuadre_relevante: Math.abs(diferenciaCuadre) >= alertas_riesgo_service_1.UMBRALES_ALERTA.cuadreCajaCOP,
            },
            retiros_total: Number(movimientos?.retiros ?? 0),
            gastos_total: Number(movimientos?.gastos_mov ?? 0) +
                gastosPorCategoria.reduce((s, g) => s + Number(g.total), 0),
            gastos_por_categoria: gastosPorCategoria.map((g) => ({
                categoria: g.categoria,
                total: Number(g.total),
                cantidad: Number(g.cantidad),
            })),
            cuentas_por_cobrar: {
                pendiente: Number(cxc?.pendiente ?? 0),
                cantidad: Number(cxc?.cantidad ?? 0),
            },
            cierres: cierres.map((c) => ({
                caja_id: c.caja_id,
                diferencia: Number(c.diferencia),
                cierre_at: c.cierre_at,
            })),
        });
    }
    async rentabilidad(sucursalId, periodo, filtros = {}, anterior) {
        const { desde, hasta } = periodo;
        const kpis = await this.kpisPeriodo(sucursalId, desde, hasta, filtros);
        const { params: pMargen, suc: sucM, fecha: fechaM, extra: extraM } = this.inicio(sucursalId, desde, hasta, filtros, 'p');
        const extraItems = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(pMargen, filtros);
        const cogs = await this.database.consultarUno(`SELECT COALESCE(SUM(pi.cantidad * COALESCE(pi.costo_unitario, 0)), 0)::text AS costo_ventas,
              COALESCE(SUM(${sql_venta_linea_item_1.SQL_VENTA_LINEA_ITEM}), 0)::text AS ingreso_lineas
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       LEFT JOIN productos pr ON pr.id = pi.producto_id
       WHERE p.sucursal_id = ${sucM}
         AND ${fechaM}${extraM}${extraItems}`, pMargen.list);
        const gastosCat = await this.database.consultar(`SELECT COALESCE(NULLIF(TRIM(categoria), ''), 'otros') AS categoria,
              COALESCE(SUM(monto), 0)::text AS total,
              COUNT(*)::text AS cantidad
       FROM gastos
       WHERE sucursal_id = $1
         AND fecha >= $2::date
         AND fecha <= $3::date
       GROUP BY 1
       ORDER BY SUM(monto) DESC`, [sucursalId, desde, hasta]);
        const gastosOrigen = await this.database.consultar(`SELECT origen,
              COALESCE(SUM(monto), 0)::text AS total,
              COUNT(*)::text AS cantidad
       FROM gastos
       WHERE sucursal_id = $1
         AND fecha >= $2::date
         AND fecha <= $3::date
       GROUP BY origen
       ORDER BY SUM(monto) DESC`, [sucursalId, desde, hasta]);
        const compras = await this.database.consultarUno(`SELECT COALESCE(SUM(total_compra), 0)::text AS total
       FROM compras_inventario
       WHERE sucursal_id = $1
         AND fecha_compra >= $2::timestamptz
         AND fecha_compra < ($3::date + interval '1 day')`, [sucursalId, desde, hasta]);
        const ventasNetas = kpis.ventas_netas;
        const costoVentas = Number(cogs?.costo_ventas ?? 0);
        const utilidadBruta = Math.round((ventasNetas - costoVentas) * 100) / 100;
        const gastosPorCategoria = gastosCat.map((g) => ({
            categoria: g.categoria,
            total: Number(g.total),
            cantidad: Number(g.cantidad),
        }));
        const totalGastos = gastosPorCategoria.reduce((s, g) => s + g.total, 0);
        const utilidadNeta = Math.round((utilidadBruta - totalGastos) * 100) / 100;
        const margenContribucion = ventasNetas > 0 ? utilidadBruta / ventasNetas : 0;
        const puntoEquilibrio = margenContribucion > 0
            ? Math.round((totalGastos / margenContribucion) * 100) / 100
            : null;
        const margenNetoPct = ventasNetas > 0
            ? Math.round((utilidadNeta / ventasNetas) * 1000) / 10
            : 0;
        let utilidadAnterior = null;
        let deltaUtilidadPct = null;
        if (anterior) {
            const prevKpis = await this.kpisPeriodo(sucursalId, anterior.desde, anterior.hasta, filtros);
            const prevCogs = await this.database.consultarUno(`SELECT COALESCE(SUM(pi.cantidad * COALESCE(pi.costo_unitario, 0)), 0)::text AS costo_ventas
         FROM pedido_items pi
         JOIN pedidos p ON p.id = pi.pedido_id
         WHERE p.sucursal_id = $1
           AND ${ventas_metricas_sql_1.SQL_DIA_LOCAL_P} >= $2::date
           AND ${ventas_metricas_sql_1.SQL_DIA_LOCAL_P} <= $3::date
           AND ${ventas_metricas_sql_1.SQL_PEDIDOS_VALIDOS_P}`, [sucursalId, anterior.desde, anterior.hasta]);
            const prevGastos = await this.database.consultarUno(`SELECT COALESCE(SUM(monto), 0)::text AS total FROM gastos
         WHERE sucursal_id = $1 AND fecha >= $2::date AND fecha <= $3::date`, [sucursalId, anterior.desde, anterior.hasta]);
            const prevUb = prevKpis.ventas_netas - Number(prevCogs?.costo_ventas ?? 0);
            utilidadAnterior =
                Math.round((prevUb - Number(prevGastos?.total ?? 0)) * 100) / 100;
            deltaUtilidadPct =
                utilidadAnterior === 0
                    ? utilidadNeta > 0
                        ? 100
                        : utilidadNeta < 0
                            ? -100
                            : 0
                    : Math.round(((utilidadNeta - utilidadAnterior) /
                        Math.abs(utilidadAnterior)) *
                        1000) / 10;
        }
        const cobertura = kpis.cobertura_costo_pct;
        const consejos = [];
        if (utilidadNeta < 0) {
            consejos.push({
                codigo: 'perdida_periodo',
                nivel: 'alerta',
                mensaje: 'En este periodo vas en pérdida. Revisa gastos o márgenes de platos.',
            });
        }
        else if (margenNetoPct > 0 && margenNetoPct < 10) {
            consejos.push({
                codigo: 'margen_bajo',
                nivel: 'aviso',
                mensaje: 'Margen neto bajo el 10%. Poco colchón ante imprevistos.',
            });
        }
        if (cobertura < 80) {
            consejos.push({
                codigo: 'cobertura_costo',
                nivel: 'aviso',
                mensaje: 'Varias ventas sin costo. Completa recetas en Costos y márgenes.',
            });
        }
        if (ventasNetas > 0 && totalGastos / ventasNetas > 0.4) {
            consejos.push({
                codigo: 'gastos_altos',
                nivel: 'aviso',
                mensaje: 'Gastos > 40% de ventas. Revisa fijos y nómina.',
            });
        }
        if (utilidadNeta > 0 &&
            deltaUtilidadPct != null &&
            deltaUtilidadPct > 0) {
            consejos.push({
                codigo: 'mejor_que_anterior',
                nivel: 'info',
                mensaje: 'Mejor utilidad neta que el periodo comparado.',
            });
        }
        if (consejos.length === 0) {
            consejos.push({
                codigo: 'ok',
                nivel: 'info',
                mensaje: 'Sin alertas fuertes en este periodo.',
            });
        }
        return {
            periodo: { label: periodo.label, desde, hasta },
            ventas_netas: ventasNetas,
            costo_ventas: Math.round(costoVentas * 100) / 100,
            utilidad_bruta: utilidadBruta,
            utilidad_bruta_pct: ventasNetas > 0
                ? Math.round((utilidadBruta / ventasNetas) * 1000) / 10
                : 0,
            gastos_por_categoria: gastosPorCategoria,
            gastos_por_origen: gastosOrigen.map((g) => ({
                origen: g.origen,
                total: Number(g.total),
                cantidad: Number(g.cantidad),
            })),
            total_gastos: Math.round(totalGastos * 100) / 100,
            utilidad_neta: utilidadNeta,
            margen_neto_pct: margenNetoPct,
            es_rentable: utilidadNeta >= 0,
            punto_equilibrio: puntoEquilibrio,
            cobertura_costo_pct: cobertura,
            nota_compras: 'Las compras a proveedores no se restan del P&L (evitar doble conteo con COGS). Se muestran como referencia de salida de caja.',
            fuente_cogs: 'pedido_items.costo_unitario',
            nota_cogs: 'COGS = snapshot al vender/editar ítem. No usa costo_unitario_actual del inventario.',
            compras_periodo: Number(compras?.total ?? 0),
            consejos,
            ...(anterior
                ? {
                    comparativa_utilidad: {
                        anterior: {
                            desde: anterior.desde,
                            hasta: anterior.hasta,
                            utilidad_neta: utilidadAnterior,
                        },
                        delta_utilidad_pct: deltaUtilidadPct,
                    },
                }
                : {}),
        };
    }
    async riesgo(sucursalId, periodo, filtros = {}, anterior) {
        const { desde, hasta } = periodo;
        const paramsFecha = new analitica_filtros_util_1.SqlParams();
        const suc = paramsFecha.add(sucursalId);
        const d = paramsFecha.add(desde);
        const h = paramsFecha.add(hasta);
        const fechaAlertas = `created_at >= ${d}::timestamptz AND created_at < (${h}::date + interval '1 day')`;
        const porNivel = await this.database.consultar(`SELECT nivel,
              COUNT(*)::text AS total,
              COUNT(*) FILTER (WHERE revisada = false)::text AS abiertas
       FROM alertas_riesgo
       WHERE sucursal_id = ${suc}
         AND ${fechaAlertas}
       GROUP BY nivel
       ORDER BY CASE nivel
         WHEN 'critico' THEN 1 WHEN 'alto' THEN 2 WHEN 'medio' THEN 3 ELSE 4 END`, paramsFecha.list);
        const { params: pDesc, suc: sucD, fecha: fechaD, extra: extraD } = this.inicio(sucursalId, desde, hasta, filtros, undefined, {
            excluirCanceladosPorDefecto: false,
        });
        const umbralDesc = pDesc.add(alertas_riesgo_service_1.UMBRALES_ALERTA.descuentoPorcentajeAlto);
        const descuentosAtipicos = await this.database.consultar(`SELECT id AS pedido_id,
              numero_pedido,
              ROUND((descuento / NULLIF(subtotal, 0) * 100)::numeric, 1)::text AS pct_descuento,
              descuento::text,
              created_at::text
       FROM pedidos
       WHERE sucursal_id = ${sucD}
         AND ${fechaD}${extraD}
         AND subtotal > 0
         AND descuento > 0
         AND (descuento / subtotal * 100) > ${umbralDesc}
       ORDER BY descuento DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, pDesc.list);
        const cancelacionesUsuario = await this.database.consultar(`SELECT h.usuario_id::text,
              COALESCE(u.nombre, 'Sistema') AS nombre,
              COUNT(*)::text AS cancelaciones
       FROM estados_pedido_historial h
       JOIN pedidos p ON p.id = h.pedido_id
       LEFT JOIN usuarios u ON u.id = h.usuario_id
       WHERE p.sucursal_id = ${suc}
         AND h.estado_nuevo IN ('cancelado', 'rechazado')
         AND h.fecha >= ${d}::timestamptz
         AND h.fecha < (${h}::date + interval '1 day')
       GROUP BY h.usuario_id, u.nombre
       HAVING COUNT(*) >= 1
       ORDER BY cancelaciones DESC
       LIMIT ${analitica_sql_const_1.ANALITICA_LIMITE_RANKING}`, paramsFecha.list);
        const transferencias = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM transferencias_mesa t
       JOIN pedidos p ON p.id = t.pedido_id
       WHERE p.sucursal_id = ${suc}
         AND t.created_at >= ${d}::timestamptz
         AND t.created_at < (${h}::date + interval '1 day')`, paramsFecha.list);
        const alertasSalioSinPagar = await this.database.consultarUno(`SELECT COUNT(*)::text AS total
       FROM alertas_riesgo
       WHERE sucursal_id = ${suc}
         AND tipo = 'salio_sin_pagar'
         AND ${fechaAlertas}`, paramsFecha.list);
        const auditoriaReciente = await this.database.consultar(`SELECT accion, COUNT(*)::text AS total
       FROM auditoria_logs
       WHERE sucursal_id = ${suc}
         AND ${fechaAlertas}
       GROUP BY accion
       ORDER BY total DESC
       LIMIT 15`, paramsFecha.list);
        const { params: pCancelPost, suc: sucCp, fecha: fechaCp, extra: extraCp } = this.inicio(sucursalId, desde, hasta, filtros, 'p', {
            excluirCanceladosPorDefecto: false,
        });
        const extraItemsCp = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(pCancelPost, filtros);
        const estadosPostSql = ESTADOS_POST_COCINA.map((e) => `'${e}'`).join(', ');
        const productosCanceladosPostCocina = await this.database.consultar(`SELECT pr.id AS producto_id,
              pr.nombre,
              COALESCE(SUM(pi.cantidad), 0)::text AS cantidad
       FROM pedido_items pi
       JOIN pedidos p ON p.id = pi.pedido_id
       JOIN productos pr ON pr.id = pi.producto_id
       WHERE p.sucursal_id = ${sucCp}
         AND ${fechaCp}${extraCp}${extraItemsCp}
         AND p.estado IN ('cancelado', 'rechazado')
         AND EXISTS (
           SELECT 1 FROM estados_pedido_historial h
           WHERE h.pedido_id = p.id
             AND (
               h.estado_anterior IN (${estadosPostSql})
               OR h.estado_nuevo IN (${estadosPostSql})
             )
         )
       GROUP BY pr.id, pr.nombre
       ORDER BY cantidad DESC
       LIMIT 5`, pCancelPost.list);
        const cancelacionesSospechosas = cancelacionesUsuario.filter((c) => Number(c.cancelaciones) >= alertas_riesgo_service_1.UMBRALES_ALERTA.cancelacionesPorDia);
        const [cocinasPrepDelta, categoriasCaida] = anterior
            ? await Promise.all([
                this.cocinasPrepDelta(sucursalId, periodo, anterior, filtros),
                this.categoriasCaida(sucursalId, periodo, anterior, filtros),
            ])
            : [[], []];
        return this.adjuntarComparativaKpis(sucursalId, periodo, anterior, filtros, {
            periodo,
            sucursal_id: sucursalId,
            umbrales: alertas_riesgo_service_1.UMBRALES_ALERTA,
            alertas_por_nivel: porNivel.map((a) => ({
                nivel: a.nivel,
                total: Number(a.total),
                abiertas: Number(a.abiertas),
            })),
            descuentos_atipicos: descuentosAtipicos.map((d) => ({
                pedido_id: d.pedido_id,
                numero_pedido: d.numero_pedido,
                pct_descuento: Number(d.pct_descuento),
                descuento: Number(d.descuento),
                created_at: d.created_at,
            })),
            cancelaciones_por_usuario: cancelacionesUsuario.map((c) => ({
                usuario_id: c.usuario_id,
                nombre: c.nombre,
                cancelaciones: Number(c.cancelaciones),
                supera_umbral_diario: Number(c.cancelaciones) >= alertas_riesgo_service_1.UMBRALES_ALERTA.cancelacionesPorDia,
            })),
            productos_cancelados_post_cocina_aprox: productosCanceladosPostCocina.map((p) => ({
                producto_id: p.producto_id,
                nombre: p.nombre,
                cantidad: Number(p.cantidad),
            })),
            cocinas_prep_delta: cocinasPrepDelta,
            categorias_caida: categoriasCaida,
            senales: {
                transferencias_mesa: Number(transferencias?.total ?? 0),
                transferencias_umbral: alertas_riesgo_service_1.UMBRALES_ALERTA.transferenciasMesa,
                salio_sin_pagar: Number(alertasSalioSinPagar?.total ?? 0),
                usuarios_cancelacion_alerta: cancelacionesSospechosas.length,
                cocinas_prep_alerta: cocinasPrepDelta.filter((c) => c.alerta_subida).length,
                categorias_caida_alerta: categoriasCaida.length,
            },
            auditoria_por_accion: auditoriaReciente.map((a) => ({
                accion: a.accion,
                total: Number(a.total),
            })),
        });
    }
    async pedidosRecientes(sucursalId, periodo, filtros = {}, limite = 15) {
        const { desde, hasta } = periodo;
        const { params, suc, fecha, extra } = this.inicio(sucursalId, desde, hasta, filtros, 'p', { excluirCanceladosPorDefecto: false });
        const lim = params.add(limite);
        const filas = await this.database.consultar(`SELECT p.id::text,
              p.numero_pedido::text,
              p.tipo,
              m.nombre AS mesa_nombre,
              p.cliente_nombre,
              COALESCE(p.total, 0)::text AS total,
              p.estado,
              p.created_at::text
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       WHERE p.sucursal_id = ${suc}
         AND ${fecha}${extra}
       ORDER BY p.created_at DESC
       LIMIT ${lim}`, params.list);
        return {
            periodo,
            sucursal_id: sucursalId,
            pedidos: filas.map((f) => ({
                id: f.id,
                numero_pedido: f.numero_pedido,
                tipo: f.tipo,
                mesa_nombre: f.mesa_nombre,
                cliente_nombre: f.cliente_nombre,
                total: Number(f.total),
                estado: f.estado,
                created_at: f.created_at,
            })),
        };
    }
    async cocinasPrepDelta(sucursalId, periodo, anterior, filtros) {
        const avgPrep = async (desde, hasta) => {
            const { params, suc, fecha, extra } = this.inicio(sucursalId, desde, hasta, filtros, 'p');
            const extraItems = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(params, filtros);
            return this.database.consultar(`SELECT cocina_id,
                COALESCE(c.nombre, 'Cocina') AS nombre,
                COALESCE(AVG(duracion_seg / 60.0), 0)::text AS minutos,
                COUNT(*)::text AS muestras
         FROM (
           SELECT DISTINCT ON (${analitica_sql_const_1.ANALITICA_COCINA_ITEM}, p.id)
             ${analitica_sql_const_1.ANALITICA_COCINA_ITEM} AS cocina_id,
             p.id AS pedido_id,
             h.duracion_estado_anterior_seg::float AS duracion_seg
           FROM estados_pedido_historial h
           JOIN pedidos p ON p.id = h.pedido_id
           JOIN pedido_items pi ON pi.pedido_id = p.id
           JOIN productos pr ON pr.id = pi.producto_id
           WHERE p.sucursal_id = ${suc}
             AND ${fecha}${extra}${extraItems}
             AND h.estado_anterior = 'en_cocina'
             AND h.estado_nuevo = 'listo'
             AND h.duracion_estado_anterior_seg IS NOT NULL
         ) prep
         LEFT JOIN cocinas c ON c.id = prep.cocina_id
         GROUP BY cocina_id, c.nombre`, params.list);
        };
        const [actual, prev] = await Promise.all([
            avgPrep(periodo.desde, periodo.hasta),
            avgPrep(anterior.desde, anterior.hasta),
        ]);
        const prevMap = new Map(prev.map((r) => [r.cocina_id, r]));
        const umbral = alertas_riesgo_service_1.UMBRALES_ALERTA.prepCocinaSubidaPct;
        const minM = alertas_riesgo_service_1.UMBRALES_ALERTA.prepCocinaMuestrasMin;
        return actual
            .map((a) => {
            const p = prevMap.get(a.cocina_id);
            const minActual = Number(a.minutos);
            const minAnterior = Number(p?.minutos ?? 0);
            const nActual = Number(a.muestras);
            const nAnterior = Number(p?.muestras ?? 0);
            const deltaPct = minAnterior === 0
                ? minActual > 0
                    ? 100
                    : 0
                : Math.round(((minActual - minAnterior) / minAnterior) * 1000) / 10;
            return {
                cocina_id: a.cocina_id,
                nombre: a.nombre,
                minutos_actual: Math.round(minActual * 10) / 10,
                minutos_anterior: Math.round(minAnterior * 10) / 10,
                muestras_actual: nActual,
                muestras_anterior: nAnterior,
                delta_pct: deltaPct,
                alerta_subida: nActual >= minM &&
                    nAnterior >= minM &&
                    minAnterior > 0 &&
                    deltaPct >= umbral,
            };
        })
            .filter((r) => r.muestras_actual > 0 || r.muestras_anterior > 0)
            .sort((x, y) => y.delta_pct - x.delta_pct);
    }
    async categoriasCaida(sucursalId, periodo, anterior, filtros) {
        const ventasCat = async (desde, hasta) => {
            const { params, suc, fecha, extra } = this.inicio(sucursalId, desde, hasta, filtros, 'p');
            const extraItems = (0, analitica_filtros_util_1.clausulasItemsYaJoineados)(params, filtros);
            return this.database.consultar(`SELECT cat.id AS categoria_id,
                cat.nombre,
                COALESCE(SUM(pi.cantidad), 0)::text AS unidades
         FROM pedido_items pi
         JOIN pedidos p ON p.id = pi.pedido_id
         JOIN productos pr ON pr.id = pi.producto_id
         JOIN categorias cat ON cat.id = pr.categoria_id
         WHERE p.sucursal_id = ${suc}
           AND ${fecha}${extra}${extraItems}
           AND pr.categoria_id IS NOT NULL
         GROUP BY cat.id, cat.nombre`, params.list);
        };
        const [actual, prev] = await Promise.all([
            ventasCat(periodo.desde, periodo.hasta),
            ventasCat(anterior.desde, anterior.hasta),
        ]);
        const actualMap = new Map(actual.map((r) => [r.categoria_id, r]));
        const umbral = alertas_riesgo_service_1.UMBRALES_ALERTA.caidaVentasPct;
        return prev
            .map((p) => {
            const a = actualMap.get(p.categoria_id);
            const uAnt = Number(p.unidades);
            const uAct = Number(a?.unidades ?? 0);
            if (uAnt < 5)
                return null;
            const deltaPct = uAnt === 0
                ? 0
                : Math.round(((uAct - uAnt) / uAnt) * 1000) / 10;
            if (deltaPct > -umbral)
                return null;
            return {
                categoria_id: p.categoria_id,
                nombre: p.nombre,
                unidades_actual: uAct,
                unidades_anterior: uAnt,
                delta_pct: deltaPct,
            };
        })
            .filter((r) => r != null)
            .sort((x, y) => x.delta_pct - y.delta_pct)
            .slice(0, 10);
    }
    csvEscape(val) {
        const s = String(val ?? '');
        if (/[",\n\r]/.test(s))
            return `"${s.replace(/"/g, '""')}"`;
        return s;
    }
    csvRow(cols) {
        return cols.map((c) => this.csvEscape(c)).join(',');
    }
    async exportarCsv(sucursalId, periodo, anterior, filtros = {}) {
        const [resumenData, ventasData, productosData, cajaData] = await Promise.all([
            this.resumen(sucursalId, periodo, anterior, filtros),
            this.ventas(sucursalId, periodo, filtros, anterior),
            this.productos(sucursalId, periodo, filtros, anterior),
            this.caja(sucursalId, periodo, filtros, anterior),
        ]);
        const filas = [];
        const bloque = (titulo, rows) => {
            filas.push(this.csvRow([`# ${titulo}`]));
            for (const row of rows)
                filas.push(this.csvRow(row));
            filas.push('');
        };
        filas.push(this.csvRow(['Foody - Analítica']));
        filas.push(this.csvRow(['Periodo', periodo.label, periodo.desde, periodo.hasta]));
        filas.push('');
        const kpis = resumenData.kpis;
        bloque('Resumen', [
            ['metrica', 'valor'],
            ['ventas_netas', kpis.ventas_netas],
            ['pedidos', kpis.pedidos],
            ['ticket_promedio', kpis.ticket_promedio],
            ['margen_bruto_estimado', kpis.margen_bruto_estimado],
            ['margen_bruto_pct', kpis.margen_bruto_pct],
            ['pct_cancelacion', kpis.pct_cancelacion],
            ['alertas_abiertas', kpis.alertas_abiertas],
        ]);
        const comp = resumenData.comparativa;
        if (comp) {
            const ant = comp.anterior;
            const delta = comp.delta;
            bloque('Comparativa', [
                ['desde', 'hasta', 'ventas_anterior', 'delta_ventas_pct', 'delta_pedidos_pct', 'tendencia'],
                [
                    ant.desde,
                    ant.hasta,
                    ant.ventas_netas,
                    delta.ventas_netas_pct,
                    delta.pedidos_pct ?? '',
                    delta.tendencia,
                ],
            ]);
        }
        const porTipo = ventasData.por_tipo;
        if (porTipo.length) {
            bloque('Por tipo', [
                ['tipo', 'pedidos', 'ventas'],
                ...porTipo.map((t) => [t.tipo, t.pedidos, t.ventas]),
            ]);
        }
        const porMetodo = ventasData.por_metodo;
        if (porMetodo.length) {
            bloque('Por metodo de pago', [
                ['metodo_pago', 'total', 'movimientos'],
                ...porMetodo.map((m) => [m.metodo_pago, m.total, m.movimientos]),
            ]);
        }
        const porCantidad = productosData.por_cantidad;
        if (porCantidad.length) {
            bloque('Productos cantidad', [
                ['producto', 'cantidad', 'ventas', 'margen'],
                ...porCantidad.map((p) => [p.nombre, p.cantidad, p.ventas, p.margen]),
            ]);
        }
        const cuadre = cajaData.cuadre;
        bloque('Caja', [
            ['metrica', 'valor'],
            ['ventas_pedidos', cuadre.ventas_pedidos],
            ['ventas_movimientos_caja', cuadre.ventas_movimientos_caja],
            ['diferencia', cuadre.diferencia],
            ['retiros_total', cajaData.retiros_total],
            ['gastos_total', cajaData.gastos_total],
        ]);
        const csv = filas.join('\r\n');
        const buffer = Buffer.concat([
            Buffer.from([0xef, 0xbb, 0xbf]),
            Buffer.from(csv, 'utf8'),
        ]);
        const slug = periodo.desde === periodo.hasta
            ? periodo.desde
            : `${periodo.desde}_${periodo.hasta}`;
        return {
            filename: `foody-analitica-${slug}.csv`,
            buffer,
            mime: 'text/csv; charset=utf-8',
        };
    }
    async comparativaSedes(restauranteId, periodo) {
        const sucursales = await this.database.consultar(`SELECT id, nombre
       FROM sucursales
       WHERE restaurante_id = $1 AND activa = true
       ORDER BY nombre ASC`, [restauranteId]);
        const sedes = [];
        for (const s of sucursales) {
            const kpis = await this.kpisPeriodo(s.id, periodo.desde, periodo.hasta, {});
            sedes.push({
                sucursal_id: s.id,
                nombre: s.nombre,
                kpis,
            });
        }
        const totales = sedes.reduce((acc, s) => ({
            ventas_netas: acc.ventas_netas + s.kpis.ventas_netas,
            pedidos: acc.pedidos + s.kpis.pedidos,
            alertas_abiertas: acc.alertas_abiertas + s.kpis.alertas_abiertas,
        }), { ventas_netas: 0, pedidos: 0, alertas_abiertas: 0 });
        return {
            periodo,
            restaurante_id: restauranteId,
            sucursales_activas: sedes.length,
            totales,
            sedes,
        };
    }
};
exports.AnaliticaService = AnaliticaService;
exports.AnaliticaService = AnaliticaService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        sucursal_scope_service_1.SucursalScopeService])
], AnaliticaService);
//# sourceMappingURL=analitica.service.js.map