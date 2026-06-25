import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { ActualizarSubrecetaDto } from './dto/actualizar-subreceta.dto';
import { CrearSubrecetaDto, SubrecetaItemDto } from './dto/crear-subreceta.dto';
import {
  convertirCantidad,
  exigirUnidadesCompatibles,
} from './unidad-costeo.util';

export interface DesgloseCostoReceta {
  receta_id: string;
  costo_ingredientes: number;
  costo_subrecetas: number;
  costo_empaques: number;
  costo_merma: number;
  costo_base: number;
  costo_domicilio: number;
  costo_por_porcion: number;
}

export interface IngredienteExpandido {
  ingrediente_id: string;
  cantidad: number;
}

@Injectable()
export class CosteoService {
  constructor(
    private readonly database: DatabaseService,
    private readonly alertasRiesgo: AlertasRiesgoService,
  ) {}

  /** costo_real = costo_unitario × (100 / rendimiento_porcentaje) */
  costoRealUnitario(costoUnitario: number, rendimientoPorcentaje: number): number {
    const rend = rendimientoPorcentaje > 0 ? rendimientoPorcentaje : 100;
    return costoUnitario * (100 / rend);
  }

  async calcularReceta(
    client: PoolClient,
    recetaId: string,
    sucursalId: string,
    visitados: Set<string> = new Set(),
  ): Promise<DesgloseCostoReceta> {
    if (visitados.has(recetaId)) {
      throw new BadRequestException('RECETA_CIRCULAR');
    }
    visitados.add(recetaId);

    const receta = await this.consultarReceta(client, recetaId, sucursalId);
    const items = await client.query<{
      tipo_item: string;
      ingrediente_id: string | null;
      subreceta_id: string | null;
      cantidad: string;
      unidad: string;
    }>(
      `SELECT tipo_item, ingrediente_id, subreceta_id,
              cantidad::float AS cantidad, unidad
       FROM receta_items WHERE receta_id = $1 ORDER BY orden, id`,
      [recetaId],
    );

    let costoIngredientes = 0;
    let costoSubrecetas = 0;
    let costoEmpaques = 0;
    let costoMerma = 0;
    const margenError = Number(receta.margen_error ?? 0.05);

    for (const item of items.rows) {
      const cantidad = Number(item.cantidad);
      if (item.tipo_item === 'ingrediente' && item.ingrediente_id) {
        const { costoReal, mermaExtra } = await this.costoLineaIngrediente(
          client,
          item.ingrediente_id,
          sucursalId,
          cantidad,
          item.unidad,
        );
        costoIngredientes += costoReal;
        costoMerma += mermaExtra;
      } else if (item.tipo_item === 'subreceta' && item.subreceta_id) {
        const cantidadEfectiva = await this.cantidadEnUnidadSubreceta(
          client,
          item.subreceta_id,
          sucursalId,
          cantidad,
          item.unidad,
        );
        const unit = await this.costoUnitarioSubreceta(
          client,
          item.subreceta_id,
          sucursalId,
          visitados,
        );
        costoSubrecetas += cantidadEfectiva * unit;
      } else if (item.tipo_item === 'empaque' && item.ingrediente_id) {
        const { costoReal } = await this.costoLineaIngrediente(
          client,
          item.ingrediente_id,
          sucursalId,
          cantidad,
          item.unidad,
        );
        costoEmpaques += costoReal;
      }
    }

    const sumaBase = costoIngredientes + costoSubrecetas;

    if (receta.tipo === 'subreceta') {
      const totalConMargen = sumaBase * (1 + margenError);
      const cantidadResultado = Math.max(
        Number(receta.cantidad_resultado ?? 1),
        0.001,
      );
      const costoPorUnidad = totalConMargen / cantidadResultado;
      return {
        receta_id: recetaId,
        costo_ingredientes: costoIngredientes,
        costo_subrecetas: costoSubrecetas,
        costo_empaques: 0,
        costo_merma: costoMerma,
        costo_base: totalConMargen,
        costo_domicilio: totalConMargen,
        costo_por_porcion: costoPorUnidad,
      };
    }

    const costoBase = sumaBase * (1 + margenError);
    const porciones = Math.max(Number(receta.rendimiento_porciones ?? 1), 1);
    const costoDomicilio = costoBase + costoEmpaques;

    return {
      receta_id: recetaId,
      costo_ingredientes: costoIngredientes,
      costo_subrecetas: costoSubrecetas,
      costo_empaques: costoEmpaques,
      costo_merma: costoMerma,
      costo_base: costoBase,
      costo_domicilio: costoDomicilio,
      costo_por_porcion: costoBase / porciones,
    };
  }

  async persistirCostoReceta(
    client: PoolClient,
    sucursalId: string,
    desglose: DesgloseCostoReceta,
    precioVenta?: number | null,
  ): Promise<void> {
    const foodCost =
      precioVenta && precioVenta > 0
        ? (desglose.costo_por_porcion / precioVenta) * 100
        : null;

    await client.query(
      `INSERT INTO costos_receta (
         receta_id, sucursal_id, costo_total, costo_por_porcion,
         costo_ingredientes, costo_subrecetas, costo_empaques, costo_merma,
         food_cost_porcentaje, calculado_at
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, now())`,
      [
        desglose.receta_id,
        sucursalId,
        desglose.costo_base,
        desglose.costo_por_porcion,
        desglose.costo_ingredientes,
        desglose.costo_subrecetas,
        desglose.costo_empaques,
        desglose.costo_merma,
        foodCost,
      ],
    );
  }

