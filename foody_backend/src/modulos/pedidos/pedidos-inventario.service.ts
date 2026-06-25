import { BadRequestException } from '@nestjs/common';
import { PoolClient } from 'pg';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';

interface IngredienteStock {
  ingrediente_id: string;
  nombre: string;
  unidad_base: string;
  cantidad: number;
  stock_actual: number;
  stock_minimo: number;
  costo_unitario_actual: number;
  descontar_stock: boolean;
}

export interface LineaStock {
  productoId: string;
  cantidad: number;
  precioVentaLinea: number;
  nombreProducto?: string;
}

export type CambioDisponibilidadProducto = {
  producto_id: string;
  disponible: boolean;
};

export type ResultadoDescontarStock = {
  costos: Map<string, number>;
  catalogo: CambioDisponibilidadProducto[];
};

/** Contexto para alertas admin cuando un pedido falla por inventario. */
export interface ContextoAlertaStock {
  origen: 'mesa' | 'domicilio' | 'para_llevar' | 'staff';
  clienteNombre?: string | null;
  mesaNombre?: string | null;
}

/**
 * Inventario de pedidos: validar al crear, descontar al confirmar, devolver al cancelar.
 */
export class PedidosInventarioService {
  constructor(
    private readonly costeo: CosteoService,
    private readonly alertas?: AlertasRiesgoService,
  ) {}

  /** Solo comprueba stock (creación cliente QR / pendiente). */
  async validarStockDisponible(
    client: PoolClient,
    sucursalId: string,
    lineas: LineaStock[],
    opciones: { incluirEmpaques?: boolean } = {},
    contextoAlerta?: ContextoAlertaStock,
  ): Promise<void> {
    const faltas = await this.detectarFaltasStock(
      client,
      sucursalId,
      lineas,
      opciones,
    );
    if (faltas.length > 0) {
      if (contextoAlerta) {
        await this.registrarAlertasIntentoPedido(
          client,
          sucursalId,
          lineas,
          faltas,
          opciones,
          contextoAlerta,
        );
      }
      this.lanzarStockInsuficiente(faltas);
    }
  }

  /**
   * Crea alertas en BD (transacción aparte) para que persistan aunque el pedido haga rollback.
   */
  private async registrarAlertasIntentoPedido(
    client: PoolClient,
    sucursalId: string,
    lineas: LineaStock[],
    faltasAgregadas: {
      ingrediente_id: string;
      nombre: string;
      necesita: number;
      disponible: number;
      unidad: string;
    }[],
    opciones: { incluirEmpaques?: boolean },
    contexto: ContextoAlertaStock,
  ): Promise<void> {
    if (!this.alertas) return;

    const incluirEmpaques = opciones.incluirEmpaques ?? false;
    const idsFaltantes = new Set(faltasAgregadas.map((f) => f.ingrediente_id));

    for (const linea of lineas) {
      const faltasLinea = await this.detectarFaltasStock(
        client,
        sucursalId,
        [linea],
        opciones,
      );
      if (faltasLinea.length === 0) continue;

      const nombreProducto =
        linea.nombreProducto ??
        (await this.nombreProducto(client, linea.productoId));

      for (const falta of faltasLinea) {
        if (!idsFaltantes.has(falta.ingrediente_id)) continue;

        const origenTxt = this.textoOrigenPedido(contexto);
        const detalleVia = await this.explicarFaltaEnProducto(
          client,
          sucursalId,
          linea.productoId,
          linea.cantidad,
          falta,
          incluirEmpaques,
        );

        const descripcion =
          `Un cliente intentó pedir ${linea.cantidad}× ${nombreProducto}${origenTxt}, ` +
          `pero no hay stock de ${falta.nombre} ` +
          `(necesita ${this.fmtCantidad(falta.necesita)} ${falta.unidad}, hay ${this.fmtCantidad(falta.disponible)}). ` +
          detalleVia;

        await this.alertas.registrar({
          sucursalId,
          tipo: 'intento_pedido_sin_stock',
          nivel: 'alto',
          descripcion,
          referenciaId: falta.ingrediente_id,
          referenciaTipo: 'ingrediente',
          deduplicar: true,
        });
      }
    }
  }

