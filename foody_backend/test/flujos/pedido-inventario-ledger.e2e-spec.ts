import { Pool } from 'pg';
import {
  api,
  assertApiViva,
  crearPedidoStaff,
  itemBody,
  limpiarPedidosActivos,
  login,
  pedidoId,
  PRODUCTO,
  setEstado,
  SID,
  TokenBundle,
  E2E_HOST,
} from '../helpers/foody-e2e';

describe('E2E ledger de inventario por pedido', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;
  let database: Pool;

  beforeAll(async () => {
    await assertApiViva();

    const apiUrl = new URL(E2E_HOST);
    const databaseUrl = process.env.DATABASE_URL;
    const dbName = databaseUrl
      ? decodeURIComponent(new URL(databaseUrl).pathname.replace(/^\//, ''))
      : '';
    if (
      !['127.0.0.1', 'localhost'].includes(apiUrl.hostname) ||
      apiUrl.port !== '3001' ||
      process.env.FOODY_QA_SIN_EFECTOS !== '1' ||
      !/^foody_diseno_qa_codex_ledger[a-zA-Z0-9_]+$/.test(dbName)
    ) {
      throw new Error(
        'El E2E de ledger requiere API localhost:3001, FOODY_QA_SIN_EFECTOS=1 y una DB clon foody_diseno_qa_codex_ledger_*.',
      );
    }

    database = new Pool({ connectionString: databaseUrl });
    admin = await login('admin@foody.demo');
    cajero = await login('cajero.test@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
  });

  afterAll(async () => {
    await database?.end();
  });

  it('liga el consumo a la línea y repone exactamente una vez al cancelar antes de cocina', async () => {
    const disponible = await api()
      .patch(`/api/v1/productos/${PRODUCTO}/disponibilidad`)
      .set(admin.auth)
      .send({ disponible: true });
    expect(disponible.body.exito).toBe(true);

    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-stock-ledger-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    const lineas = await database.query<{
      id: string;
      stock_snapshot_version: number | null;
    }>(
      `SELECT id, stock_snapshot_version FROM pedido_items WHERE pedido_id = $1`,
      [id],
    );
    expect(lineas.rows).toHaveLength(1);
    expect(lineas.rows[0].stock_snapshot_version).toBe(1);

    const ventas = await database.query<{
      ingrediente_id: string;
      pedido_item_id: string;
      cantidad: string;
    }>(
      `SELECT ingrediente_id, pedido_item_id, SUM(cantidad)::text AS cantidad
       FROM movimientos_ingrediente
       WHERE pedido_id = $1 AND sucursal_id = $2 AND tipo = 'venta'
       GROUP BY ingrediente_id, pedido_item_id`,
      [id, SID],
    );
    expect(ventas.rows.length).toBeGreaterThan(0);
    expect(
      ventas.rows.every((row) => row.pedido_item_id === lineas.rows[0].id),
    ).toBe(true);

    // Simula un pedido legacy en estado confirmado antes del ingreso a Cocina.
    // Su ítem sigue pendiente, por lo que cancelar debe devolver stock, no merma.
    await database.query(
      `UPDATE pedidos SET estado = 'confirmado' WHERE id = $1`,
      [id],
    );
    const cancelado = await setEstado(admin.auth, id, 'cancelado', {
      motivo: 'QA verifica devolución exacta de inventario',
    });
    expect(cancelado.body.exito).toBe(true);

    const saldo = await database.query<{
      ingrediente_id: string;
      vendido: string;
      devuelto: string;
      mermado: string;
    }>(
      `SELECT ingrediente_id,
              COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'venta'), 0)::text AS vendido,
              COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'devolucion'), 0)::text AS devuelto,
              COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'merma'), 0)::text AS mermado
       FROM movimientos_ingrediente
       WHERE pedido_id = $1 AND sucursal_id = $2
       GROUP BY ingrediente_id`,
      [id, SID],
    );
    expect(saldo.rows.length).toBe(ventas.rows.length);
    for (const row of saldo.rows) {
      expect(Number(row.devuelto)).toBeCloseTo(Number(row.vendido), 6);
      expect(Number(row.mermado)).toBe(0);
    }

    const devolucionesAntesDelReintento = await database.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM movimientos_ingrediente
       WHERE pedido_id = $1 AND sucursal_id = $2 AND tipo = 'devolucion'`,
      [id, SID],
    );
    const reintento = await setEstado(admin.auth, id, 'cancelado', {
      motivo: 'QA reintento de cancelación',
    });
    expect(reintento.body.exito).toBe(true);

    const devolucionesTrasReintento = await database.query<{ n: string }>(
      `SELECT COUNT(*)::text AS n FROM movimientos_ingrediente
       WHERE pedido_id = $1 AND sucursal_id = $2 AND tipo = 'devolucion'`,
      [id, SID],
    );
    expect(devolucionesTrasReintento.rows[0]?.n).toBe(
      devolucionesAntesDelReintento.rows[0]?.n,
    );
  });

  it('reduce cantidad antes de cocina usando el consumo snapshot aunque la receta cambie', async () => {
    const receta = await database.query<{
      id: string;
      receta_id: string;
      cantidad: string;
    }>(
      `SELECT ri.id, ri.receta_id, ri.cantidad::text
       FROM productos p
       JOIN receta_items ri ON ri.receta_id = p.receta_id
       WHERE p.id = $1 AND p.sucursal_id = $2
         AND ri.tipo_item = 'ingrediente'
       ORDER BY ri.orden, ri.id LIMIT 1`,
      [PRODUCTO, SID],
    );
    expect(receta.rows).toHaveLength(1);
    const recetaOriginal = Number(receta.rows[0].cantidad);
    let pedidoCreado: string | null = null;

    try {
      const crear = await crearPedidoStaff(cajero.auth, {
        sucursal_id: SID,
        tipo: 'para_llevar',
        device_id: `jest-stock-snapshot-${Date.now()}`,
        metodo_pago: 'pendiente',
        items: [itemBody(2)],
      });
      expect(crear.body.exito).toBe(true);
      pedidoCreado = pedidoId(crear);
      const item = await database.query<{ id: string }>(
        `SELECT id FROM pedido_items WHERE pedido_id = $1`,
        [pedidoCreado],
      );
      expect(item.rows).toHaveLength(1);

      const consumos = await database.query<{
        ingrediente_id: string;
        cantidad: string;
      }>(
        `SELECT ingrediente_id, SUM(cantidad)::text AS cantidad
         FROM pedido_item_stock_ledger
         WHERE pedido_id = $1 AND pedido_item_id_original = $2
           AND tipo_componente = 'producto' AND evento = 'consumo'
         GROUP BY ingrediente_id`,
        [pedidoCreado, item.rows[0].id],
      );
      expect(consumos.rows.length).toBeGreaterThan(0);

      // Si el servicio reexpande la receta actual, devolvería diez veces el snapshot.
      await database.query(
        `UPDATE receta_items SET cantidad = $1 WHERE id = $2`,
        [recetaOriginal * 10, receta.rows[0].id],
      );
      const editar = await api()
        .patch(`/api/v1/pedidos/${pedidoCreado}/items/${item.rows[0].id}`)
        .query({ sucursal_id: SID })
        .set(admin.auth)
        .send({ cantidad: 1 });
      expect(editar.body.exito).toBe(true);

      const devoluciones = await database.query<{
        ingrediente_id: string;
        cantidad: string;
      }>(
        `SELECT ingrediente_id, SUM(cantidad)::text AS cantidad
         FROM pedido_item_stock_ledger
         WHERE pedido_id = $1 AND pedido_item_id_original = $2
           AND tipo_componente = 'producto' AND evento = 'devolucion'
         GROUP BY ingrediente_id`,
        [pedidoCreado, item.rows[0].id],
      );
      expect(devoluciones.rows).toHaveLength(consumos.rows.length);
      for (const consumo of consumos.rows) {
        const devolucion = devoluciones.rows.find(
          (fila) => fila.ingrediente_id === consumo.ingrediente_id,
        );
        expect(Number(devolucion?.cantidad ?? 0)).toBeCloseTo(
          Number(consumo.cantidad) / 2,
          4,
        );
      }
    } finally {
      await database.query(
        `UPDATE receta_items SET cantidad = $1 WHERE id = $2`,
        [recetaOriginal, receta.rows[0].id],
      );
      if (pedidoCreado) {
        await setEstado(admin.auth, pedidoCreado, 'cancelado', {
          motivo: 'QA limpia pedido de edición por snapshot',
        });
      }
    }
  });

  it('reemplaza toppings antes de cocina y devuelve el stock del topping desde su snapshot', async () => {
    const toppingId = '20000000-0000-4000-8000-000000000001';
    const productoHamburguesa = 'f0000000-0000-4000-8000-000000000001';
    const topping = await database.query<{
      receta_id: string | null;
      nombre: string;
      precio: string;
    }>(`SELECT receta_id, nombre, precio::text FROM toppings WHERE id = $1`, [
      toppingId,
    ]);
    const recetaPapa = await database.query<{
      receta_id: string;
      ingrediente_id: string;
      cantidad: string;
      receta_item_id: string;
    }>(
      `SELECT r.id AS receta_id, ri.ingrediente_id, ri.cantidad::text,
              ri.id AS receta_item_id
       FROM recetas r JOIN receta_items ri ON ri.receta_id = r.id
       WHERE r.id = '41000000-0000-4000-8000-000000000002'
         AND ri.tipo_item = 'ingrediente'
       ORDER BY ri.orden LIMIT 1`,
    );
    expect(topping.rows).toHaveLength(1);
    expect(recetaPapa.rows).toHaveLength(1);
    const recetaOriginal = Number(recetaPapa.rows[0].cantidad);
    let pedidoCreado: string | null = null;

    try {
      await database.query(`UPDATE toppings SET receta_id = $1 WHERE id = $2`, [
        recetaPapa.rows[0].receta_id,
        toppingId,
      ]);
      const crear = await crearPedidoStaff(cajero.auth, {
        sucursal_id: SID,
        tipo: 'para_llevar',
        device_id: `jest-stock-topping-${Date.now()}`,
        metodo_pago: 'pendiente',
        items: [
          {
            producto_id: productoHamburguesa,
            cantidad: 1,
            precio: 18000,
            toppings: [{ topping_id: toppingId }],
          },
        ],
      });
      expect(crear.body.exito).toBe(true);
      pedidoCreado = pedidoId(crear);
      const item = await database.query<{ id: string }>(
        `SELECT id FROM pedido_items WHERE pedido_id = $1`,
        [pedidoCreado],
      );
      expect(item.rows).toHaveLength(1);
      const consumo = await database.query<{ cantidad: string }>(
        `SELECT SUM(cantidad)::text AS cantidad
         FROM pedido_item_stock_ledger
         WHERE pedido_id = $1 AND pedido_item_id_original = $2
           AND tipo_componente = 'topping' AND componente_id = $3
           AND evento = 'consumo'`,
        [pedidoCreado, item.rows[0].id, toppingId],
      );
      expect(Number(consumo.rows[0]?.cantidad ?? 0)).toBeGreaterThan(0);

      await database.query(
        `UPDATE receta_items SET cantidad = $1 WHERE id = $2`,
        [recetaOriginal * 10, recetaPapa.rows[0].receta_item_id],
      );
      const editar = await api()
        .patch(`/api/v1/pedidos/${pedidoCreado}/items/${item.rows[0].id}`)
        .query({ sucursal_id: SID })
        .set(admin.auth)
        .send({ toppings: [] });
      expect(editar.body.exito).toBe(true);

      const devolucion = await database.query<{ cantidad: string }>(
        `SELECT SUM(cantidad)::text AS cantidad
         FROM pedido_item_stock_ledger
         WHERE pedido_id = $1 AND pedido_item_id_original = $2
           AND tipo_componente = 'topping' AND componente_id = $3
           AND evento = 'devolucion'`,
        [pedidoCreado, item.rows[0].id, toppingId],
      );
      expect(Number(devolucion.rows[0]?.cantidad ?? 0)).toBeCloseTo(
        Number(consumo.rows[0].cantidad),
        4,
      );
      const toppingsActivos = await database.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM pedido_item_toppings WHERE pedido_item_id = $1`,
        [item.rows[0].id],
      );
      expect(toppingsActivos.rows[0]?.n).toBe('0');
    } finally {
      await database.query(
        `UPDATE receta_items SET cantidad = $1 WHERE id = $2`,
        [recetaOriginal, recetaPapa.rows[0].receta_item_id],
      );
      await database.query(`UPDATE toppings SET receta_id = $1 WHERE id = $2`, [
        topping.rows[0].receta_id,
        toppingId,
      ]);
      if (pedidoCreado) {
        await setEstado(admin.auth, pedidoCreado, 'cancelado', {
          motivo: 'QA limpia pedido de reemplazo de topping',
        });
      }
    }
  });

  it('elimina una línea pendiente devolviendo su consumo completo sin releer receta vigente', async () => {
    const receta = await database.query<{
      id: string;
      receta_id: string;
      cantidad: string;
    }>(
      `SELECT ri.id, ri.receta_id, ri.cantidad::text
       FROM productos p
       JOIN receta_items ri ON ri.receta_id = p.receta_id
       WHERE p.id = $1 AND p.sucursal_id = $2
         AND ri.tipo_item = 'ingrediente'
       ORDER BY ri.orden, ri.id LIMIT 1`,
      [PRODUCTO, SID],
    );
    expect(receta.rows).toHaveLength(1);
    const recetaOriginal = Number(receta.rows[0].cantidad);
    let pedidoCreado: string | null = null;

    try {
      const crear = await crearPedidoStaff(cajero.auth, {
        sucursal_id: SID,
        tipo: 'para_llevar',
        device_id: `jest-stock-delete-${Date.now()}`,
        metodo_pago: 'pendiente',
        items: [
          itemBody(1),
          {
            producto_id: 'f0000000-0000-4000-8000-000000000001',
            cantidad: 1,
            precio: 18000,
          },
        ],
      });
      expect(crear.body.exito).toBe(true);
      pedidoCreado = pedidoId(crear);
      const item = await database.query<{ id: string }>(
        `SELECT id FROM pedido_items WHERE pedido_id = $1 AND producto_id = $2`,
        [pedidoCreado, PRODUCTO],
      );
      expect(item.rows).toHaveLength(1);
      const consumos = await database.query<{
        ingrediente_id: string;
        cantidad: string;
      }>(
        `SELECT ingrediente_id, SUM(cantidad)::text AS cantidad
         FROM pedido_item_stock_ledger
         WHERE pedido_id = $1 AND pedido_item_id_original = $2
           AND evento = 'consumo'
         GROUP BY ingrediente_id`,
        [pedidoCreado, item.rows[0].id],
      );
      expect(consumos.rows.length).toBeGreaterThan(0);

      await database.query(
        `UPDATE receta_items SET cantidad = $1 WHERE id = $2`,
        [recetaOriginal * 10, receta.rows[0].id],
      );
      const eliminar = await api()
        .delete(`/api/v1/pedidos/${pedidoCreado}/items/${item.rows[0].id}`)
        .query({ sucursal_id: SID })
        .set(admin.auth)
        .send({ motivo: 'QA devuelve snapshot antes de cocina' });
      expect(eliminar.body.exito).toBe(true);

      const devoluciones = await database.query<{
        ingrediente_id: string;
        cantidad: string;
      }>(
        `SELECT ingrediente_id, SUM(cantidad)::text AS cantidad
         FROM pedido_item_stock_ledger
         WHERE pedido_id = $1 AND pedido_item_id_original = $2
           AND evento = 'devolucion'
         GROUP BY ingrediente_id`,
        [pedidoCreado, item.rows[0].id],
      );
      expect(devoluciones.rows).toHaveLength(consumos.rows.length);
      for (const consumo of consumos.rows) {
        const devolucion = devoluciones.rows.find(
          (fila) => fila.ingrediente_id === consumo.ingrediente_id,
        );
        expect(Number(devolucion?.cantidad ?? 0)).toBeCloseTo(
          Number(consumo.cantidad),
          4,
        );
      }
      const lineasRestantes = await database.query<{ n: string }>(
        `SELECT COUNT(*)::text AS n FROM pedido_items WHERE pedido_id = $1`,
        [pedidoCreado],
      );
      expect(lineasRestantes.rows[0]?.n).toBe('1');
    } finally {
      await database.query(
        `UPDATE receta_items SET cantidad = $1 WHERE id = $2`,
        [recetaOriginal, receta.rows[0].id],
      );
      if (pedidoCreado) {
        await setEstado(admin.auth, pedidoCreado, 'cancelado', {
          motivo: 'QA limpia pedido tras eliminar línea',
        });
      }
    }
  });

  it('no devuelve al cancelar el pedido una línea eliminada en cocina que ya quedó como merma', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-stock-waste-cancel-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [
        itemBody(1),
        {
          producto_id: 'f0000000-0000-4000-8000-000000000001',
          cantidad: 1,
          precio: 18000,
        },
      ],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const item = await database.query<{ id: string }>(
      `SELECT id FROM pedido_items WHERE pedido_id = $1 AND producto_id = $2`,
      [id, PRODUCTO],
    );
    expect(item.rows).toHaveLength(1);
    await database.query(
      `UPDATE pedidos SET estado = 'confirmado' WHERE id = $1`,
      [id],
    );
    await database.query(
      `UPDATE pedido_items SET estado_cocina = 'preparando' WHERE id = $1`,
      [item.rows[0].id],
    );

    const eliminado = await api()
      .delete(`/api/v1/pedidos/${id}/items/${item.rows[0].id}`)
      .query({ sucursal_id: SID })
      .set(admin.auth)
      .send({ motivo: 'QA descarta línea después de iniciar cocina' });
    expect(eliminado.body.exito).toBe(true);
    const mermasLinea = await database.query<{ ingrediente_id: string }>(
      `SELECT DISTINCT ingrediente_id FROM pedido_item_stock_ledger
       WHERE pedido_id = $1 AND pedido_item_id_original = $2 AND evento = 'merma'`,
      [id, item.rows[0].id],
    );
    expect(mermasLinea.rows.length).toBeGreaterThan(0);

    const cancelado = await setEstado(admin.auth, id, 'cancelado', {
      motivo: 'QA devuelve solo la línea que no fue merma',
    });
    expect(cancelado.body.exito).toBe(true);
    const saldos = await database.query<{
      ingrediente_id: string;
      vendido: string;
      devuelto: string;
      mermado: string;
    }>(
      `SELECT ingrediente_id,
              SUM(cantidad) FILTER (WHERE tipo = 'venta')::text AS vendido,
              COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'devolucion'), 0)::text AS devuelto,
              COALESCE(SUM(cantidad) FILTER (WHERE tipo = 'merma'), 0)::text AS mermado
       FROM movimientos_ingrediente WHERE pedido_id = $1 AND sucursal_id = $2
       GROUP BY ingrediente_id`,
      [id, SID],
    );
    expect(saldos.rows.length).toBeGreaterThan(0);
    for (const saldo of saldos.rows) {
      expect(Number(saldo.devuelto) + Number(saldo.mermado)).toBeCloseTo(
        Number(saldo.vendido),
        4,
      );
    }
  });
});