  async recalcularProducto(
    client: PoolClient,
    productoId: string,
    sucursalId: string,
    recalculando: Set<string> = new Set(),
    recalcularPadres = true,
  ): Promise<number> {
    const producto = await client.query<{
      receta_id: string | null;
      precio: string;
    }>(
      `SELECT receta_id, precio FROM productos
       WHERE id = $1 AND sucursal_id = $2`,
      [productoId, sucursalId],
    );
    const fila = producto.rows[0];
    if (!fila) return 0;

    let costoPorcion = 0;
    let costoDomicilio = 0;
    let desglose: DesgloseCostoReceta | null = null;

    if (fila.receta_id) {
      desglose = await this.calcularReceta(
        client,
        fila.receta_id,
        sucursalId,
      );
      costoPorcion = desglose.costo_por_porcion;
      costoDomicilio = desglose.costo_domicilio;
    }

    const costoIncluidos = await this.sumarCostosItemsIncluidos(
      client,
      productoId,
      sucursalId,
      recalculando,
    );
    costoPorcion += costoIncluidos.base;
    costoDomicilio += costoIncluidos.domicilio;

    if (!fila.receta_id && costoIncluidos.base === 0) return 0;

    const precio = Number(fila.precio);
    const margenObj = await this.margenObjetivoProducto(
      client,
      productoId,
      sucursalId,
    );
    const precioSugerido = this.calcularPrecioSugerido(costoPorcion, margenObj);

    await client.query(
      `UPDATE productos SET
         costo_calculado = $1,
         costo_domicilio = $2,
         precio_sugerido = $3
       WHERE id = $4 AND sucursal_id = $5`,
      [costoPorcion, costoDomicilio, precioSugerido, productoId, sucursalId],
    );

    if (desglose) {
      await this.persistirCostoReceta(client, sucursalId, desglose, precio);
    }
    await this.evaluarAlertaMargenProducto(
      client,
      productoId,
      sucursalId,
      precio,
      costoPorcion,
    );

    if (recalcularPadres) {
      await this.recalcularProductosPadre(
        client,
        productoId,
        sucursalId,
        recalculando,
      );
    }

    return costoPorcion;
  }

  async recalcularCombo(
    client: PoolClient,
    comboId: string,
    sucursalId: string,
  ): Promise<number> {
    const combo = await client.query<{
      precio_fijo: string;
      margen_error: string;
      costo_empaque_extra: string;
    }>(
      `SELECT precio_fijo, margen_error, costo_empaque_extra FROM combos
       WHERE id = $1 AND sucursal_id = $2`,
      [comboId, sucursalId],
    );
    const fila = combo.rows[0];
    if (!fila) throw new NotFoundException('Combo no encontrado');

    const items = await client.query<{
      tipo_item: string;
      item_id: string;
      cantidad: number;
    }>(
      `SELECT tipo_item, item_id, cantidad FROM combo_items WHERE combo_id = $1`,
      [comboId],
    );

    let costo = Number(fila.costo_empaque_extra ?? 0);
    for (const ci of items.rows) {
      if (ci.tipo_item !== 'producto') continue;
      const prod = await client.query<{ costo: string | null }>(
        `SELECT costo_calculado AS costo FROM productos
         WHERE id = $1 AND sucursal_id = $2`,
        [ci.item_id, sucursalId],
      );
      costo += Number(prod.rows[0]?.costo ?? 0) * ci.cantidad;
    }

    const margenError = Number(fila.margen_error ?? 0);
    costo = costo * (1 + margenError);

    await client.query(
      `UPDATE combos SET costo_calculado = $1 WHERE id = $2`,
      [costo, comboId],
    );

    const precioFijo = Number(fila.precio_fijo);
    if (precioFijo > 0) {
      const margenPct = ((precioFijo - costo) / precioFijo) * 100;
      const umbral = await this.umbralMargenSucursal(client, sucursalId);
      if (margenPct < umbral) {
        await this.alertasRiesgo.registrarEnTransaccion(client, {
          sucursalId,
          tipo: 'combo_margen_bajo',
          nivel: 'medio',
          descripcion: `Combo con margen ${margenPct.toFixed(1)}% (costo ${costo.toFixed(0)}, precio ${precioFijo})`,
          referenciaId: comboId,
          referenciaTipo: 'combo',
          deduplicar: true,
        });
      }
    }

    return costo;
  }

