import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { PlanFeaturesService } from '../../core/auth/plan-features.service';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { CosteoService } from '../costeo/costeo.service';
import { CatalogoDisponibilidadService } from '../catalogo/catalogo-disponibilidad.service';
import { ActualizarIngredienteDto } from './dto/actualizar-ingrediente.dto';
import { ConfigurarRecetaProductoDto } from './dto/configurar-receta-producto.dto';
import { CrearIngredienteDto } from './dto/crear-ingrediente.dto';
import { CerrarConteoDto } from './dto/cerrar-conteo.dto';
import { RegistrarCompraDto } from './dto/registrar-compra.dto';
import { CrearTrasladoDto } from './dto/crear-traslado.dto';
import {
  exigirUnidadesCompatibles,
  normalizarUnidad,
} from '../costeo/unidad-costeo.util';
import {
  derivarCostoDesdeMercado,
  enriquecerInsumoRespuesta,
  tipoCosteoDesdeUnidad,
} from './insumo-mercado.util';
import {
  envolverPaginado,
  opcionesListado,
  PaginacionQueryDto,
  resolverPaginacion,
} from '../../compartido/dto/paginacion.dto';
import { StockMovimientoService } from './stock-movimiento.service';

@Injectable()
export class InventarioService {
  constructor(
    private readonly database: DatabaseService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly costeo: CosteoService,
    private readonly catalogoDisponibilidad: CatalogoDisponibilidadService,
    private readonly planFeatures: PlanFeaturesService,
    private readonly stockMovimiento: StockMovimientoService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  private assertPuedeTrasladosMultiSucursal(actor: JwtPayload) {
    if (!this.sucursalScope.puedeVerInventarioHermanas(actor)) {
      throw new ForbiddenException({
        error: 'TRASLADOS_REQUIERE_ADMIN_MULTI_SUCURSAL',
        message:
          'Los traslados entre sedes requieren permiso corporativo (gestionar sucursales).',
      });
    }
  }

  /** Resumen de inventario en sucursales hermanas (solo lectura admin). */
  async resumenInventarioHermanas(actor: JwtPayload) {
    if (!this.sucursalScope.puedeVerInventarioHermanas(actor)) {
      await this.sucursalScope.validarLecturaInventario(
        actor,
        actor.sucursal_id!,
      );
      return {
        sucursal_propia: actor.sucursal_id,
        puede_ver_hermanas: false,
        sucursales: [],
      };
    }

    const restauranteId = actor.restaurante_id!;
    const sucursalPropiaId = actor.sucursal_id!;
    const sucursales = await this.database.consultar<{
      id: string;
      nombre: string;
    }>(
      `SELECT id, nombre FROM sucursales
       WHERE restaurante_id = $1 AND activa = true
       ORDER BY nombre ASC`,
      [restauranteId],
    );

    const resultado: {
      sucursal_id: string;
      nombre: string;
      es_propia: boolean;
      solo_lectura: boolean;
      total_insumos: number;
      bajo_stock: number;
      agotados: number;
      alertas: {
        id: string;
        nombre: string;
        stock_actual: number;
        stock_minimo: number;
        unidad_base: string;
        bajo_minimo: boolean;
      }[];
    }[] = [];
    for (const suc of sucursales) {
      const stats = await this.database.consultarUno<{
        total: string;
        bajo: string;
        agotados: string;
      }>(
        `SELECT COUNT(*)::text AS total,
                COUNT(*) FILTER (
                  WHERE descontar_stock = true
                    AND COALESCE(es_subreceta, false) = false
                    AND stock_actual > 0
                    AND stock_actual <= stock_minimo
                )::text AS bajo,
                COUNT(*) FILTER (
                  WHERE descontar_stock = true
                    AND COALESCE(es_subreceta, false) = false
                    AND stock_actual <= 0
                )::text AS agotados
         FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true`,
        [suc.id],
      );
      const ingredientes = await this.database.consultar<{
        id: string;
        nombre: string;
        stock_actual: string;
        stock_minimo: string;
        unidad_base: string;
        bajo_minimo: boolean;
      }>(
        `SELECT id, nombre, stock_actual, stock_minimo, unidad_base,
                (stock_actual <= stock_minimo) AS bajo_minimo
         FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true
           AND descontar_stock = true
           AND COALESCE(es_subreceta, false) = false
           AND (stock_actual <= stock_minimo)
         ORDER BY stock_actual ASC, nombre ASC
         LIMIT 12`,
        [suc.id],
      );

      resultado.push({
        sucursal_id: suc.id,
        nombre: suc.nombre,
        es_propia: suc.id === sucursalPropiaId,
        solo_lectura: suc.id !== sucursalPropiaId,
        total_insumos: Number(stats?.total ?? 0),
        bajo_stock: Number(stats?.bajo ?? 0),
        agotados: Number(stats?.agotados ?? 0),
        alertas: ingredientes.map((ing) => ({
          id: ing.id,
          nombre: ing.nombre,
          stock_actual: Number(ing.stock_actual),
          stock_minimo: Number(ing.stock_minimo),
          unidad_base: ing.unidad_base,
          bajo_minimo: ing.bajo_minimo,
        })),
      });
    }

    return {
      sucursal_propia: sucursalPropiaId,
      puede_ver_hermanas: true,
      sucursales: resultado,
    };
  }

  async listarIngredientes(
    sucursalId: string,
    query: PaginacionQueryDto = {},
  ) {
    const opts = opcionesListado(query, 50);
    const select = `SELECT id, nombre, unidad_base, tipo_costeo, stock_actual, stock_minimo,
              costo_unitario_actual, descontar_stock, activo, created_at,
              proveedor, precio_compra, peso_bruto, peso_neto, categoria_insumo,
              rendimiento_porcentaje,
              (stock_actual <= stock_minimo) AS bajo_minimo
       FROM ingredientes
       WHERE sucursal_id = $1 AND activo = true
         AND COALESCE(es_subreceta, false) = false`;
    if (!opts.paginar) {
      const filas = await this.database.consultar(
        `${select}
       ORDER BY nombre ASC
       LIMIT $2`,
        [sucursalId, opts.limite],
      );
      return filas.map((f) => enriquecerInsumoRespuesta(f));
    }
    const { page, limit, offset } = resolverPaginacion(
      opts.page,
      opts.limite,
      50,
    );
    const [items, totalRow] = await Promise.all([
      this.database.consultar(
        `${select}
       ORDER BY nombre ASC
       LIMIT $2 OFFSET $3`,
        [sucursalId, limit, offset],
      ),
      this.database.consultarUno<{ count: number }>(
        `SELECT COUNT(*)::int AS count FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true
           AND COALESCE(es_subreceta, false) = false`,
        [sucursalId],
      ),
    ]);
    return envolverPaginado(
      items.map((f) => enriquecerInsumoRespuesta(f)),
      totalRow?.count ?? 0,
      page,
      limit,
    );
  }

  async crearIngrediente(dto: CrearIngredienteDto, restauranteId?: string) {
    if (restauranteId) {
      await this.planFeatures.assertLimiteIngredientes(restauranteId, dto.sucursal_id);
    }
    const unidad = dto.unidad_base;
    const tipoCosteo = dto.tipo_costeo ?? tipoCosteoDesdeUnidad(unidad);
    const descontarStock = dto.descontar_stock ?? unidad !== 'servicio';
    const categoria =
      dto.categoria_insumo ??
      (descontarStock ? 'alimento' : 'mano_obra');

    let costoUnitario = dto.costo_unitario_actual ?? 0;
    let rendimiento = 100;
    let precioCompra: number | null = dto.precio_compra ?? null;
    let pesoBruto: number | null = dto.peso_bruto ?? null;
    let pesoNeto: number | null = dto.peso_neto ?? null;

    const modoMercado =
      dto.precio_compra != null &&
      dto.peso_bruto != null &&
      dto.peso_neto != null &&
      dto.peso_neto > 0;

    if (modoMercado) {
      const derivado = derivarCostoDesdeMercado({
        precio_compra: dto.precio_compra!,
        peso_bruto: dto.peso_bruto!,
        peso_neto: dto.peso_neto!,
        unidad_base: unidad,
      });
      costoUnitario = derivado.costo_unitario_actual;
      rendimiento = derivado.rendimiento_porcentaje;
    } else if (!descontarStock && dto.costo_unitario_actual != null) {
      costoUnitario = dto.costo_unitario_actual;
      precioCompra = null;
      pesoBruto = null;
      pesoNeto = null;
    }

    const fila = await this.database.consultarUno(
      `INSERT INTO ingredientes (
         sucursal_id, nombre, unidad_base, tipo_costeo,
         stock_actual, stock_minimo, costo_unitario_actual, descontar_stock,
         proveedor, precio_compra, peso_bruto, peso_neto, categoria_insumo,
         rendimiento_porcentaje
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       RETURNING id, nombre, unidad_base, stock_actual, stock_minimo,
                 costo_unitario_actual, descontar_stock, proveedor,
                 precio_compra, peso_bruto, peso_neto, categoria_insumo,
                 rendimiento_porcentaje`,
      [
        dto.sucursal_id,
        dto.nombre,
        unidad,
        tipoCosteo,
        dto.stock_actual ?? 0,
        dto.stock_minimo ?? 0,
        costoUnitario,
        descontarStock,
        dto.proveedor ?? null,
        precioCompra,
        pesoBruto,
        pesoNeto,
        categoria,
        rendimiento,
      ],
    );
    if (!fila) {
      throw new NotFoundException('INGREDIENTE_NO_CREADO');
    }
    if (costoUnitario > 0) {
      await this.costeo.recalcularSucursal(dto.sucursal_id);
    }
    return enriquecerInsumoRespuesta(fila as Record<string, unknown>);
  }

  async actualizarIngrediente(
    id: string,
    sucursalId: string,
    usuarioId: string,
    dto: ActualizarIngredienteDto,
  ) {
    let recalcularCostos = false;
    let stockCambio = false;

    const result = await this.database.enTransaccion(async (client) => {
      const actual = await this.exigirIngrediente(client, id, sucursalId);

      if (dto.stock_nuevo !== undefined) {
        const nuevo = dto.stock_nuevo;
        const anterior = Number(actual.stock_actual);
        if (nuevo !== anterior) {
          await this.stockMovimiento.aplicarMovimiento({
            client,
            sucursalId,
            ingredienteId: id,
            tipo: 'ajuste',
            cantidad: Math.abs(nuevo - anterior),
            stockAnterior: anterior,
            stockPosterior: nuevo,
            motivo: dto.motivo_ajuste ?? 'Ajuste manual',
            usuarioId,
          });
          stockCambio = true;
        }
      }

      const campos: string[] = [];
      const valores: unknown[] = [];
      let i = 1;

      const setCampo = (col: string, val: unknown) => {
        campos.push(`${col} = $${i++}`);
        valores.push(val);
      };

      if (dto.nombre !== undefined) setCampo('nombre', dto.nombre);
      if (dto.proveedor !== undefined) setCampo('proveedor', dto.proveedor);
      if (dto.categoria_insumo !== undefined) {
        setCampo('categoria_insumo', dto.categoria_insumo);
      }
      if (dto.unidad_base !== undefined) {
        setCampo('unidad_base', dto.unidad_base);
        setCampo('tipo_costeo', tipoCosteoDesdeUnidad(dto.unidad_base));
      }
      if (dto.descontar_stock !== undefined) {
        setCampo('descontar_stock', dto.descontar_stock);
      }
      if (dto.stock_minimo !== undefined) {
        setCampo('stock_minimo', dto.stock_minimo);
      }

      const precioCompra =
        dto.precio_compra ?? (actual.precio_compra != null ? Number(actual.precio_compra) : null);
      const pesoBruto =
        dto.peso_bruto ?? (actual.peso_bruto != null ? Number(actual.peso_bruto) : null);
      const pesoNeto =
        dto.peso_neto ?? (actual.peso_neto != null ? Number(actual.peso_neto) : null);
      const unidad =
        dto.unidad_base ?? (actual.unidad_base as string);

      const tocóMercado =
        dto.precio_compra !== undefined ||
        dto.peso_bruto !== undefined ||
        dto.peso_neto !== undefined;

      if (tocóMercado) {
        if (precioCompra == null || pesoBruto == null || pesoNeto == null) {
          throw new BadRequestException('DATOS_MERCADO_INCOMPLETOS');
        }
        const derivado = derivarCostoDesdeMercado({
          precio_compra: precioCompra,
          peso_bruto: pesoBruto,
          peso_neto: pesoNeto,
          unidad_base: unidad,
        });
        setCampo('precio_compra', precioCompra);
        setCampo('peso_bruto', pesoBruto);
        setCampo('peso_neto', pesoNeto);
        setCampo('costo_unitario_actual', derivado.costo_unitario_actual);
        setCampo('rendimiento_porcentaje', derivado.rendimiento_porcentaje);
        recalcularCostos = true;
      } else if (dto.costo_unitario_actual !== undefined) {
        setCampo('costo_unitario_actual', dto.costo_unitario_actual);
        recalcularCostos = true;
      }

      if (campos.length) {
        valores.push(id, sucursalId);
        await client.query(
          `UPDATE ingredientes SET ${campos.join(', ')}
           WHERE id = $${i++} AND sucursal_id = $${i}`,
          valores,
        );
      }

      const fila = await this.obtenerIngrediente(client, id, sucursalId);
      return { fila, stockCambio };
    });

    if (result.stockCambio) {
      const cambios =
        await this.catalogoDisponibilidad.sincronizarPorIngrediente(
          sucursalId,
          id,
        );
      this.catalogoDisponibilidad.emitirCambios(sucursalId, cambios);
      const stock = Number(result.fila.stock_actual);
      const minimo = Number(result.fila.stock_minimo ?? 0);
      if (minimo > 0 && stock <= minimo) {
        await this.alertasRiesgo.registrar({
          sucursalId,
          tipo: 'stock_minimo_alcanzado',
          nivel: 'medio',
          descripcion: `Stock bajo en ${result.fila.nombre} tras ajuste (${stock} ≤ ${minimo})`,
          referenciaId: id,
          referenciaTipo: 'ingrediente',
          deduplicar: true,
        });
      }
    }

    if (recalcularCostos) {
      await this.costeo.recalcularSucursal(sucursalId);
    }
    return enriquecerInsumoRespuesta(result.fila);
  }

  listarMovimientos(
    sucursalId: string,
    opciones: { limite?: number; page?: number; paginar?: boolean } = {},
  ) {
    const select = `SELECT m.id, m.ingrediente_id, i.nombre AS ingrediente_nombre,
              m.tipo, m.cantidad, m.stock_anterior, m.stock_posterior,
              m.motivo, m.pedido_id, m.usuario_id, u.nombre AS usuario_nombre,
              m.created_at
       FROM movimientos_ingrediente m
       INNER JOIN ingredientes i ON i.id = m.ingrediente_id
       LEFT JOIN usuarios u ON u.id = m.usuario_id
       WHERE m.sucursal_id = $1`;
    if (!opciones.paginar) {
      const limite = opciones.limite ?? 50;
      return this.database.consultar(
        `${select}
       ORDER BY m.created_at DESC
       LIMIT $2`,
        [sucursalId, limite],
      );
    }
    const { page, limit, offset } = resolverPaginacion(
      opciones.page,
      opciones.limite,
      50,
    );
    return Promise.all([
      this.database.consultar(
        `${select}
       ORDER BY m.created_at DESC
       LIMIT $2 OFFSET $3`,
        [sucursalId, limit, offset],
      ),
      this.database.consultarUno<{ count: number }>(
        `SELECT COUNT(*)::int AS count FROM movimientos_ingrediente
         WHERE sucursal_id = $1`,
        [sucursalId],
      ),
    ]).then(([items, totalRow]) =>
      envolverPaginado(items, totalRow?.count ?? 0, page, limit),
    );
  }

  registrarCompra(dto: RegistrarCompraDto, usuarioId: string) {
    return this.database.enTransaccion(async (client) => {
      let totalCompra = 0;
      for (const item of dto.items) {
        totalCompra += item.precio_total;
      }

      const compra = await client.query<{ id: string }>(
        `INSERT INTO compras_inventario (
           sucursal_id, usuario_id, proveedor, total_compra, observaciones
         ) VALUES ($1,$2,$3,$4,$5)
         RETURNING id`,
        [
          dto.sucursal_id,
          usuarioId,
          dto.proveedor ?? null,
          totalCompra,
          dto.observaciones ?? null,
        ],
      );
      const compraId = compra.rows[0].id;

      for (const item of dto.items) {
        const ing = await this.exigirIngrediente(
          client,
          item.ingrediente_id,
          dto.sucursal_id,
        );
        const costoUnitario =
          item.cantidad_unidades_base > 0
            ? item.precio_total / item.cantidad_unidades_base
            : 0;
        const stockAnterior = Number(ing.stock_actual);
        const stockPosterior = stockAnterior + item.cantidad_unidades_base;
        const costoAnterior = Number(ing.costo_unitario_actual ?? 0);

        await client.query(
          `INSERT INTO compra_items (
             compra_id, ingrediente_id, cantidad_presentaciones,
             precio_presentacion, cantidad_unidades_base, costo_unitario_base
           ) VALUES ($1,$2,1,$3,$4,$5)`,
          [
            compraId,
            item.ingrediente_id,
            item.precio_total,
            item.cantidad_unidades_base,
            costoUnitario,
          ],
        );

        await this.stockMovimiento.aplicarMovimiento({
          client,
          sucursalId: dto.sucursal_id,
          ingredienteId: item.ingrediente_id,
          tipo: 'compra',
          cantidad: item.cantidad_unidades_base,
          stockAnterior,
          stockPosterior,
          motivo: `Compra ${compraId}`,
          usuarioId,
          costoUnitarioActual: costoUnitario,
        });

        await this.alertasRiesgo.evaluarSubidaCostoIngrediente(
          client,
          dto.sucursal_id,
          item.ingrediente_id,
          ing.nombre,
          costoAnterior,
          costoUnitario,
        );
      }

      const ingredientesAfectados = [
        ...new Set(dto.items.map((i) => i.ingrediente_id)),
      ];
      return {
        compra_id: compraId,
        total_compra: totalCompra,
        ingredientesAfectados,
      };
    }).then(async (result) => {
      await this.costeo.recalcularSucursal(dto.sucursal_id);
      await this.sincronizarCatalogoPorIngredientes(
        dto.sucursal_id,
        result.ingredientesAfectados,
      );
      return { compra_id: result.compra_id, total_compra: result.total_compra };
    });
  }

  async recetaDeProducto(
    productoId: string,
    sucursalId: string,
    tipoEntidad: 'producto' | 'bebida' | 'topping' = 'producto',
  ) {
    if (tipoEntidad === 'bebida' || tipoEntidad === 'topping') {
      return this.recetaDeExtra(productoId, sucursalId, tipoEntidad);
    }
    const producto = await this.database.consultarUno<{
      receta_id: string | null;
      costo_calculado: string | null;
      costo_domicilio: string | null;
    }>(
      `SELECT receta_id, costo_calculado, costo_domicilio FROM productos
       WHERE id = $1 AND sucursal_id = $2`,
      [productoId, sucursalId],
    );
    if (!producto) throw new NotFoundException('PRODUCTO_NO_ENCONTRADO');
    if (!producto.receta_id) {
      return {
        producto_id: productoId,
        tipo_entidad: 'producto',
        receta_id: null,
        items: [],
        margen_error: 0.05,
        costo_calculado: producto.costo_calculado,
        costo_domicilio: producto.costo_domicilio,
      };
    }

    const receta = await this.database.consultarUno<{ margen_error: string }>(
      `SELECT margen_error FROM recetas WHERE id = $1 AND sucursal_id = $2`,
      [producto.receta_id, sucursalId],
    );

    const items = await this.database.consultar(
      `SELECT ri.id, ri.tipo_item, ri.ingrediente_id, i.nombre AS ingrediente_nombre,
              ri.subreceta_id, sr.nombre AS subreceta_nombre,
              ri.cantidad, ri.unidad, ri.orden
       FROM receta_items ri
       LEFT JOIN ingredientes i ON i.id = ri.ingrediente_id
       LEFT JOIN recetas sr ON sr.id = ri.subreceta_id
       WHERE ri.receta_id = $1
       ORDER BY ri.orden ASC`,
      [producto.receta_id],
    );

    return {
      producto_id: productoId,
      tipo_entidad: 'producto',
      receta_id: producto.receta_id,
      margen_error: Number(receta?.margen_error ?? 0.05),
      costo_calculado: producto.costo_calculado,
      costo_domicilio: producto.costo_domicilio,
      items,
    };
  }

  private async recetaDeExtra(
    extraId: string,
    sucursalId: string,
    tipo: 'bebida' | 'topping',
  ) {
    const tabla = tipo === 'bebida' ? 'bebidas' : 'toppings';
    const fila = await this.database.consultarUno<{
      receta_id: string | null;
      costo_calculado: string | null;
    }>(
      `SELECT receta_id, costo_calculado FROM ${tabla}
       WHERE id = $1 AND sucursal_id = $2`,
      [extraId, sucursalId],
    );
    if (!fila) {
      throw new NotFoundException(
        tipo === 'bebida' ? 'BEBIDA_NO_ENCONTRADA' : 'TOPPING_NO_ENCONTRADO',
      );
    }
    if (!fila.receta_id) {
      return {
        producto_id: extraId,
        tipo_entidad: tipo,
        receta_id: null,
        items: [],
        margen_error: 0.05,
        costo_calculado: fila.costo_calculado,
      };
    }

    const receta = await this.database.consultarUno<{ margen_error: string }>(
      `SELECT margen_error FROM recetas WHERE id = $1 AND sucursal_id = $2`,
      [fila.receta_id, sucursalId],
    );

    const items = await this.database.consultar(
      `SELECT ri.id, ri.tipo_item, ri.ingrediente_id, i.nombre AS ingrediente_nombre,
              ri.subreceta_id, sr.nombre AS subreceta_nombre,
              ri.cantidad, ri.unidad, ri.orden
       FROM receta_items ri
       LEFT JOIN ingredientes i ON i.id = ri.ingrediente_id
       LEFT JOIN recetas sr ON sr.id = ri.subreceta_id
       WHERE ri.receta_id = $1
       ORDER BY ri.orden ASC`,
      [fila.receta_id],
    );

    return {
      producto_id: extraId,
      tipo_entidad: tipo,
      receta_id: fila.receta_id,
      margen_error: Number(receta?.margen_error ?? 0.05),
      costo_calculado: fila.costo_calculado,
      items,
    };
  }

  configurarRecetaProducto(
    dto: ConfigurarRecetaProductoDto,
    sucursalId: string,
  ) {
    const tipo = dto.tipo_entidad ?? 'producto';
    if (tipo === 'bebida' || tipo === 'topping') {
      return this.configurarRecetaExtra(dto, sucursalId, tipo);
    }
    return this.database.enTransaccion(async (client) => {
      const producto = await client.query<{
        id: string;
        nombre: string;
        receta_id: string | null;
      }>(
        `SELECT id, nombre, receta_id FROM productos
         WHERE id = $1 AND sucursal_id = $2`,
        [dto.producto_id, sucursalId],
      );
      if (!producto.rows[0]) {
        throw new NotFoundException('PRODUCTO_NO_ENCONTRADO');
      }
      const fila = producto.rows[0];

      let recetaId = fila.receta_id;
      if (!recetaId) {
        const nueva = await client.query<{ id: string }>(
          `INSERT INTO recetas (sucursal_id, nombre, tipo, rendimiento_porciones)
           VALUES ($1,$2,'producto',1)
           RETURNING id`,
          [sucursalId, `Receta ${fila.nombre}`],
        );
        recetaId = nueva.rows[0].id;
        await client.query(
          `UPDATE productos SET receta_id = $1 WHERE id = $2 AND sucursal_id = $3`,
          [recetaId, dto.producto_id, sucursalId],
        );
      }

      if (dto.margen_error !== undefined) {
        await client.query(
          `UPDATE recetas SET margen_error = $1, tipo = 'producto'
           WHERE id = $2 AND sucursal_id = $3`,
          [dto.margen_error, recetaId, sucursalId],
        );
      }

      await client.query(`DELETE FROM receta_items WHERE receta_id = $1`, [
        recetaId,
      ]);

      let orden = 0;
      for (const item of dto.items) {
        const tipoItem = item.tipo_item ?? 'ingrediente';
        if (tipoItem === 'subreceta') {
          if (!item.subreceta_id) {
            throw new BadRequestException('SUBRECETA_REQUERIDA');
          }
          const sr = await client.query<{ unidad_resultado: string }>(
            `SELECT unidad_resultado FROM recetas
             WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`,
            [item.subreceta_id, sucursalId],
          );
          if (!sr.rows[0]) {
            throw new NotFoundException('SUBRECETA_NO_ENCONTRADA');
          }
          exigirUnidadesCompatibles(
            item.unidad,
            sr.rows[0].unidad_resultado,
            `Receta de ${fila.nombre}`,
          );
          await client.query(
            `INSERT INTO receta_items (
               receta_id, tipo_item, subreceta_id, cantidad, unidad, orden
             ) VALUES ($1,'subreceta',$2,$3,$4,$5)`,
            [
              recetaId,
              item.subreceta_id,
              item.cantidad,
              normalizarUnidad(item.unidad),
              orden++,
            ],
          );
        } else {
          if (!item.ingrediente_id) {
            throw new BadRequestException('INGREDIENTE_REQUERIDO');
          }
          const ing = await this.exigirIngrediente(
            client,
            item.ingrediente_id,
            sucursalId,
          );
          exigirUnidadesCompatibles(
            item.unidad,
            ing.unidad_base,
            `Receta de ${fila.nombre}`,
          );
          await client.query(
            `INSERT INTO receta_items (
               receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden
             ) VALUES ($1,$2,$3,$4,$5,$6)`,
            [
              recetaId,
              tipoItem,
              item.ingrediente_id,
              item.cantidad,
              normalizarUnidad(item.unidad),
              orden++,
            ],
          );
        }
      }

      const costoPorcion = await this.costeo.recalcularProducto(
        client,
        dto.producto_id,
        sucursalId,
      );

      return {
        producto_id: dto.producto_id,
        tipo_entidad: 'producto',
        receta_id: recetaId,
        costo_calculado: costoPorcion,
        items: dto.items.length,
      };
    });
  }

  private configurarRecetaExtra(
    dto: ConfigurarRecetaProductoDto,
    sucursalId: string,
    tipo: 'bebida' | 'topping',
  ) {
    const tabla = tipo === 'bebida' ? 'bebidas' : 'toppings';
    const tipoReceta = tipo;
    return this.database.enTransaccion(async (client) => {
      const extra = await client.query<{
        id: string;
        nombre: string;
        receta_id: string | null;
      }>(
        `SELECT id, nombre, receta_id FROM ${tabla}
         WHERE id = $1 AND sucursal_id = $2`,
        [dto.producto_id, sucursalId],
      );
      if (!extra.rows[0]) {
        throw new NotFoundException(
          tipo === 'bebida' ? 'BEBIDA_NO_ENCONTRADA' : 'TOPPING_NO_ENCONTRADO',
        );
      }
      const fila = extra.rows[0];

      let recetaId = fila.receta_id;
      if (!recetaId) {
        const nueva = await client.query<{ id: string }>(
          `INSERT INTO recetas (sucursal_id, nombre, tipo, rendimiento_porciones)
           VALUES ($1,$2,$3,1)
           RETURNING id`,
          [sucursalId, `Receta ${fila.nombre}`, tipoReceta],
        );
        recetaId = nueva.rows[0].id;
        await client.query(
          `UPDATE ${tabla} SET receta_id = $1 WHERE id = $2 AND sucursal_id = $3`,
          [recetaId, dto.producto_id, sucursalId],
        );
      }

      if (dto.margen_error !== undefined) {
        await client.query(
          `UPDATE recetas SET margen_error = $1, tipo = $2
           WHERE id = $3 AND sucursal_id = $4`,
          [dto.margen_error, tipoReceta, recetaId, sucursalId],
        );
      }

      await client.query(`DELETE FROM receta_items WHERE receta_id = $1`, [
        recetaId,
      ]);

      let orden = 0;
      for (const item of dto.items) {
        const tipoItem = item.tipo_item ?? 'ingrediente';
        if (tipoItem === 'subreceta') {
          if (!item.subreceta_id) {
            throw new BadRequestException('SUBRECETA_REQUERIDA');
          }
          const sr = await client.query<{ unidad_resultado: string }>(
            `SELECT unidad_resultado FROM recetas
             WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`,
            [item.subreceta_id, sucursalId],
          );
          if (!sr.rows[0]) {
            throw new NotFoundException('SUBRECETA_NO_ENCONTRADA');
          }
          exigirUnidadesCompatibles(
            item.unidad,
            sr.rows[0].unidad_resultado,
            `Receta de ${fila.nombre}`,
          );
          await client.query(
            `INSERT INTO receta_items (
               receta_id, tipo_item, subreceta_id, cantidad, unidad, orden
             ) VALUES ($1,'subreceta',$2,$3,$4,$5)`,
            [
              recetaId,
              item.subreceta_id,
              item.cantidad,
              normalizarUnidad(item.unidad),
              orden++,
            ],
          );
        } else {
          if (!item.ingrediente_id) {
            throw new BadRequestException('INGREDIENTE_REQUERIDO');
          }
          const ing = await this.exigirIngrediente(
            client,
            item.ingrediente_id,
            sucursalId,
          );
          exigirUnidadesCompatibles(
            item.unidad,
            ing.unidad_base,
            `Receta de ${fila.nombre}`,
          );
          await client.query(
            `INSERT INTO receta_items (
               receta_id, tipo_item, ingrediente_id, cantidad, unidad, orden
             ) VALUES ($1,$2,$3,$4,$5,$6)`,
            [
              recetaId,
              tipoItem,
              item.ingrediente_id,
              item.cantidad,
              normalizarUnidad(item.unidad),
              orden++,
            ],
          );
        }
      }

      const costoPorcion = await this.costeo.recalcularExtra(
        client,
        tipo,
        dto.producto_id,
        sucursalId,
      );

      return {
        producto_id: dto.producto_id,
        tipo_entidad: tipo,
        receta_id: recetaId,
        costo_calculado: costoPorcion,
        items: dto.items.length,
      };
    });
  }

  async iniciarConteo(sucursalId: string, usuarioId: string) {
    const activo = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM conteos_inventario
       WHERE sucursal_id = $1 AND estado = 'en_proceso'
       LIMIT 1`,
      [sucursalId],
    );
    if (activo) {
      return { conteo_id: activo.id, reutilizado: true };
    }

    const fila = await this.database.consultarUno<{ id: string }>(
      `INSERT INTO conteos_inventario (sucursal_id, usuario_id, estado)
       VALUES ($1,$2,'en_proceso')
       RETURNING id`,
      [sucursalId, usuarioId],
    );
    return { conteo_id: fila!.id, reutilizado: false };
  }

  cerrarConteo(
    conteoId: string,
    sucursalId: string,
    usuarioId: string,
    dto: CerrarConteoDto,
  ) {
    return this.database.enTransaccion(async (client) => {
      const conteo = await client.query<{ id: string; estado: string }>(
        `SELECT id, estado FROM conteos_inventario
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [conteoId, sucursalId],
      );
      if (!conteo.rows[0]) {
        throw new NotFoundException('CONTEO_NO_ENCONTRADO');
      }
      if (conteo.rows[0].estado !== 'en_proceso') {
        throw new BadRequestException('El conteo ya fue cerrado');
      }

      let ajustes = 0;
      const ingredientesAfectados: string[] = [];
      for (const item of dto.items) {
        const ing = await this.exigirIngrediente(
          client,
          item.ingrediente_id,
          sucursalId,
        );
        const teorico = Number(ing.stock_actual);
        const real = item.cantidad_real;
        const diferencia = real - teorico;

        await client.query(
          `INSERT INTO conteo_items (
             conteo_id, ingrediente_id, cantidad_teorica, cantidad_real
           ) VALUES ($1,$2,$3,$4)`,
          [conteoId, item.ingrediente_id, teorico, real],
        );

        if (diferencia !== 0) {
          await this.stockMovimiento.aplicarMovimiento({
            client,
            sucursalId,
            ingredienteId: item.ingrediente_id,
            tipo: 'conteo',
            cantidad: Math.abs(diferencia),
            stockAnterior: teorico,
            stockPosterior: real,
            motivo: `Conteo físico ${conteoId}`,
            usuarioId,
          });
          ajustes++;
          ingredientesAfectados.push(item.ingrediente_id);
        }
      }

      await client.query(
        `UPDATE conteos_inventario
         SET estado = 'cerrado', cerrado_at = now()
         WHERE id = $1`,
        [conteoId],
      );

      return {
        conteo_id: conteoId,
        items: dto.items.length,
        ajustes,
        ingredientesAfectados,
      };
    }).then(async (result) => {
      await this.sincronizarCatalogoPorIngredientes(
        sucursalId,
        result.ingredientesAfectados,
      );
      return {
        conteo_id: result.conteo_id,
        items: result.items,
        ajustes: result.ajustes,
      };
    });
  }

  /** Propaga stock de ingredientes al menú (disponibilidad + Realtime). */
  private async sincronizarCatalogoPorIngredientes(
    sucursalId: string,
    ingredienteIds: string[],
  ) {
    const unicos = [...new Set(ingredienteIds)];
    if (!unicos.length) return;

    const todosCambios: Awaited<
      ReturnType<CatalogoDisponibilidadService['sincronizarPorIngrediente']>
    > = [];
    for (const ingId of unicos) {
      const cambios = await this.catalogoDisponibilidad.sincronizarPorIngrediente(
        sucursalId,
        ingId,
      );
      todosCambios.push(...cambios);
    }
    if (todosCambios.length) {
      this.catalogoDisponibilidad.emitirCambios(sucursalId, todosCambios);
    }
  }

  listarCostosProductos(sucursalId: string) {
    return this.costeo.resumenSucursal(sucursalId).then((r) => r.productos);
  }

  listarTraslados(restauranteId: string, sucursalId?: string) {
    const params: unknown[] = [restauranteId];
    let filtroSucursal = '';
    if (sucursalId) {
      filtroSucursal =
        ' AND (t.sucursal_origen_id = $2 OR t.sucursal_destino_id = $2)';
      params.push(sucursalId);
    }
    return this.database.consultar(
      `       SELECT t.id, t.estado, t.cantidad, t.motivo, t.created_at, t.recibido_at,
              t.sucursal_origen_id, t.sucursal_destino_id,
              io.nombre AS ingrediente_nombre, io.unidad_base,
              so.nombre AS sucursal_origen, sd.nombre AS sucursal_destino,
              u.nombre AS usuario_nombre
       FROM traslados_inventario t
       INNER JOIN ingredientes io ON io.id = t.ingrediente_id
       INNER JOIN sucursales so ON so.id = t.sucursal_origen_id
       INNER JOIN sucursales sd ON sd.id = t.sucursal_destino_id
       LEFT JOIN usuarios u ON u.id = t.usuario_id
       WHERE t.restaurante_id = $1${filtroSucursal}
       ORDER BY t.created_at DESC
       LIMIT 100`,
      params,
    );
  }

  crearTraslado(actor: JwtPayload, dto: CrearTrasladoDto) {
    this.assertPuedeTrasladosMultiSucursal(actor);
    const restauranteId = actor.restaurante_id!;
    const usuarioId = actor.sub;
    if (dto.sucursal_origen_id === dto.sucursal_destino_id) {
      throw new BadRequestException('ORIGEN_IGUAL_DESTINO');
    }

    return this.database.enTransaccion(async (client) => {
      const sucursales = await client.query<{ id: string }>(
        `SELECT id FROM sucursales
         WHERE restaurante_id = $1 AND activa = true
           AND id = ANY($2::uuid[])`,
        [restauranteId, [dto.sucursal_origen_id, dto.sucursal_destino_id]],
      );
      if (sucursales.rows.length < 2) {
        throw new BadRequestException('SUCURSALES_INVALIDAS');
      }

      const origen = await this.exigirIngrediente(
        client,
        dto.ingrediente_id,
        dto.sucursal_origen_id,
      );
      const stockAnterior = Number(origen.stock_actual);
      if (stockAnterior < dto.cantidad) {
        throw new BadRequestException('STOCK_INSUFICIENTE_TRASLADO');
      }
      const stockPosterior = stockAnterior - dto.cantidad;

      const destinoIng = await client.query<{ id: string }>(
        `SELECT id FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true
           AND LOWER(nombre) = LOWER($2)
         LIMIT 1`,
        [dto.sucursal_destino_id, origen.nombre],
      );
      if (!destinoIng.rows[0]) {
        throw new BadRequestException({
          error: 'INGREDIENTE_DESTINO_NO_ENCONTRADO',
          message: `No existe «${origen.nombre}» en la sucursal destino`,
        });
      }

      await this.stockMovimiento.aplicarMovimiento({
        client,
        sucursalId: dto.sucursal_origen_id,
        ingredienteId: dto.ingrediente_id,
        tipo: 'ajuste',
        cantidad: dto.cantidad,
        stockAnterior,
        stockPosterior,
        motivo: `Traslado saliente → ${dto.sucursal_destino_id}`,
        usuarioId,
      });

      const traslado = await client.query<{ id: string }>(
        `INSERT INTO traslados_inventario (
           restaurante_id, sucursal_origen_id, sucursal_destino_id,
           ingrediente_id, cantidad, usuario_id, motivo
         ) VALUES ($1,$2,$3,$4,$5,$6,$7)
         RETURNING id`,
        [
          restauranteId,
          dto.sucursal_origen_id,
          dto.sucursal_destino_id,
          dto.ingrediente_id,
          dto.cantidad,
          usuarioId,
          dto.motivo ?? null,
        ],
      );

      await client.query(
        `INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues
         ) VALUES ($1,$2,'CREAR_TRASLADO','traslados_inventario',$3,$4::jsonb)`,
        [
          dto.sucursal_origen_id,
          usuarioId,
          traslado.rows[0].id,
          JSON.stringify({
            destino: dto.sucursal_destino_id,
            ingrediente: origen.nombre,
            cantidad: dto.cantidad,
          }),
        ],
      );

      return {
        traslado_id: traslado.rows[0].id,
        ingrediente_destino_id: destinoIng.rows[0].id,
        estado: 'pendiente',
      };
    });
  }

  recibirTraslado(
    trasladoId: string,
    restauranteId: string,
    sucursalDestinoId: string,
    usuarioId: string,
  ) {
    return this.database.enTransaccion(async (client) => {
      const t = await client.query<{
        id: string;
        estado: string;
        cantidad: string;
        ingrediente_id: string;
        sucursal_destino_id: string;
        nombre: string;
      }>(
        `SELECT t.id, t.estado, t.cantidad, t.ingrediente_id, t.sucursal_destino_id,
                i.nombre
         FROM traslados_inventario t
         INNER JOIN ingredientes i ON i.id = t.ingrediente_id
         WHERE t.id = $1 AND t.restaurante_id = $2 FOR UPDATE`,
        [trasladoId, restauranteId],
      );
      const fila = t.rows[0];
      if (!fila) throw new NotFoundException('TRASLADO_NO_ENCONTRADO');
      if (fila.sucursal_destino_id !== sucursalDestinoId) {
        throw new BadRequestException('TRASLADO_OTRA_SUCURSAL');
      }
      if (fila.estado !== 'pendiente') {
        throw new BadRequestException('TRASLADO_YA_CERRADO');
      }

      const destinoIng = await client.query<{
        id: string;
        stock_actual: string;
      }>(
        `SELECT id, stock_actual FROM ingredientes
         WHERE sucursal_id = $1 AND activo = true
           AND LOWER(nombre) = LOWER($2)
         LIMIT 1`,
        [sucursalDestinoId, fila.nombre],
      );
      if (!destinoIng.rows[0]) {
        throw new BadRequestException('INGREDIENTE_DESTINO_NO_ENCONTRADO');
      }

      const cantidad = Number(fila.cantidad);
      const stockAnterior = Number(destinoIng.rows[0].stock_actual);
      const stockPosterior = stockAnterior + cantidad;

      await this.stockMovimiento.aplicarMovimiento({
        client,
        sucursalId: sucursalDestinoId,
        ingredienteId: destinoIng.rows[0].id,
        tipo: 'compra',
        cantidad,
        stockAnterior,
        stockPosterior,
        motivo: `Traslado recibido ${trasladoId}`,
        usuarioId,
      });

      await client.query(
        `UPDATE traslados_inventario
         SET estado = 'recibido', recibido_at = now()
         WHERE id = $1`,
        [trasladoId],
      );

      await client.query(
        `INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id
         ) VALUES ($1,$2,'RECIBIR_TRASLADO','traslados_inventario',$3)`,
        [sucursalDestinoId, usuarioId, trasladoId],
      );

      return { traslado_id: trasladoId, estado: 'recibido' };
    });
  }

  cancelarTraslado(
    trasladoId: string,
    actor: JwtPayload,
    sucursalOrigenId: string,
  ) {
    this.assertPuedeTrasladosMultiSucursal(actor);
    const restauranteId = actor.restaurante_id!;
    const usuarioId = actor.sub;
    return this.database.enTransaccion(async (client) => {
      const t = await client.query<{
        id: string;
        estado: string;
        cantidad: string;
        ingrediente_id: string;
        sucursal_origen_id: string;
      }>(
        `SELECT id, estado, cantidad, ingrediente_id, sucursal_origen_id
         FROM traslados_inventario
         WHERE id = $1 AND restaurante_id = $2 FOR UPDATE`,
        [trasladoId, restauranteId],
      );
      const fila = t.rows[0];
      if (!fila) throw new NotFoundException('TRASLADO_NO_ENCONTRADO');
      if (fila.sucursal_origen_id !== sucursalOrigenId) {
        throw new BadRequestException('TRASLADO_OTRA_SUCURSAL');
      }
      if (fila.estado !== 'pendiente') {
        throw new BadRequestException('TRASLADO_YA_CERRADO');
      }

      const origen = await this.exigirIngrediente(
        client,
        fila.ingrediente_id,
        sucursalOrigenId,
      );
      const cantidad = Number(fila.cantidad);
      const stockAnterior = Number(origen.stock_actual);
      const stockPosterior = stockAnterior + cantidad;

      await this.stockMovimiento.aplicarMovimiento({
        client,
        sucursalId: sucursalOrigenId,
        ingredienteId: fila.ingrediente_id,
        tipo: 'ajuste',
        cantidad,
        stockAnterior,
        stockPosterior,
        motivo: `Traslado cancelado ${trasladoId}`,
        usuarioId,
      });

      await client.query(
        `UPDATE traslados_inventario SET estado = 'cancelado' WHERE id = $1`,
        [trasladoId],
      );

      await client.query(
        `INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id
         ) VALUES ($1,$2,'CANCELAR_TRASLADO','traslados_inventario',$3)`,
        [sucursalOrigenId, usuarioId, trasladoId],
      );

      return { traslado_id: trasladoId, estado: 'cancelado' };
    });
  }

  private async exigirIngrediente(
    client: PoolClient,
    id: string,
    sucursalId: string,
  ) {
    const fila = await client.query<{
      id: string;
      nombre: string;
      stock_actual: string;
      stock_minimo: string;
      costo_unitario_actual: string;
      unidad_base: string;
      precio_compra: string | null;
      peso_bruto: string | null;
      peso_neto: string | null;
    }>(
      `SELECT id, nombre, stock_actual, stock_minimo, costo_unitario_actual,
              unidad_base, precio_compra, peso_bruto, peso_neto
       FROM ingredientes
       WHERE id = $1 AND sucursal_id = $2 AND activo = true
       FOR UPDATE`,
      [id, sucursalId],
    );
    if (!fila.rows[0]) {
      throw new NotFoundException('INGREDIENTE_NO_ENCONTRADO');
    }
    return fila.rows[0];
  }

  private async exigirSubreceta(
    client: PoolClient,
    id: string,
    sucursalId: string,
  ) {
    const fila = await client.query<{ id: string }>(
      `SELECT id FROM recetas
       WHERE id = $1 AND sucursal_id = $2 AND tipo = 'subreceta'`,
      [id, sucursalId],
    );
    if (!fila.rows[0]) {
      throw new NotFoundException('SUBRECETA_NO_ENCONTRADA');
    }
    return fila.rows[0];
  }

  private async obtenerIngrediente(
    client: PoolClient,
    id: string,
    sucursalId: string,
  ) {
    const fila = await client.query(
      `SELECT id, nombre, unidad_base, stock_actual, stock_minimo,
              costo_unitario_actual, descontar_stock, proveedor,
              precio_compra, peso_bruto, peso_neto, categoria_insumo,
              rendimiento_porcentaje
       FROM ingredientes WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!fila.rows[0]) {
      throw new NotFoundException('INGREDIENTE_NO_ENCONTRADO');
    }
    return fila.rows[0];
  }
}