  private textoOrigenPedido(ctx: ContextoAlertaStock): string {
    const partes: string[] = [];
    if (ctx.clienteNombre?.trim()) {
      partes.push(ctx.clienteNombre.trim());
    }
    if (ctx.mesaNombre?.trim()) {
      partes.push(`mesa ${ctx.mesaNombre.trim()}`);
    } else if (ctx.origen === 'domicilio') {
      partes.push('domicilio');
    } else if (ctx.origen === 'para_llevar') {
      partes.push('para llevar');
    } else if (ctx.origen === 'staff') {
      partes.push('pedido staff');
    }
    if (partes.length === 0) return '';
    return ` (${partes.join(', ')})`;
  }

  private async explicarFaltaEnProducto(
    client: PoolClient,
    sucursalId: string,
    productoId: string,
    cantidadPedida: number,
    falta: { ingrediente_id: string; nombre: string; necesita: number; unidad: string },
    incluirEmpaques: boolean,
  ): Promise<string> {
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

    const viasIncluidos: { nombre: string; cantidadTotal: number; necesita: number }[] =
      [];

    for (const inc of incluidos.rows) {
      const cantIncluidos = cantidadPedida * Number(inc.cantidad);
      const exp = await this.costeo.expandirIngredientesProducto(
        client,
        inc.producto_incluido_id,
        sucursalId,
        cantIncluidos,
        incluirEmpaques,
      );
      const uso = exp.find((e) => e.ingrediente_id === falta.ingrediente_id);
      if (uso && uso.cantidad > 0) {
        viasIncluidos.push({
          nombre: inc.nombre,
          cantidadTotal: cantIncluidos,
          necesita: uso.cantidad,
        });
      }
    }

    if (viasIncluidos.length > 0) {
      const lista = viasIncluidos
        .map(
          (v) =>
            `${this.fmtCantidad(v.cantidadTotal)}× ${v.nombre} ` +
            `(${this.fmtCantidad(v.necesita)} ${falta.unidad} de ${falta.nombre})`,
        )
        .join(', ');
      return `El ${falta.nombre} se usa en los ítems incluidos: ${lista}.`;
    }

    const recetaDirecta = await this.costeo.expandirSoloRecetaProducto(
      client,
      productoId,
      sucursalId,
      cantidadPedida,
      incluirEmpaques,
    );
    const enReceta = recetaDirecta.find(
      (e) => e.ingrediente_id === falta.ingrediente_id,
    );
    if (enReceta) {
      return `El ${falta.nombre} forma parte de la receta directa del plato.`;
    }

    return `Revisa la receta e ítems incluidos del plato en Costos y márgenes.`;
  }

  private async nombreProducto(
    client: PoolClient,
    productoId: string,
  ): Promise<string> {
    const fila = await client.query<{ nombre: string }>(
      `SELECT nombre FROM productos WHERE id = $1`,
      [productoId],
    );
    return fila.rows[0]?.nombre ?? 'Producto';
  }

  private fmtCantidad(n: number): string {
    return Number.isInteger(n) ? String(n) : n.toFixed(1);
  }