  async recalcularSucursal(sucursalId: string) {
    return this.database.enTransaccion(async (client) => {
      const subrecetas = await client.query<{ id: string }>(
        `SELECT id FROM recetas
         WHERE sucursal_id = $1 AND tipo = 'subreceta'
         ORDER BY created_at`,
        [sucursalId],
      );
      for (const sr of subrecetas.rows) {
        const d = await this.calcularReceta(client, sr.id, sucursalId);
        await this.persistirCostoReceta(client, sucursalId, d, null);
      }

      const productos = await client.query<{ id: string }>(
        `SELECT id FROM productos WHERE sucursal_id = $1 AND receta_id IS NOT NULL`,
        [sucursalId],
      );
      let nProd = 0;
      for (const p of productos.rows) {
        await this.recalcularProducto(client, p.id, sucursalId);
        nProd++;
      }

      const combos = await client.query<{ id: string }>(
        `SELECT id FROM combos WHERE sucursal_id = $1`,
        [sucursalId],
      );
      let nCombo = 0;
      for (const c of combos.rows) {
        await this.recalcularCombo(client, c.id, sucursalId);
        nCombo++;
      }

      return {
        productos_recalculados: nProd,
        combos_recalculados: nCombo,
        subrecetas_recalculadas: subrecetas.rows.length,
      };
    });
  }

  /** Ingredientes planos para descuento de stock (expande subrecetas). */
  async expandirIngredientesProducto(
    client: PoolClient,
    productoId: string,
    sucursalId: string,
    cantidadPorciones: number,
    incluirEmpaques: boolean,
  ): Promise<IngredienteExpandido[]> {
    const producto = await client.query<{ receta_id: string | null }>(
      `SELECT receta_id FROM productos WHERE id = $1 AND sucursal_id = $2`,
      [productoId, sucursalId],
    );
    const recetaId = producto.rows[0]?.receta_id;
    if (!recetaId) return [];

    const acumulador = new Map<string, number>();
    await this.expandirReceta(
      client,
      recetaId,
      sucursalId,
      cantidadPorciones,
      incluirEmpaques,
      new Set(),
      acumulador,
    );

    const incluidos = await client.query<{
      producto_incluido_id: string;
      cantidad: string;
    }>(
      `SELECT producto_incluido_id, cantidad::float AS cantidad
       FROM producto_items_incluidos
       WHERE producto_id = $1 AND sucursal_id = $2`,
      [productoId, sucursalId],
    );

    for (const inc of incluidos.rows) {
      const sub = await this.expandirIngredientesProducto(
        client,
        inc.producto_incluido_id,
        sucursalId,
        cantidadPorciones * Number(inc.cantidad),
        incluirEmpaques,
      );
      for (const s of sub) {
        acumulador.set(
          s.ingrediente_id,
          (acumulador.get(s.ingrediente_id) ?? 0) + s.cantidad,
        );
      }
    }

    return [...acumulador.entries()].map(([ingrediente_id, cantidad]) => ({
      ingrediente_id,
      cantidad,
    }));
  }

  /** Solo receta del producto (sin ítems incluidos ni sus sub-recetas). */
  async expandirSoloRecetaProducto(
    client: PoolClient,
    productoId: string,
    sucursalId: string,
    cantidadPorciones: number,
    incluirEmpaques: boolean,
  ): Promise<IngredienteExpandido[]> {
    const producto = await client.query<{ receta_id: string | null }>(
      `SELECT receta_id FROM productos WHERE id = $1 AND sucursal_id = $2`,
      [productoId, sucursalId],
    );
    const recetaId = producto.rows[0]?.receta_id;
    if (!recetaId) return [];

    const acumulador = new Map<string, number>();
    await this.expandirReceta(
      client,
      recetaId,
      sucursalId,
      cantidadPorciones,
      incluirEmpaques,
      new Set(),
      acumulador,
    );

    return [...acumulador.entries()].map(([ingrediente_id, cantidad]) => ({
      ingrediente_id,
      cantidad,
    }));
  }

  async listarItemsIncluidosProducto(productoId: string, sucursalId: string) {
    // Refresca costos de incluidos y del plato padre antes de leer (evita cifras obsoletas).
    await this.database.enTransaccion(async (client) => {
      const recalculando = new Set<string>();
      const incluidos = await client.query<{ producto_incluido_id: string }>(
        `SELECT producto_incluido_id FROM producto_items_incluidos
         WHERE producto_id = $1 AND sucursal_id = $2`,
        [productoId, sucursalId],
      );
      for (const fila of incluidos.rows) {
        await this.recalcularProducto(
          client,
          fila.producto_incluido_id,
          sucursalId,
          recalculando,
          false,
        );
      }
      await this.recalcularProducto(
        client,
        productoId,
        sucursalId,
        recalculando,
        false,
      );
    });

    return this.database.consultar(
      `SELECT pii.id, pii.producto_incluido_id, pii.cantidad,
              pr.nombre AS producto_incluido_nombre,
              pr.precio AS producto_incluido_precio,
              pr.costo_calculado AS producto_incluido_costo
       FROM producto_items_incluidos pii
       INNER JOIN productos pr ON pr.id = pii.producto_incluido_id
       WHERE pii.producto_id = $1 AND pii.sucursal_id = $2
       ORDER BY pr.nombre`,
      [productoId, sucursalId],
    );
  }

  calcularPrecioSugerido(costo: number, margenObjetivoPct: number): number {
    if (margenObjetivoPct >= 100) return costo * 2;
    return Math.round(costo / (1 - margenObjetivoPct / 100));
  }

