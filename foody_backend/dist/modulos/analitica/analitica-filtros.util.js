"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SqlParams = exports.ANALITICA_CLIENTE_FRECUENTE_MIN = void 0;
exports.parseFiltrosDesdeDto = parseFiltrosDesdeDto;
exports.filtrosActivos = filtrosActivos;
exports.filtrosSumanPorLinea = filtrosSumanPorLinea;
exports.clausulasPedidos = clausulasPedidos;
exports.clausulasItemsYaJoineados = clausulasItemsYaJoineados;
const ventas_metricas_sql_1 = require("../../compartido/sql/ventas-metricas.sql");
exports.ANALITICA_CLIENTE_FRECUENTE_MIN = 3;
const ESTADOS_FUERA_VENTA_NETA = new Set(['cancelado', 'rechazado']);
function parseFiltrosDesdeDto(dto) {
    const bool = (v) => v === 'true' || v === '1';
    const filtros = {};
    if (dto.mesera_ids?.length)
        filtros.meseraIds = dto.mesera_ids;
    if (dto.cocina_ids?.length)
        filtros.cocinaIds = dto.cocina_ids;
    if (dto.producto_ids?.length)
        filtros.productoIds = dto.producto_ids;
    if (dto.categoria_ids?.length)
        filtros.categoriaIds = dto.categoria_ids;
    if (dto.estados?.length) {
        const incluirCancelados = bool(dto.incluir_cancelados);
        const limpios = incluirCancelados
            ? dto.estados
            : dto.estados.filter((e) => !ESTADOS_FUERA_VENTA_NETA.has(e));
        if (limpios.length)
            filtros.estados = limpios;
        else if (!incluirCancelados)
            filtros.sinEstadosOperativos = true;
    }
    if (dto.item_estados_cocina?.length) {
        filtros.itemEstadosCocina = dto.item_estados_cocina;
    }
    if (dto.hora_desde != null)
        filtros.horaDesde = dto.hora_desde;
    if (dto.hora_hasta != null)
        filtros.horaHasta = dto.hora_hasta;
    if (bool(dto.solo_pendiente_pago))
        filtros.soloPendientePago = true;
    if (bool(dto.solo_facturados))
        filtros.soloFacturados = true;
    if (dto.metodos_pago?.length)
        filtros.metodosPago = dto.metodos_pago;
    if (dto.cajero_ids?.length)
        filtros.cajeroIds = dto.cajero_ids;
    if (dto.caja_ids?.length)
        filtros.cajaIds = dto.caja_ids;
    if (dto.cliente_telefono?.trim()) {
        filtros.clienteTelefono = dto.cliente_telefono.trim();
    }
    if (dto.device_id?.trim())
        filtros.deviceId = dto.device_id.trim();
    if (dto.cliente_segmento === 'frecuente' || dto.cliente_segmento === 'nuevo') {
        filtros.clienteSegmento = dto.cliente_segmento;
    }
    if (dto.domiciliario_ids?.length) {
        filtros.domiciliarioIds = dto.domiciliario_ids;
    }
    return filtros;
}
function filtrosActivos(f) {
    return Object.keys(f).length > 0;
}
function filtrosSumanPorLinea(f) {
    return Boolean(f.productoIds?.length ||
        f.categoriaIds?.length ||
        f.cocinaIds?.length ||
        f.itemEstadosCocina?.length);
}
class SqlParams {
    list = [];
    add(value) {
        this.list.push(value);
        return `$${this.list.length}`;
    }
}
exports.SqlParams = SqlParams;
function clausulasPedidos(params, filtros, opts = {}) {
    const pref = opts.alias && opts.alias.length > 0 ? `${opts.alias}.` : 'pedidos.';
    const parts = [];
    const frecuenteMin = opts.frecuenteMin ?? exports.ANALITICA_CLIENTE_FRECUENTE_MIN;
    if (filtros.sinEstadosOperativos) {
        parts.push('FALSE');
    }
    else if (filtros.estados?.length) {
        const p = params.add(filtros.estados);
        parts.push(`${pref}estado = ANY(${p}::text[])`);
    }
    else if (opts.excluirCanceladosPorDefecto !== false) {
        parts.push((0, ventas_metricas_sql_1.sqlPedidosValidos)(pref));
    }
    if (filtros.soloPendientePago) {
        parts.push(`${pref}estado NOT IN ('cancelado', 'rechazado', 'pagado')`, `COALESCE(${pref}monto_pagado, 0) < ${pref}total - 0.01`);
    }
    if (filtros.meseraIds?.length) {
        const p = params.add(filtros.meseraIds);
        parts.push(`${pref}mesera_id = ANY(${p}::uuid[])`);
    }
    if (filtros.cajeroIds?.length) {
        const p = params.add(filtros.cajeroIds);
        parts.push(`${pref}cajero_id = ANY(${p}::uuid[])`);
    }
    if (filtros.metodosPago?.length) {
        const p = params.add(filtros.metodosPago);
        parts.push(`${pref}metodo_pago = ANY(${p}::text[])`);
    }
    if (filtros.horaDesde != null || filtros.horaHasta != null) {
        const h0 = filtros.horaDesde ?? 0;
        const h1 = filtros.horaHasta ?? 23;
        const p0 = params.add(h0);
        const p1 = params.add(h1);
        parts.push(`EXTRACT(HOUR FROM ${pref}created_at AT TIME ZONE '${ventas_metricas_sql_1.SQL_TZ_NEGOCIO}')::int BETWEEN ${p0} AND ${p1}`);
    }
    if (filtros.clienteTelefono) {
        const p = params.add(filtros.clienteTelefono);
        parts.push(`${pref}cliente_telefono = ${p}`);
    }
    if (filtros.deviceId) {
        const p = params.add(filtros.deviceId);
        parts.push(`${pref}device_id = ${p}`);
    }
    if (filtros.soloFacturados) {
        parts.push(`EXISTS (SELECT 1 FROM facturas f WHERE f.pedido_id = ${pref}id AND f.estado IS DISTINCT FROM 'anulada')`);
    }
    if (filtros.cajaIds?.length) {
        const p = params.add(filtros.cajaIds);
        parts.push(`EXISTS (
         SELECT 1 FROM movimientos_caja mc
         WHERE mc.pedido_id = ${pref}id AND mc.caja_id = ANY(${p}::uuid[])
       )`);
    }
    if (filtros.domiciliarioIds?.length) {
        const p = params.add(filtros.domiciliarioIds);
        parts.push(`EXISTS (
         SELECT 1 FROM asignaciones_domicilio ad
         WHERE ad.pedido_id = ${pref}id
           AND (
             ad.domiciliario_planta_id = ANY(${p}::uuid[])
             OR ad.domiciliario_independiente_id = ANY(${p}::uuid[])
           )
       )`);
    }
    const needsItems = (filtros.cocinaIds?.length ?? 0) > 0 ||
        (filtros.productoIds?.length ?? 0) > 0 ||
        (filtros.categoriaIds?.length ?? 0) > 0 ||
        (filtros.itemEstadosCocina?.length ?? 0) > 0;
    if (needsItems) {
        const sub = [`pi.pedido_id = ${pref}id`];
        if (filtros.cocinaIds?.length) {
            const p = params.add(filtros.cocinaIds);
            sub.push(`COALESCE(pi.cocina_id, pr.cocina_id) = ANY(${p}::uuid[])`);
        }
        if (filtros.productoIds?.length) {
            const p = params.add(filtros.productoIds);
            sub.push(`pi.producto_id = ANY(${p}::uuid[])`);
        }
        if (filtros.categoriaIds?.length) {
            const p = params.add(filtros.categoriaIds);
            sub.push(`pr.categoria_id = ANY(${p}::uuid[])`);
        }
        if (filtros.itemEstadosCocina?.length) {
            const p = params.add(filtros.itemEstadosCocina);
            sub.push(`pi.estado_cocina = ANY(${p}::text[])`);
        }
        parts.push(`EXISTS (
         SELECT 1 FROM pedido_items pi
         JOIN productos pr ON pr.id = pi.producto_id
         WHERE ${sub.join(' AND ')}
       )`);
    }
    if (filtros.clienteSegmento === 'frecuente' || filtros.clienteSegmento === 'nuevo') {
        const pMin = params.add(frecuenteMin);
        const clave = `COALESCE(NULLIF(TRIM(${pref}cliente_telefono), ''), ${pref}device_id)`;
        const conteo = `(
      SELECT COUNT(*)::int
      FROM pedidos px
      WHERE px.sucursal_id = ${pref}sucursal_id
        AND px.estado NOT IN ('cancelado', 'rechazado')
        AND px.created_at >= now() - interval '90 days'
        AND COALESCE(NULLIF(TRIM(px.cliente_telefono), ''), px.device_id)
            = ${clave}
    )`;
        if (filtros.clienteSegmento === 'frecuente') {
            parts.push(`${clave} IS NOT NULL`);
            parts.push(`${conteo} >= ${pMin}`);
        }
        else {
            parts.push(`(${clave} IS NULL OR ${conteo} < ${pMin})`);
        }
    }
    return parts.length ? ` AND ${parts.join(' AND ')}` : '';
}
function clausulasItemsYaJoineados(params, filtros) {
    const parts = [];
    if (filtros.cocinaIds?.length) {
        const p = params.add(filtros.cocinaIds);
        parts.push(`COALESCE(pi.cocina_id, pr.cocina_id) = ANY(${p}::uuid[])`);
    }
    if (filtros.productoIds?.length) {
        const p = params.add(filtros.productoIds);
        parts.push(`pi.producto_id = ANY(${p}::uuid[])`);
    }
    if (filtros.categoriaIds?.length) {
        const p = params.add(filtros.categoriaIds);
        parts.push(`pr.categoria_id = ANY(${p}::uuid[])`);
    }
    if (filtros.itemEstadosCocina?.length) {
        const p = params.add(filtros.itemEstadosCocina);
        parts.push(`pi.estado_cocina = ANY(${p}::text[])`);
    }
    return parts.length ? ` AND ${parts.join(' AND ')}` : '';
}
//# sourceMappingURL=analitica-filtros.util.js.map