  /** Ingredientes que faltarían para las líneas indicadas (admin / preview). */
  async detectarFaltasStock(
    client: PoolClient,
    sucursalId: string,
    lineas: LineaStock[],
    opciones: { incluirEmpaques?: boolean } = {},
  ): Promise<
    {
      ingrediente_id: string;
      nombre: string;
      necesita: number;
      disponible: number;
      unidad: string;
    }[]
  > {
    const incluirEmpaques = opciones.incluirEmpaques ?? false;
    const acumulado = new Map<
      string,
      { cantidad: number; nombre: string; unidad: string }
    >();

    for (const linea of lineas) {
      const expandidos = await this.costeo.expandirIngredientesProducto(
        client,
        linea.productoId,
        sucursalId,
        linea.cantidad,
        incluirEmpaques,
      );
      if (expandidos.length === 0) continue;

      const ingredientes = await this.cargarStockIngredientes(
        client,
        sucursalId,
        expandidos,
        { lanzarSiFaltaIngrediente: false },
      );

      for (const ing of ingredientes) {
        if (!ing.descontar_stock) continue;
        const prev = acumulado.get(ing.ingrediente_id);
        acumulado.set(ing.ingrediente_id, {
          cantidad: (prev?.cantidad ?? 0) + ing.cantidad,
          nombre: ing.nombre,
          unidad: ing.unidad_base,
        });
      }
    }

    const faltas: {
      ingrediente_id: string;
      nombre: string;
      necesita: number;
      disponible: number;
      unidad: string;
    }[] = [];

    for (const [ingredienteId, req] of acumulado) {
      const fila = await client.query<{
        stock_actual: string;
        descontar_stock: boolean;
      }>(
        `SELECT stock_actual, descontar_stock FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 AND activo = true`,
        [ingredienteId, sucursalId],
      );
      const ing = fila.rows[0];
      if (!ing || ing.descontar_stock === false) continue;
      const disponible = Number(ing.stock_actual);
      if (disponible < req.cantidad) {
        faltas.push({
          ingrediente_id: ingredienteId,
          nombre: req.nombre,
          necesita: req.cantidad,
          disponible,
          unidad: req.unidad,
        });
      }
    }

    return faltas;
  }

  private lanzarStockInsuficiente(
    faltas: {
      ingrediente_id: string;
      nombre: string;
      necesita: number;
      disponible: number;
      unidad: string;
    }[],
  ): never {
    const resumen = faltas
      .map(
        (f) =>
          `${f.nombre}: necesitas ${f.necesita} ${f.unidad}, hay ${f.disponible}`,
      )
      .join('; ');
    throw new BadRequestException({
      error: 'STOCK_INSUFICIENTE',
      message: resumen,
      detalles: faltas,
    });
  }

  /** Descuenta stock y registra movimientos tipo venta. */
  async descontarStockPedido(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    lineas: LineaStock[],
    opciones: { incluirEmpaques?: boolean } = {},
  ): Promise<ResultadoDescontarStock> {
    const costosPorProducto = new Map<string, number>();
    const catalogo: CambioDisponibilidadProducto[] = [];
    const incluirEmpaques = opciones.incluirEmpaques ?? false;

    for (const linea of lineas) {
      const expandidos = await this.costeo.expandirIngredientesProducto(
        client,
        linea.productoId,
        sucursalId,
        linea.cantidad,
        incluirEmpaques,
      );

      if (expandidos.length === 0) {
        const costoProducto = await this.costoCalculadoProducto(
          client,
          linea.productoId,
        );
        costosPorProducto.set(linea.productoId, costoProducto);
        continue;
      }

      const ingredientes = await this.cargarStockIngredientes(
        client,
        sucursalId,
        expandidos,
      );

      let costoLinea = 0;
      const faltasLinea = ingredientes
        .filter(
          (ing) => ing.descontar_stock && ing.stock_actual < ing.cantidad,
        )
        .map((ing) => ({
          ingrediente_id: ing.ingrediente_id,
          nombre: ing.nombre,
          necesita: ing.cantidad,
          disponible: ing.stock_actual,
          unidad: ing.unidad_base,
        }));
      if (faltasLinea.length > 0) {
        this.lanzarStockInsuficiente(faltasLinea);
      }

      for (const ing of ingredientes) {
        costoLinea += ing.cantidad * ing.costo_unitario_actual;
        if (!ing.descontar_stock) continue;
      }

      for (const ing of ingredientes) {
        if (!ing.descontar_stock) continue;
        const stockAnterior = ing.stock_actual;
        const stockPosterior = stockAnterior - ing.cantidad;

        await client.query(
          `UPDATE ingredientes
           SET stock_actual = $1
           WHERE id = $2 AND sucursal_id = $3`,
          [stockPosterior, ing.ingrediente_id, sucursalId],
        );

        await client.query(
          `INSERT INTO movimientos_ingrediente (
             sucursal_id, ingrediente_id, pedido_id, tipo,
             cantidad, stock_anterior, stock_posterior, motivo
           ) VALUES ($1,$2,$3,'venta',$4,$5,$6,$7)`,
          [
            sucursalId,
            ing.ingrediente_id,
            pedidoId,
            ing.cantidad,
            stockAnterior,
            stockPosterior,
            'Venta pedido',
          ],
        );

        await this.alertarStockBajo(
          client,
          sucursalId,
          ing.ingrediente_id,
          stockPosterior,
          ing.stock_minimo,
        );

        if (stockPosterior <= 0) {
          await client.query(
            `UPDATE productos SET disponible = false
             WHERE id = $1 AND sucursal_id = $2`,
            [linea.productoId, sucursalId],
          );
          catalogo.push({
            producto_id: linea.productoId,
            disponible: false,
          });
        }

        ing.stock_actual = stockPosterior;
      }

      costosPorProducto.set(linea.productoId, costoLinea / linea.cantidad);
    }

    return { costos: costosPorProducto, catalogo };
  }