  /** Vista admin: qué insumos descuenta una venta y si alcanza el stock. */
  async impactoStockProducto(
    productoId: string,
    sucursalId: string,
    cantidad = 1,
  ) {
    return this.database.enTransaccion(async (client) => {
      const producto = await client.query<{ nombre: string; receta_id: string | null }>(
        `SELECT nombre, receta_id FROM productos WHERE id = $1 AND sucursal_id = $2`,
        [productoId, sucursalId],
      );
      const filaProd = producto.rows[0];
      if (!filaProd) {
        throw new NotFoundException('Producto no encontrado');
      }

      const expandidos = await this.expandirIngredientesProducto(
        client,
        productoId,
        sucursalId,
        cantidad,
        false,
      );

      const incluidos = await client.query<{
        producto_incluido_id: string;
        cantidad: string;
        nombre: string;
      }>(
        `SELECT pii.producto_incluido_id, pii.cantidad::float AS cantidad, pr.nombre
         FROM producto_items_incluidos pii
         INNER JOIN productos pr ON pr.id = pii.producto_incluido_id
         WHERE pii.producto_id = $1 AND pii.sucursal_id = $2`,
        [productoId, sucursalId],
      );

      if (expandidos.length === 0) {
        return {
          producto_id: productoId,
          producto_nombre: filaProd.nombre,
          cantidad,
          tiene_receta: filaProd.receta_id != null,
          puede_vender: true,
          ingredientes: [],
          faltas: [],
          incluidos: incluidos.rows.map((i) => ({
            producto_id: i.producto_incluido_id,
            nombre: i.nombre,
            cantidad: Number(i.cantidad) * cantidad,
          })),
          mensaje:
            filaProd.receta_id == null
              ? 'Sin receta: no descuenta inventario al vender.'
              : null,
        };
      }

      const ids = expandidos.map((e) => e.ingrediente_id);
      const stockRows = await client.query<{
        id: string;
        nombre: string;
        unidad_base: string;
        stock_actual: string;
        stock_minimo: string;
        descontar_stock: boolean;
      }>(
        `SELECT id, nombre, unidad_base, stock_actual, stock_minimo, descontar_stock
         FROM ingredientes WHERE sucursal_id = $1 AND id = ANY($2::uuid[])`,
        [sucursalId, ids],
      );
      const porId = new Map(stockRows.rows.map((r) => [r.id, r]));

      const ingredientes = expandidos.map((exp) => {
        const ing = porId.get(exp.ingrediente_id);
        const disponible = Number(ing?.stock_actual ?? 0);
        const minimo = Number(ing?.stock_minimo ?? 0);
        const descontar = ing?.descontar_stock !== false;
        const necesita = exp.cantidad;
        const falta = descontar && disponible < necesita;
        return {
          ingrediente_id: exp.ingrediente_id,
          nombre: ing?.nombre ?? 'Insumo',
          unidad: ing?.unidad_base ?? 'und',
          necesita,
          disponible,
          minimo,
          descontar_stock: descontar,
          bajo_minimo: descontar && disponible <= minimo,
          falta,
        };
      });

      const faltas = ingredientes.filter((i) => i.falta);

      return {
        producto_id: productoId,
        producto_nombre: filaProd.nombre,
        cantidad,
        tiene_receta: true,
        puede_vender: faltas.length === 0,
        ingredientes,
        faltas,
        incluidos: incluidos.rows.map((i) => ({
          producto_id: i.producto_incluido_id,
          nombre: i.nombre,
          cantidad: Number(i.cantidad) * cantidad,
        })),
        mensaje:
          faltas.length > 0
            ? `Falta stock: ${faltas.map((f) => f.nombre).join(', ')}`
            : 'Stock suficiente para 1 venta.',
      };
    });
  }

  async resumenSucursal(sucursalId: string) {
    const umbral = await this.umbralMargenSucursalDesdeDb(sucursalId);
    const productos = await this.database.consultar(
      `SELECT p.id, p.nombre, p.precio, p.precio_para_llevar,
              p.costo_calculado, p.costo_domicilio,
              p.precio_sugerido, p.margen_objetivo,
              CASE WHEN p.precio > 0 AND p.costo_calculado IS NOT NULL
                THEN ROUND(((p.precio - p.costo_calculado) / p.precio) * 100, 1)
                ELSE NULL END AS margen_porcentaje,
              CASE WHEN p.precio > 0 AND p.costo_calculado IS NOT NULL
                THEN ROUND((p.costo_calculado / p.precio) * 100, 1)
                ELSE NULL END AS food_cost_porcentaje
       FROM productos p
       WHERE p.sucursal_id = $1
       ORDER BY p.nombre`,
      [sucursalId],
    );

    const combos = await this.listarCombos(sucursalId);
    const bajoMargen = productos.filter(
      (p) =>
        p.margen_porcentaje != null &&
        Number(p.margen_porcentaje) < umbral,
    );

    return {
      productos,
      combos,
      productos_bajo_margen: bajoMargen.length,
      umbral_margen: umbral,
    };
  }

  async recalcularComboPorId(comboId: string, sucursalId: string) {
    return this.database.enTransaccion(async (client) => {
      const costo = await this.recalcularCombo(client, comboId, sucursalId);
      return { combo_id: comboId, costo_calculado: costo };
    });
  }

