import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { CosteoService } from '../costeo/costeo.service';

export type CambioDisponibilidadProducto = {
  producto_id: string;
  disponible: boolean;
};

/**
 * Recalcula productos.disponible según stock de ingredientes y emite Realtime al menú.
 */
@Injectable()
export class CatalogoDisponibilidadService {
  constructor(
    private readonly database: DatabaseService,
    private readonly costeo: CosteoService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly menuCache: MenuCacheService,
  ) {}

  /** Fuera de transacción — abre client propio. */
  async sincronizarPorIngrediente(
    sucursalId: string,
    ingredienteId: string,
  ): Promise<CambioDisponibilidadProducto[]> {
    return this.database.enTransaccion(async (client) =>
      this.sincronizarPorIngredienteEnTransaccion(
        client,
        sucursalId,
        ingredienteId,
      ),
    );
  }

  async sincronizarPorIngredienteEnTransaccion(
    client: PoolClient,
    sucursalId: string,
    ingredienteId: string,
  ): Promise<CambioDisponibilidadProducto[]> {
    const productos = await client.query<{ id: string }>(
      `WITH RECURSIVE recetas_relacionadas AS (
         -- Caso base: recetas que usan el ingrediente directamente
         SELECT DISTINCT receta_id
         FROM receta_items
         WHERE ingrediente_id = $2
         
         UNION
         
         -- Caso recursivo: recetas que usan una subreceta que usa el ingrediente
         SELECT ri.receta_id
         FROM receta_items ri
         INNER JOIN recetas_relacionadas rr ON rr.receta_id = ri.subreceta_id
         WHERE ri.tipo_item = 'subreceta'
       )
       SELECT DISTINCT p.id
       FROM productos p
       INNER JOIN recetas_relacionadas rr ON rr.receta_id = p.receta_id
       WHERE p.sucursal_id = $1
       UNION
       SELECT DISTINCT pii.producto_id AS id
       FROM producto_items_incluidos pii
       INNER JOIN productos pin ON pin.id = pii.producto_incluido_id
       INNER JOIN recetas_relacionadas rr ON rr.receta_id = pin.receta_id
       WHERE pii.sucursal_id = $1`,
      [sucursalId, ingredienteId],
    );

    const cambios: CambioDisponibilidadProducto[] = [];
    for (const row of productos.rows) {
      const cambio = await this.evaluarDisponibilidadProducto(
        client,
        sucursalId,
        row.id,
      );
      if (cambio) cambios.push(cambio);
    }
    return cambios;
  }

  emitirCambios(sucursalId: string, cambios: CambioDisponibilidadProducto[]) {
    if (!cambios.length) return;
    void this.menuCache.invalidar(sucursalId);
    const agotados = cambios.filter((c) => !c.disponible).map((c) => c.producto_id);
    const reactivados = cambios.filter((c) => c.disponible).map((c) => c.producto_id);
    if (agotados.length) {
      void this.realtime.catalogoDisponibilidad(sucursalId, {
        producto_ids: agotados,
        disponible: false,
      });
    }
    if (reactivados.length) {
      void this.realtime.catalogoDisponibilidad(sucursalId, {
        producto_ids: reactivados,
        disponible: true,
      });
    }
  }

  private async evaluarDisponibilidadProducto(
    client: PoolClient,
    sucursalId: string,
    productoId: string,
  ): Promise<CambioDisponibilidadProducto | null> {
    const actual = await client.query<{ disponible: boolean }>(
      `SELECT disponible FROM productos WHERE id = $1 AND sucursal_id = $2`,
      [productoId, sucursalId],
    );
    if (!actual.rows[0]) return null;

    const expandidos = await this.costeo.expandirIngredientesProducto(
      client,
      productoId,
      sucursalId,
      1,
      false,
    );
    if (!expandidos.length) return null;

    let hayStock = true;
    for (const uso of expandidos) {
      const ing = await client.query<{
        stock_actual: string;
        descontar_stock: boolean;
      }>(
        `SELECT stock_actual, descontar_stock FROM ingredientes
         WHERE id = $1 AND sucursal_id = $2`,
        [uso.ingrediente_id, sucursalId],
      );
      const fila = ing.rows[0];
      if (!fila?.descontar_stock) continue;
      if (Number(fila.stock_actual) < uso.cantidad - 1e-9) {
        hayStock = false;
        break;
      }
    }

    const nuevoDisponible = hayStock;
    if (actual.rows[0].disponible === nuevoDisponible) return null;

    await client.query(
      `UPDATE productos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`,
      [nuevoDisponible, productoId, sucursalId],
    );
    return { producto_id: productoId, disponible: nuevoDisponible };
  }
}