  /** Devuelve ingredientes descontados por un pedido confirmado (cancelación). */
  async restaurarStockPedido(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
  ): Promise<CambioDisponibilidadProducto[]> {
    const catalogo: CambioDisponibilidadProducto[] = [];
    const movs = await client.query<{
      ingrediente_id: string;
      cantidad: string;
    }>(
      `SELECT ingrediente_id, cantidad
       FROM movimientos_ingrediente
       WHERE pedido_id = $1 AND sucursal_id = $2 AND tipo = 'venta'`,
      [pedidoId, sucursalId],
    );

    for (const mov of movs.rows) {
      const cantidad = Number(mov.cantidad);
      const ing = await client.query<{
        stock_actual: string;
        stock_minimo: string;
      }>(
        `SELECT stock_actual, stock_minimo FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [mov.ingrediente_id, sucursalId],
      );
      const fila = ing.rows[0];
      if (!fila) continue;

      const stockAnterior = Number(fila.stock_actual);
      const stockPosterior = stockAnterior + cantidad;

      await client.query(
        `UPDATE ingredientes SET stock_actual = $1
         WHERE id = $2 AND sucursal_id = $3`,
        [stockPosterior, mov.ingrediente_id, sucursalId],
      );

      await client.query(
        `INSERT INTO movimientos_ingrediente (
           sucursal_id, ingrediente_id, pedido_id, tipo,
           cantidad, stock_anterior, stock_posterior, motivo
         ) VALUES ($1,$2,$3,'ajuste',$4,$5,$6,$7)`,
        [
          sucursalId,
          mov.ingrediente_id,
          pedidoId,
          cantidad,
          stockAnterior,
          stockPosterior,
          'Devolución por cancelación/rechazo de pedido',
        ],
      );

      if (stockPosterior > 0) {
        const reactivados = await client.query<{ id: string }>(
          `UPDATE productos p SET disponible = true
           FROM receta_items ri
           INNER JOIN productos pr ON pr.receta_id = ri.receta_id
           WHERE pr.sucursal_id = $1
             AND ri.ingrediente_id = $2
             AND p.id = pr.id
             AND p.disponible = false
           RETURNING p.id`,
          [sucursalId, mov.ingrediente_id],
        );
        for (const row of reactivados.rows) {
          catalogo.push({ producto_id: row.id, disponible: true });
        }
      }
    }
    return catalogo;
  }

  /** Registra merma (stock ya descontado; no restaura). INV-011 */
  async registrarMermaLineaProducto(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    productoId: string,
    cantidad: number,
    motivo: string,
  ): Promise<void> {
    const expandidos = await this.costeo.expandirIngredientesProducto(
      client,
      productoId,
      sucursalId,
      cantidad,
      false,
    );
    if (expandidos.length === 0) return;

    const ingredientes = await this.cargarStockIngredientes(
      client,
      sucursalId,
      expandidos,
    );

    for (const ing of ingredientes) {
      if (!ing.descontar_stock) continue;
      const stock = ing.stock_actual;

      await client.query(
        `INSERT INTO movimientos_ingrediente (
           sucursal_id, ingrediente_id, pedido_id, tipo,
           cantidad, stock_anterior, stock_posterior, motivo
         ) VALUES ($1,$2,$3,'merma',$4,$5,$5,$6)`,
        [
          sucursalId,
          ing.ingrediente_id,
          pedidoId,
          ing.cantidad,
          stock,
          motivo,
        ],
      );
    }
  }

  /** Devuelve stock de una línea de producto eliminada del pedido. */
  async restaurarStockLineaProducto(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    productoId: string,
    cantidad: number,
    opciones: { incluirEmpaques?: boolean } = {},
  ): Promise<void> {
    const expandidos = await this.costeo.expandirIngredientesProducto(
      client,
      productoId,
      sucursalId,
      cantidad,
      opciones.incluirEmpaques ?? false,
    );
    if (expandidos.length === 0) return;

    const ingredientes = await this.cargarStockIngredientes(
      client,
      sucursalId,
      expandidos,
    );

    for (const ing of ingredientes) {
      if (!ing.descontar_stock) continue;
      const stockAnterior = ing.stock_actual;
      const stockPosterior = stockAnterior + ing.cantidad;

      await client.query(
        `UPDATE ingredientes SET stock_actual = $1
         WHERE id = $2 AND sucursal_id = $3`,
        [stockPosterior, ing.ingrediente_id, sucursalId],
      );

      await client.query(
        `INSERT INTO movimientos_ingrediente (
           sucursal_id, ingrediente_id, pedido_id, tipo,
           cantidad, stock_anterior, stock_posterior, motivo
         ) VALUES ($1,$2,$3,'ajuste',$4,$5,$6,$7)`,
        [
          sucursalId,
          ing.ingrediente_id,
          pedidoId,
          ing.cantidad,
          stockAnterior,
          stockPosterior,
          'Devolución por ítem eliminado del pedido',
        ],
      );

      await this.alertarStockBajo(
        client,
        sucursalId,
        ing.ingrediente_id,
        stockPosterior,
        ing.stock_minimo,
      );
    }
  }

  /** Reconstruye líneas de inventario desde ítems ya guardados en el pedido. */
  async lineasDesdePedido(
    client: PoolClient,
    pedidoId: string,
    sucursalId: string,
  ): Promise<LineaStock[]> {
    const lineas = new Map<string, { cantidad: number; precioVentaLinea: number }>();

    const items = await client.query<{
      producto_id: string;
      cantidad: number;
      precio_unitario: string;
      item_id: string;
    }>(
      `SELECT pi.id AS item_id, pi.producto_id, pi.cantidad, pi.precio_unitario
       FROM pedido_items pi
       WHERE pi.pedido_id = $1`,
      [pedidoId],
    );

    for (const row of items.rows) {
      const combo = await client.query<{ combo_id: string }>(
        `SELECT combo_id FROM pedido_combo_selecciones WHERE pedido_item_id = $1`,
        [row.item_id],
      );
      if (combo.rows[0]) {
        const comboItems = await client.query<{
          item_id: string;
          cantidad: number;
        }>(
          `SELECT item_id, cantidad FROM combo_items
           WHERE combo_id = $1 AND tipo_item = 'producto'`,
          [combo.rows[0].combo_id],
        );
        for (const ci of comboItems.rows) {
          const cant = Number(ci.cantidad) * row.cantidad;
          const prev = lineas.get(ci.item_id);
          lineas.set(ci.item_id, {
            cantidad: (prev?.cantidad ?? 0) + cant,
            precioVentaLinea: (prev?.precioVentaLinea ?? 0) + 1,
          });
        }
      } else {
        const prev = lineas.get(row.producto_id);
        const venta = Number(row.precio_unitario) * row.cantidad;
        lineas.set(row.producto_id, {
          cantidad: (prev?.cantidad ?? 0) + row.cantidad,
          precioVentaLinea: (prev?.precioVentaLinea ?? 0) + venta,
        });
      }
    }

    return [...lineas.entries()].map(([productoId, v]) => ({
      productoId,
      cantidad: v.cantidad,
      precioVentaLinea: v.precioVentaLinea,
    }));
  }

  /** @deprecated Usar validarStockDisponible + descontarStockPedido */
  async validarYDescontarStock(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
    lineas: LineaStock[],
    opciones: { incluirEmpaques?: boolean } = {},
  ): Promise<ResultadoDescontarStock> {
    await this.validarStockDisponible(client, sucursalId, lineas, opciones);
    return this.descontarStockPedido(
      client,
      sucursalId,
      pedidoId,
      lineas,
      opciones,
    );
  }

  private async alertarStockBajo(
    client: PoolClient,
    sucursalId: string,
    ingredienteId: string,
    stockPosterior: number,
    stockMinimo: number,
  ) {
    if (stockPosterior > stockMinimo) return;
    if (this.alertas) {
      await this.alertas.registrarEnTransaccion(client, {
        sucursalId,
        tipo: 'stock_minimo_alcanzado',
        nivel: 'medio',
        descripcion: 'Stock bajo en ingrediente tras pedido',
        referenciaId: ingredienteId,
        referenciaTipo: 'ingrediente',
        deduplicar: true,
      });
    } else {
      await client.query(
        `INSERT INTO alertas_riesgo (
           sucursal_id, tipo, nivel, descripcion, referencia_id, referencia_tipo
         ) VALUES ($1,'stock_minimo_alcanzado','medio',$2,$3,'ingrediente')`,
        [sucursalId, 'Stock bajo en ingrediente tras pedido', ingredienteId],
      );
    }
  }

  private async cargarStockIngredientes(
    client: PoolClient,
    sucursalId: string,
    expandidos: { ingrediente_id: string; cantidad: number }[],
    opciones: { lanzarSiFaltaIngrediente?: boolean } = {},
  ): Promise<IngredienteStock[]> {
    const lanzar = opciones.lanzarSiFaltaIngrediente !== false;
    const ids = expandidos.map((e) => e.ingrediente_id);
    const resultado = await client.query<{
      id: string;
      nombre: string;
      unidad_base: string;
      stock_actual: string;
      stock_minimo: string;
      costo_unitario_actual: string;
      descontar_stock: boolean;
    }>(
      `SELECT id, nombre, unidad_base, stock_actual, stock_minimo,
              costo_unitario_actual, descontar_stock
       FROM ingredientes
       WHERE sucursal_id = $1 AND activo = true AND id = ANY($2::uuid[])`,
      [sucursalId, ids],
    );

    const porId = new Map(resultado.rows.map((r) => [r.id, r]));

    return expandidos.map((exp) => {
      const fila = porId.get(exp.ingrediente_id);
      if (!fila) {
        if (lanzar) {
          this.lanzarStockInsuficiente([
            {
              ingrediente_id: exp.ingrediente_id,
              nombre: 'Insumo no encontrado',
              necesita: exp.cantidad,
              disponible: 0,
              unidad: 'und',
            },
          ]);
        }
        return {
          ingrediente_id: exp.ingrediente_id,
          nombre: 'Insumo no encontrado',
          unidad_base: 'und',
          cantidad: exp.cantidad,
          stock_actual: 0,
          stock_minimo: 0,
          costo_unitario_actual: 0,
          descontar_stock: true,
        };
      }
      return {
        ingrediente_id: exp.ingrediente_id,
        nombre: fila.nombre,
        unidad_base: fila.unidad_base ?? 'und',
        cantidad: exp.cantidad,
        stock_actual: Number(fila.stock_actual),
        stock_minimo: Number(fila.stock_minimo),
        costo_unitario_actual: Number(fila.costo_unitario_actual),
        descontar_stock: fila.descontar_stock !== false,
      };
    });
  }

  private async costoCalculadoProducto(
    client: PoolClient,
    productoId: string,
  ): Promise<number> {
    const fila = await client.query<{ costo: string | null }>(
      `SELECT costo_calculado AS costo FROM productos WHERE id = $1`,
      [productoId],
    );
    return Number(fila.rows[0]?.costo ?? 0);
  }
}