  async recalcularProductoPorId(productoId: string, sucursalId: string) {
    return this.database.enTransaccion(async (client) => {
      const costo = await this.recalcularProducto(
        client,
        productoId,
        sucursalId,
      );
      return { producto_id: productoId, costo_calculado: costo };
    });
  }

  crearSubreceta(dto: CrearSubrecetaDto) {
    return this.database.enTransaccion(async (client) => {
      const receta = await client.query<{ id: string }>(
        `INSERT INTO recetas (
           sucursal_id, nombre, tipo, margen_error,
           cantidad_resultado, unidad_resultado, rendimiento_porciones
         ) VALUES ($1,$2,'subreceta',$3,$4,$5,1)
         RETURNING id`,
        [
          dto.sucursal_id,
          dto.nombre,
          dto.margen_error ?? 0.05,
          dto.cantidad_resultado,
          dto.unidad_resultado,
        ],
      );
      const recetaId = receta.rows[0].id;
      await this.insertarItemsSubreceta(
        client,
        recetaId,
        dto.sucursal_id,
        dto.items,
      );
      const desglose = await this.calcularReceta(
        client,
        recetaId,
        dto.sucursal_id,
      );
      await this.persistirCostoReceta(client, dto.sucursal_id, desglose, null);
      return {
        receta_id: recetaId,
        costo_por_unidad: desglose.costo_por_porcion,
        desglose,
      };
    });
  }

  listarCombos(sucursalId: string) {
    return this.database.consultar(
      `SELECT c.id, c.nombre, c.precio_fijo, c.costo_calculado, c.costo_empaque_extra,
              CASE WHEN c.precio_fijo > 0 AND c.costo_calculado IS NOT NULL
                THEN ROUND(((c.precio_fijo - c.costo_calculado) / c.precio_fijo) * 100, 1)
                ELSE NULL END AS margen_porcentaje,
              CASE WHEN c.precio_fijo > 0 AND c.costo_calculado IS NOT NULL
                THEN ROUND((c.costo_calculado / c.precio_fijo) * 100, 1)
                ELSE NULL END AS food_cost_porcentaje
       FROM combos c
       WHERE c.sucursal_id = $1
       ORDER BY c.nombre`,
      [sucursalId],
    );
  }

  listarSubrecetas(sucursalId: string) {
    return this.database.consultar(
      `SELECT r.id, r.nombre, r.cantidad_resultado, r.unidad_resultado,
              r.margen_error,
              cr.costo_total,
              cr.costo_por_porcion AS costo_por_unidad,
              cr.costo_ingredientes,
              (
                SELECT COUNT(*)::int
                FROM receta_items ri
                WHERE ri.receta_id = r.id
              ) AS num_items
       FROM recetas r
       LEFT JOIN LATERAL (
         SELECT costo_total, costo_por_porcion, costo_ingredientes
         FROM costos_receta
         WHERE receta_id = r.id
         ORDER BY calculado_at DESC
         LIMIT 1
       ) cr ON true
       WHERE r.sucursal_id = $1 AND r.tipo = 'subreceta'
       ORDER BY r.nombre`,
      [sucursalId],
    );
  }

  async obtenerSubrecetaDetalle(recetaId: string, sucursalId: string) {
    const cabecera = await this.database.consultarUno<{
      id: string;
      nombre: string;
      cantidad_resultado: string;
      unidad_resultado: string;
      margen_error: string;
    }>(
      `SELECT id, nombre, cantidad_resultado, unidad_resultado, margen_error
       FROM recetas
       WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`,
      [recetaId, sucursalId],
    );
    if (!cabecera) throw new NotFoundException('SUBRECETA_NO_ENCONTRADA');

    const items = await this.database.consultar(
      `SELECT ri.id, ri.tipo_item, ri.ingrediente_id, ri.subreceta_id,
              ri.cantidad, ri.unidad, ri.orden,
              i.nombre AS ingrediente_nombre,
              i.costo_unitario_actual, i.unidad_base,
              sr.nombre AS subreceta_nombre,
              sr.unidad_resultado AS subreceta_unidad
       FROM receta_items ri
       LEFT JOIN ingredientes i ON i.id = ri.ingrediente_id
       LEFT JOIN recetas sr ON sr.id = ri.subreceta_id
       WHERE ri.receta_id = $1
         AND ri.tipo_item IN ('ingrediente', 'subreceta')
       ORDER BY ri.orden, ri.id`,
      [recetaId],
    );

    const costo = await this.database.consultarUno<{
      costo_total: string;
      costo_por_porcion: string;
      costo_ingredientes: string;
      costo_merma: string;
      calculado_at: string;
    }>(
      `SELECT costo_total, costo_por_porcion, costo_ingredientes, costo_merma, calculado_at
       FROM costos_receta
       WHERE receta_id = $1
       ORDER BY calculado_at DESC
       LIMIT 1`,
      [recetaId],
    );

    return {
      ...cabecera,
      items,
      costo,
    };
  }

