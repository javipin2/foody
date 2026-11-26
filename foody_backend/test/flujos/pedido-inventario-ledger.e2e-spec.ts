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
});