  actualizarSubreceta(recetaId: string, dto: ActualizarSubrecetaDto) {
    return this.database.enTransaccion(async (client) => {
      const existe = await client.query<{ id: string }>(
        `SELECT id FROM recetas
         WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`,
        [recetaId, dto.sucursal_id],
      );
      if (!existe.rows[0]) {
        throw new NotFoundException('SUBRECETA_NO_ENCONTRADA');
      }

      await client.query(
        `UPDATE recetas
         SET nombre = $1, margen_error = $2,
             cantidad_resultado = $3, unidad_resultado = $4
         WHERE id = $5`,
        [
          dto.nombre,
          dto.margen_error ?? 0.05,
          dto.cantidad_resultado,
          dto.unidad_resultado,
          recetaId,
        ],
      );

      await client.query(`DELETE FROM receta_items WHERE receta_id = $1`, [
        recetaId,
      ]);

      await this.insertarItemsSubreceta(
        client,
        recetaId,
        dto.sucursal_id,
        dto.items,
        recetaId,
      );

      const desglose = await this.calcularReceta(
        client,
        recetaId,
        dto.sucursal_id,
      );
      await this.persistirCostoReceta(
        client,
        dto.sucursal_id,
        desglose,
        null,
      );
      await this.recalcularProductosQueUsanSubreceta(
        client,
        recetaId,
        dto.sucursal_id,
      );

      return {
        receta_id: recetaId,
        costo_por_unidad: desglose.costo_por_porcion,
        desglose,
      };
    });
  }

  recalcularSubrecetaPorId(recetaId: string, sucursalId: string) {
    return this.database.enTransaccion(async (client) => {
      const existe = await client.query<{ id: string }>(
        `SELECT id FROM recetas
         WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`,
        [recetaId, sucursalId],
      );
      if (!existe.rows[0]) {
        throw new NotFoundException('SUBRECETA_NO_ENCONTRADA');
      }

      const desglose = await this.calcularReceta(client, recetaId, sucursalId);
      await this.persistirCostoReceta(client, sucursalId, desglose, null);
      await this.recalcularProductosQueUsanSubreceta(
        client,
        recetaId,
        sucursalId,
      );

      return {
        receta_id: recetaId,
        costo_por_unidad: desglose.costo_por_porcion,
        desglose,
      };
    });
  }

  private async recalcularProductosQueUsanSubreceta(
    client: PoolClient,
    subrecetaId: string,
    sucursalId: string,
  ): Promise<void> {
    const productos = await client.query<{ producto_id: string }>(
      `SELECT DISTINCT p.id AS producto_id
       FROM productos p
       JOIN receta_items ri ON ri.receta_id = p.receta_id
       WHERE p.sucursal_id = $1
         AND ri.tipo_item = 'subreceta'
         AND ri.subreceta_id = $2`,
      [sucursalId, subrecetaId],
    );
    for (const row of productos.rows) {
      await this.recalcularProducto(client, row.producto_id, sucursalId);
    }
  }

  private async expandirReceta(
    client: PoolClient,
    recetaId: string,
    sucursalId: string,
    factor: number,
    incluirEmpaques: boolean,
    visitados: Set<string>,
    acumulador: Map<string, number>,
  ): Promise<void> {
    if (visitados.has(recetaId)) return;
    visitados.add(recetaId);

    const receta = await this.consultarReceta(client, recetaId, sucursalId);
    const items = await client.query<{
      tipo_item: string;
      ingrediente_id: string | null;
      subreceta_id: string | null;
      cantidad: string;
    }>(
      `SELECT tipo_item, ingrediente_id, subreceta_id, cantidad::float AS cantidad
       FROM receta_items WHERE receta_id = $1`,
      [recetaId],
    );

    for (const item of items.rows) {
      const cantidad = Number(item.cantidad) * factor;
      if (item.tipo_item === 'empaque' && !incluirEmpaques) continue;

      if (
        (item.tipo_item === 'ingrediente' || item.tipo_item === 'empaque') &&
        item.ingrediente_id
      ) {
        const prev = acumulador.get(item.ingrediente_id) ?? 0;
        acumulador.set(item.ingrediente_id, prev + cantidad);
      } else if (item.tipo_item === 'subreceta' && item.subreceta_id) {
        const sub = await this.consultarReceta(
          client,
          item.subreceta_id,
          sucursalId,
        );
        const cantidadResultado = Math.max(
          Number(sub.cantidad_resultado ?? 1),
          0.001,
        );
        const factorSub = cantidad / cantidadResultado;
        await this.expandirReceta(
          client,
          item.subreceta_id,
          sucursalId,
          factorSub,
          false,
          visitados,
          acumulador,
        );
      }
    }

    if (receta.tipo === 'producto' && receta.rendimiento_porciones > 1) {
      // factor ya incluye porciones del caller
    }
  }

  private async costoUnitarioSubreceta(
    client: PoolClient,
    subrecetaId: string,
    sucursalId: string,
    visitados: Set<string>,
  ): Promise<number> {
    const d = await this.calcularReceta(client, subrecetaId, sucursalId, visitados);
    return d.costo_por_porcion;
  }

  private async costoLineaIngrediente(
    client: PoolClient,
    ingredienteId: string,
    sucursalId: string,
    cantidad: number,
    unidadLinea?: string,
  ): Promise<{ costoReal: number; mermaExtra: number }> {
    const ing = await client.query<{
      costo_unitario_actual: string;
      rendimiento_porcentaje: string;
      unidad_base: string;
      peso_bruto: string | null;
      peso_neto: string | null;
    }>(
      `SELECT costo_unitario_actual, rendimiento_porcentaje, unidad_base,
              peso_bruto, peso_neto
       FROM ingredientes
       WHERE id = $1 AND sucursal_id = $2 AND activo = true`,
      [ingredienteId, sucursalId],
    );
    const fila = ing.rows[0];
    if (!fila) throw new NotFoundException('INGREDIENTE_NO_ENCONTRADO');

    const unidadBase = fila.unidad_base ?? 'g';
    if (unidadLinea) {
      exigirUnidadesCompatibles(
        unidadLinea,
        unidadBase,
        'Línea de receta',
      );
    }
    const cantidadBase = unidadLinea
      ? convertirCantidad(cantidad, unidadLinea, unidadBase)
      : cantidad;

    const costoBase = Number(fila.costo_unitario_actual ?? 0);
    const modoMercado =
      fila.peso_neto != null && Number(fila.peso_neto) > 0;

    let costoRealUnit: number;
    let mermaExtra: number;

    if (modoMercado) {
      // Modo mercado KYG: costo_unitario ya es precio / peso_neto (costo real).
      costoRealUnit = costoBase;
      const bruto = Number(fila.peso_bruto ?? 0);
      const neto = Number(fila.peso_neto ?? 1);
      const costoBrutoUnit =
        bruto > 0 ? costoBase * (neto / bruto) : costoBase;
      mermaExtra = Math.max(
        0,
        (costoRealUnit - costoBrutoUnit) * cantidadBase,
      );
    } else {
      const rend = Number(fila.rendimiento_porcentaje ?? 100);
      costoRealUnit = this.costoRealUnitario(costoBase, rend);
      const sinMerma = costoBase * cantidadBase;
      const conMerma = costoRealUnit * cantidadBase;
      mermaExtra = Math.max(0, conMerma - sinMerma);
    }

    return {
      costoReal: costoRealUnit * cantidadBase,
      mermaExtra,
    };
  }

  private async insertarItemsSubreceta(
    client: PoolClient,
    recetaId: string,
    sucursalId: string,
    items: SubrecetaItemDto[],
    excluirSubrecetaId?: string,
  ): Promise<void> {
    let orden = 0;
    for (const item of items) {
      const tipo = item.tipo_item ?? 'ingrediente';
      if (tipo === 'subreceta') {
        if (!item.subreceta_id) {
          throw new BadRequestException('SUBRECETA_REQUERIDA');
        }
        if (item.subreceta_id === excluirSubrecetaId) {
          throw new BadRequestException('SUBRECETA_CIRCULAR');
        }
        await this.cantidadEnUnidadSubreceta(
          client,
          item.subreceta_id,
          sucursalId,
          item.cantidad,
          item.unidad,
        );
        await client.query(
          `INSERT INTO receta_items (
             receta_id, tipo_item, subreceta_id, cantidad, unidad, orden
           ) VALUES ($1,'subreceta',$2,$3,$4,$5)`,
          [
            recetaId,
            item.subreceta_id,
            item.cantidad,
            item.unidad,
            orden++,
          ],
        );
      } else {
        if (!item.ingrediente_id) {
          throw new BadRequestException('INGREDIENTE_REQUERIDO');
        }
        const ing = await client.query<{ unidad_base: string }>(
          `SELECT unidad_base FROM ingredientes
           WHERE id = $1 AND sucursal_id = $2 AND activo = true`,
          [item.ingrediente_id, sucursalId],
        );
        if (!ing.rows[0]) {
          throw new NotFoundException('INGREDIENTE_NO_ENCONTRADO');
        }
        exigirUnidadesCompatibles(
          item.unidad,
          ing.rows[0].unidad_base,
          'Línea de subreceta',
        );
        await client.query(
          `INSERT INTO receta_items (
             receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden
           ) VALUES ($1,'ingrediente',$2,$3,$4,$5)`,
          [
            recetaId,
            item.ingrediente_id,
            item.cantidad,
            item.unidad,
            orden++,
          ],
        );
      }
    }
  }

  private async cantidadEnUnidadSubreceta(
    client: PoolClient,
    subrecetaId: string,
    sucursalId: string,
    cantidad: number,
    unidadLinea: string,
  ): Promise<number> {
    const sr = await client.query<{ unidad_resultado: string }>(
      `SELECT unidad_resultado FROM recetas
       WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`,
      [subrecetaId, sucursalId],
    );
    if (!sr.rows[0]) throw new NotFoundException('SUBRECETA_NO_ENCONTRADA');
    const unidadRes = sr.rows[0].unidad_resultado ?? 'g';
    exigirUnidadesCompatibles(
      unidadLinea,
      unidadRes,
      'Línea de subreceta',
    );
    return convertirCantidad(cantidad, unidadLinea, unidadRes);
  }

  private async consultarReceta(
    client: PoolClient,
    recetaId: string,
    sucursalId: string,
  ) {
    const r = await client.query<{
      id: string;
      tipo: string;
      margen_error: string;
      rendimiento_porciones: number;
      cantidad_resultado: string | null;
    }>(
      `SELECT id, COALESCE(tipo, 'producto') AS tipo,
              margen_error, rendimiento_porciones, cantidad_resultado
       FROM recetas WHERE id = $1 AND sucursal_id = $2`,
      [recetaId, sucursalId],
    );
    if (!r.rows[0]) throw new NotFoundException('RECETA_NO_ENCONTRADA');
    return r.rows[0];
  }

  private async margenObjetivoProducto(
    client: PoolClient,
    productoId: string,
    sucursalId: string,
  ): Promise<number> {
    const p = await client.query<{ margen: string }>(
      `SELECT COALESCE(p.margen_objetivo, s.margen_objetivo_default, 35)::float AS margen
       FROM productos p
       JOIN sucursales s ON s.id = p.sucursal_id
       WHERE p.id = $1 AND p.sucursal_id = $2`,
      [productoId, sucursalId],
    );
    return Number(p.rows[0]?.margen ?? 35);
  }

  private async umbralMargenSucursal(
    client: PoolClient,
    sucursalId: string,
  ): Promise<number> {
    const r = await client.query<{ umbral: string }>(
      `SELECT COALESCE(umbral_alerta_margen, 35)::float AS umbral
       FROM sucursales WHERE id = $1`,
      [sucursalId],
    );
    return Number(r.rows[0]?.umbral ?? 25);
  }

  private umbralMargenSucursalDesdeDb(sucursalId: string): Promise<number> {
    return this.database.enTransaccion(async (client) =>
      this.umbralMargenSucursal(client, sucursalId),
    );
  }

  private async sumarCostosItemsIncluidos(
    client: PoolClient,
    productoId: string,
    sucursalId: string,
    recalculando: Set<string>,
  ): Promise<{ base: number; domicilio: number }> {
    const filas = await client.query<{
      producto_incluido_id: string;
      cantidad: string;
    }>(
      `SELECT producto_incluido_id, cantidad::float AS cantidad
       FROM producto_items_incluidos
       WHERE producto_id = $1 AND sucursal_id = $2`,
      [productoId, sucursalId],
    );

    let base = 0;
    let domicilio = 0;
    for (const fila of filas.rows) {
      const unit = await this.obtenerCostoUnitarioIncluido(
        client,
        fila.producto_incluido_id,
        sucursalId,
        recalculando,
      );
      const cant = Number(fila.cantidad);
      base += unit.base * cant;
      domicilio += unit.domicilio * cant;
    }
    return { base, domicilio };
  }

  private async obtenerCostoUnitarioIncluido(
    client: PoolClient,
    productoIncluidoId: string,
    sucursalId: string,
    recalculando: Set<string>,
  ): Promise<{ base: number; domicilio: number }> {
    if (recalculando.has(productoIncluidoId)) {
      throw new BadRequestException('INCLUIDOS_CIRCULAR');
    }

    let prod = await client.query<{
      costo_calculado: string | null;
      costo_domicilio: string | null;
    }>(
      `SELECT costo_calculado, costo_domicilio FROM productos
       WHERE id = $1 AND sucursal_id = $2`,
      [productoIncluidoId, sucursalId],
    );
    if (!prod.rows[0]) {
      throw new NotFoundException('PRODUCTO_INCLUIDO_NO_ENCONTRADO');
    }

    if (!recalculando.has(productoIncluidoId)) {
      recalculando.add(productoIncluidoId);
      try {
        await this.recalcularProducto(
          client,
          productoIncluidoId,
          sucursalId,
          recalculando,
          false,
        );
      } finally {
        recalculando.delete(productoIncluidoId);
      }
      prod = await client.query(
        `SELECT costo_calculado, costo_domicilio FROM productos
         WHERE id = $1 AND sucursal_id = $2`,
        [productoIncluidoId, sucursalId],
      );
    }

    const base = Number(prod.rows[0]?.costo_calculado ?? 0);
    const domicilio = Number(
      prod.rows[0]?.costo_domicilio ?? prod.rows[0]?.costo_calculado ?? 0,
    );
    return { base, domicilio };
  }

  private async recalcularProductosPadre(
    client: PoolClient,
    productoIncluidoId: string,
    sucursalId: string,
    recalculando: Set<string>,
  ): Promise<void> {
    const padres = await client.query<{ producto_id: string }>(
      `SELECT producto_id FROM producto_items_incluidos
       WHERE producto_incluido_id = $1 AND sucursal_id = $2`,
      [productoIncluidoId, sucursalId],
    );
    for (const p of padres.rows) {
      if (recalculando.has(p.producto_id)) continue;
      await this.recalcularProducto(
        client,
        p.producto_id,
        sucursalId,
        recalculando,
        false,
      );
    }
  }

  private async evaluarAlertaMargenProducto(
    client: PoolClient,
    productoId: string,
    sucursalId: string,
    precio: number,
    costo: number,
  ): Promise<void> {
    if (precio <= 0) return;
    const margenPct = ((precio - costo) / precio) * 100;
    const umbral = await this.umbralMargenSucursal(client, sucursalId);
    if (margenPct < umbral) {
      await this.alertasRiesgo.registrarEnTransaccion(client, {
        sucursalId,
        tipo: 'producto_margen_bajo',
        nivel: 'medio',
        descripcion: `Producto con margen ${margenPct.toFixed(1)}% (umbral ${umbral}%)`,
        referenciaId: productoId,
        referenciaTipo: 'producto',
        deduplicar: true,
      });
    }
  }
}
