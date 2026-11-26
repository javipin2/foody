import { Pool } from 'pg';
import {
  api,
  assertApiViva,
  crearPedidoStaff,
  detallePedido,
  E2E_HOST,
  ensureCajaAbierta,
  limpiarDispositivosClienteE2e,
  login,
  limpiarPedidosActivos,
  mesaLibre,
  pedidoId,
  QR_TOKEN,
  registrarDispositivoCliente,
  SID,
  setEstado,
  TokenBundle,
} from '../helpers/foody-e2e';
import { randomUUID } from 'crypto';

describe('E2E decisión de combo en QA API/DB', () => {
  let database: Pool;
  let admin: TokenBundle;
  let cocina: TokenBundle;
  let cajero: TokenBundle;
  let combos: string[] = [];
  const pedidosQa: string[] = [];
  const cocinasQa: string[] = [];

  beforeAll(async () => {
    await assertApiViva();
    const host = new URL(E2E_HOST);
    const databaseUrl = process.env.DATABASE_URL;
    const databaseName = databaseUrl
      ? decodeURIComponent(new URL(databaseUrl).pathname.replace(/^\//, ''))
      : '';
    if (
      !['127.0.0.1', 'localhost'].includes(host.hostname) ||
      host.port !== '3001' ||
      process.env.FOODY_QA_SIN_EFECTOS !== '1' ||
      !/^foody_diseno_qa_codex_ledger[a-zA-Z0-9_]+$/.test(databaseName)
    ) {
      throw new Error(
        'El E2E de combos requiere API QA :3001, FOODY_QA_SIN_EFECTOS=1 y un clon desechable foody_diseno_qa_codex_ledger*.',
      );
    }
    database = new Pool({ connectionString: databaseUrl });
    admin = await login('admin@foody.demo');
    cocina = await login('cocina@foody.demo');
    cajero = await login('cajero.test@foody.demo');
  });

  afterAll(async () => {
    if (database) {
      const previos = await database.query<{ id: string }>(
        `SELECT DISTINCT p.id FROM pedidos p
         JOIN pedido_items i ON i.pedido_id = p.id
         JOIN pedido_combo_selecciones s ON s.pedido_item_id = i.id
         JOIN combos c ON c.id = s.combo_id
         WHERE c.nombre LIKE 'QA Combo decisión %'`,
      );
      const ids = [
        ...new Set([...pedidosQa, ...previos.rows.map((r) => r.id)]),
      ];
      for (const id of ids) {
        await database.query(
          'DELETE FROM pedido_combo_stock_ledger WHERE pedido_id = $1',
          [id],
        );
        await database.query(
          'DELETE FROM pedido_combo_decisiones_cliente WHERE pedido_id = $1',
          [id],
        );
        await database.query(
          'DELETE FROM pedido_combo_tareas_cocina WHERE pedido_id = $1',
          [id],
        );
        await database.query(
          'DELETE FROM pago_pedido_items WHERE pedido_item_id IN (SELECT id FROM pedido_items WHERE pedido_id = $1)',
          [id],
        );
        await database.query(
          'DELETE FROM pedido_item_toppings WHERE pedido_item_id IN (SELECT id FROM pedido_items WHERE pedido_id = $1)',
          [id],
        );
        await database.query(
          'DELETE FROM pedido_item_bebidas WHERE pedido_item_id IN (SELECT id FROM pedido_items WHERE pedido_id = $1)',
          [id],
        );
        await database.query(
          'DELETE FROM pedido_combo_selecciones WHERE pedido_item_id IN (SELECT id FROM pedido_items WHERE pedido_id = $1)',
          [id],
        );
        await database.query(
          'DELETE FROM margenes_venta WHERE pedido_id = $1',
          [id],
        );
        await database.query(
          'DELETE FROM movimientos_ingrediente WHERE pedido_id = $1',
          [id],
        );
        await database.query(
          'DELETE FROM movimientos_caja WHERE pedido_id = $1',
          [id],
        );
        await database.query(
          'DELETE FROM impresion_cocina_jobs WHERE pedido_id = $1',
          [id],
        );
        await database.query('DELETE FROM pagos_pedido WHERE pedido_id = $1', [
          id,
        ]);
        await database.query('DELETE FROM pedido_items WHERE pedido_id = $1', [
          id,
        ]);
        await database.query(
          'DELETE FROM estados_pedido_historial WHERE pedido_id = $1',
          [id],
        );
        await database.query(
          'DELETE FROM pedidos_idempotencia WHERE pedido_id = $1',
          [id],
        );
        await database.query('DELETE FROM pedidos WHERE id = $1', [id]);
      }
    }
    await database?.query(
      `DELETE FROM combo_items ci USING combos c
       WHERE ci.combo_id = c.id AND c.nombre LIKE 'QA Combo decisión %'`,
    );
    await database?.query(
      "DELETE FROM combos WHERE nombre LIKE 'QA Combo decisión %'",
    );
    if (cocinasQa.length) {
      await database?.query('DELETE FROM cocinas WHERE id = ANY($1::uuid[])', [
        cocinasQa,
      ]);
    }
    await limpiarDispositivosClienteE2e();
    await database?.end();
  });

  async function crearComboTemporal(productoIds?: string[]) {
    const productos = await database.query<{
      id: string;
      cocina_id: string;
    }>(
      `SELECT id, cocina_id FROM productos
       WHERE sucursal_id = $1 AND disponible = true
         AND (($2::uuid[] IS NULL AND nombre LIKE 'E2E Ruta Cocina %')
              OR id = ANY($2::uuid[]))
       ORDER BY id LIMIT 2`,
      [SID, productoIds ?? null],
    );
    if (productos.rows.length < 2 || !productos.rows[0].cocina_id) {
      throw new Error(
        'Faltan dos productos QA disponibles con cocina asignada.',
      );
    }
    const comboId = await database.query<{ id: string }>(
      `INSERT INTO combos (sucursal_id, nombre, descripcion, precio_fijo, disponible)
       VALUES ($1, $2, 'Fixture temporal del test de decisión', 30000, true)
       RETURNING id`,
      [SID, `QA Combo decisión ${Date.now()}`],
    );
    const id = comboId.rows[0].id;
    combos.push(id);
    await database.query(
      `INSERT INTO combo_items (combo_id, tipo_item, item_id, cantidad)
       VALUES ($1, 'producto', $2, 1), ($1, 'producto', $3, 1)`,
      [id, productos.rows[0].id, productos.rows[1].id],
    );
    return {
      id,
      componenteId: productos.rows[0].id,
      componentesIds: productos.rows.map((producto) => producto.id),
    };
  }

  async function crearPedidoConCombo(
    comboId: string,
    auth: TokenBundle['auth'] = admin.auth,
  ) {
    const creado = await crearPedidoStaff(auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `e2e-combo-${Date.now()}-${Math.random()}`,
      metodo_pago: 'pendiente',
      combos: [{ combo_id: comboId, cantidad: 1, precio: 30000 }],
    });
    expect(creado.status).toBe(201);
    expect(creado.body?.exito).toBe(true);
    const id = pedidoId(creado);
    pedidosQa.push(id);
    return id;
  }

  async function meseraActiva() {
    const resultado = await database.query<{ id: string }>(
      `SELECT id FROM usuarios
       WHERE sucursal_id = $1 AND rol = 'mesero' AND activo = true
       ORDER BY created_at LIMIT 1`,
      [SID],
    );
    if (!resultado.rows[0]) {
      throw new Error(
        'Falta una mesera activa en el fixture QA de esta sucursal.',
      );
    }
    return resultado.rows[0];
  }

  async function reportarFaltante(pedidoIdStr: string) {
    const tareas = await database.query<{ id: string; componente_id: string }>(
      `SELECT id, componente_id FROM pedido_combo_tareas_cocina
       WHERE pedido_id = $1 ORDER BY componente_indice`,
      [pedidoIdStr],
    );
    expect(tareas.rows).toHaveLength(2);
    const faltante = tareas.rows[0];
    const respuesta = await api()
      .patch(`/api/v1/cocina/combo-tareas/${faltante.id}/no-disponible`)
      .set(cocina.auth)
      .send({ motivo: 'Componente no disponible en prueba E2E' });
    expect(respuesta.status).toBe(200);
    expect(respuesta.body?.exito).toBe(true);
    return { faltante, tareas: tareas.rows };
  }

  it('encola preparación del combo por cocina y permite reimprimir solo esa estación', async () => {
    const combo = await crearComboTemporal();
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    const tareas = await database.query<{
      cocina_id: string;
      nombre_snapshot: string;
    }>(
      `SELECT cocina_id, nombre_snapshot
       FROM pedido_combo_tareas_cocina
       WHERE pedido_id = $1 ORDER BY componente_indice`,
      [pedidoIdStr],
    );
    expect(tareas.rows).toHaveLength(2);
    const cocinaId = tareas.rows[0].cocina_id;

    const ticketsKds = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    expect(ticketsKds.status).toBe(200);
    expect(ticketsKds.body?.exito).toBe(true);
    expect(
      ticketsKds.body.datos.find(
        (ticket: { pedido_id: string }) => ticket.pedido_id === pedidoIdStr,
      )?.cocina_id,
    ).toBe(cocinaId);

    let automaticos = await database.query<{
      cocina_id: string;
      payload: { ticket?: string };
    }>(
      `SELECT cocina_id, payload FROM impresion_cocina_jobs
       WHERE pedido_id = $1 AND cocina_id = $2 ORDER BY created_at`,
      [pedidoIdStr, cocinaId],
    );
    for (
      let intento = 0;
      intento < 20 && automaticos.rows.length === 0;
      intento++
    ) {
      await new Promise((resolve) => setTimeout(resolve, 50));
      automaticos = await database.query(
        `SELECT cocina_id, payload FROM impresion_cocina_jobs
         WHERE pedido_id = $1 AND cocina_id = $2 ORDER BY created_at`,
        [pedidoIdStr, cocinaId],
      );
    }
    if (automaticos.rows.length === 0) {
      const errores = await database.query(
        `SELECT cocina_id, estado, ultimo_error FROM impresion_cocina_jobs
         WHERE pedido_id = $1 ORDER BY created_at`,
        [pedidoIdStr],
      );
      throw new Error(`No se encoló comanda: ${JSON.stringify(errores.rows)}`);
    }
    expect(automaticos.rows).toHaveLength(1);
    const ticket = automaticos.rows[0].payload.ticket ?? '';
    for (const tarea of tareas.rows) {
      expect(ticket).toContain(`[PREPARACIÓN COMBO:`);
      expect(ticket).toContain(tarea.nombre_snapshot);
    }
    expect(ticket).not.toContain(`1x QA Combo decisión`);

    const reimpresion = await api()
      .post('/api/v1/impresion/reimprimir')
      .set(admin.auth)
      .send({ pedido_id: pedidoIdStr, cocina_id: cocinaId, sucursal_id: SID });
    expect(reimpresion.status).toBe(201);
    expect(reimpresion.body?.exito).toBe(true);

    const reimpresionCocina = await api()
      .post('/api/v1/impresion/reimprimir')
      .set(cocina.auth)
      .send({ pedido_id: pedidoIdStr, cocina_id: cocinaId, sucursal_id: SID });
    expect(reimpresionCocina.status).toBe(201);

    const otraCocina = await api()
      .post('/api/v1/impresion/reimprimir')
      .set(cocina.auth)
      .send({
        pedido_id: pedidoIdStr,
        cocina_id: 'd0000000-0000-4000-8000-000000000099',
        sucursal_id: SID,
      });
    expect(otraCocina.status).toBe(403);

    const jobsDespues = await database.query<{ total: number }>(
      `SELECT COUNT(*)::int AS total FROM impresion_cocina_jobs
       WHERE pedido_id = $1 AND cocina_id = $2`,
      [pedidoIdStr, cocinaId],
    );
    expect(jobsDespues.rows[0].total).toBe(3);
  });

  it('KDS y reimpresión consultan una estación secundaria con datos reales de QA', async () => {
    const combo = await crearComboTemporal();
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    const tareas = await database.query<{
      id: string;
      cocina_id: string;
      nombre_snapshot: string;
    }>(
      `SELECT id, cocina_id, nombre_snapshot
       FROM pedido_combo_tareas_cocina
       WHERE pedido_id = $1 ORDER BY componente_indice`,
      [pedidoIdStr],
    );
    expect(tareas.rows).toHaveLength(2);
    const itemPedido = await database.query<{
      id: string;
      cocina_id: string | null;
    }>(
      `SELECT id, cocina_id FROM pedido_items
       WHERE pedido_id = $1 ORDER BY id LIMIT 1`,
      [pedidoIdStr],
    );
    expect(itemPedido.rows).toHaveLength(1);
    const tareaSecundaria = tareas.rows[1];
    const cocinaOriginal = tareaSecundaria.cocina_id;
    const cocinaSecundaria = randomUUID();
    await database.query(
      'INSERT INTO cocinas (id, sucursal_id, nombre, activa) VALUES ($1, $2, $3, true)',
      [cocinaSecundaria, SID, 'QA Cocina secundaria temporal'],
    );
    try {
      await database.query(
        'UPDATE pedido_combo_tareas_cocina SET cocina_id = $1 WHERE id = $2',
        [cocinaSecundaria, tareaSecundaria.id],
      );
      await database.query(
        'UPDATE pedido_items SET cocina_id = $1 WHERE id = $2',
        [cocinaSecundaria, itemPedido.rows[0].id],
      );

      const cocinasCocina = await api()
        .get('/api/v1/cocina/cocinas')
        .set(cocina.auth);
      expect(cocinasCocina.status).toBe(200);
      expect(
        cocinasCocina.body.datos.map((estacion: { id: string }) => estacion.id),
      ).not.toContain(cocinaSecundaria);

      const ticketsCocinaAjena = await api()
        .get(`/api/v1/cocina/tickets/${cocinaSecundaria}`)
        .set(cocina.auth);
      expect(ticketsCocinaAjena.status).toBe(403);

      const mutacionCocinaAjena = await api()
        .patch(`/api/v1/cocina/combo-tareas/${tareaSecundaria.id}/estado`)
        .set(cocina.auth)
        .send({ estado_cocina: 'listo' });
      expect(mutacionCocinaAjena.status).toBe(403);

      const noDisponibleCocinaAjena = await api()
        .patch(
          `/api/v1/cocina/combo-tareas/${tareaSecundaria.id}/no-disponible`,
        )
        .set(cocina.auth)
        .send({ motivo: 'No autorizado desde estación ajena' });
      expect(noDisponibleCocinaAjena.status).toBe(403);
      const decisionNoAutorizada = await database.query<{ total: number }>(
        `SELECT COUNT(*)::int AS total FROM pedido_combo_decisiones_cliente
         WHERE pedido_id = $1`,
        [pedidoIdStr],
      );
      expect(decisionNoAutorizada.rows[0].total).toBe(0);

      const estadoItemAjeno = await api()
        .patch(`/api/v1/cocina/items/${itemPedido.rows[0].id}/estado`)
        .set(cocina.auth)
        .send({ estado_cocina: 'listo' });
      expect(estadoItemAjeno.status).toBe(403);
      const falloPreparacionAjeno = await api()
        .post(`/api/v1/cocina/items/${itemPedido.rows[0].id}/fallo-preparacion`)
        .set(cocina.auth)
        .send({ motivo: 'No autorizado desde estación ajena' });
      expect(falloPreparacionAjeno.status).toBe(403);
      const observacionesAjena = await api()
        .patch(`/api/v1/cocina/items/${itemPedido.rows[0].id}/observaciones`)
        .set(cocina.auth)
        .send({ observaciones: 'Cambio no autorizado' });
      expect(observacionesAjena.status).toBe(403);
      const prioridadAjena = await api()
        .patch(`/api/v1/cocina/items/${itemPedido.rows[0].id}/prioridad`)
        .set(cocina.auth)
        .send({ urgente: true });
      expect(prioridadAjena.status).toBe(403);

      const tickets = await api()
        .get(`/api/v1/cocina/tickets/${cocinaSecundaria}`)
        .set(admin.auth);
      expect(tickets.status).toBe(200);
      const ticket = tickets.body.datos.find(
        (item: { pedido_id: string }) => item.pedido_id === pedidoIdStr,
      );
      expect(ticket?.cocina_id).toBe(cocinaSecundaria);
      expect(ticket?.items).toHaveLength(1);
      expect(ticket.items[0]).toMatchObject({
        tarea_combo_id: tareaSecundaria.id,
        producto: tareaSecundaria.nombre_snapshot,
      });

      const reimpresion = await api()
        .post('/api/v1/impresion/reimprimir')
        .set(admin.auth)
        .send({
          pedido_id: pedidoIdStr,
          sucursal_id: SID,
          cocina_id: cocinaSecundaria,
        });
      expect(reimpresion.status).toBe(201);
      const job = await database.query<{
        payload: { ticket?: string };
      }>(
        `SELECT payload FROM impresion_cocina_jobs
         WHERE pedido_id = $1 AND cocina_id = $2 ORDER BY created_at DESC LIMIT 1`,
        [pedidoIdStr, cocinaSecundaria],
      );
      expect(job.rows).toHaveLength(1);
      expect(job.rows[0].payload.ticket).toContain(
        tareaSecundaria.nombre_snapshot,
      );
      expect(job.rows[0].payload.ticket).not.toContain(
        tareas.rows[0].nombre_snapshot,
      );

      const estado = await api()
        .patch(`/api/v1/cocina/combo-tareas/${tareaSecundaria.id}/estado`)
        .set(admin.auth)
        .send({ estado_cocina: 'preparando' });
      expect(estado.status).toBe(200);
      expect(estado.body?.datos?.cocina_id).toBe(cocinaSecundaria);
    } finally {
      await database.query(
        'DELETE FROM impresion_cocina_jobs WHERE pedido_id = $1 AND cocina_id = $2',
        [pedidoIdStr, cocinaSecundaria],
      );
      await database.query(
        'UPDATE pedido_combo_tareas_cocina SET cocina_id = $1 WHERE id = $2',
        [cocinaOriginal, tareaSecundaria.id],
      );
      await database.query(
        'UPDATE pedido_items SET cocina_id = $1 WHERE id = $2',
        [itemPedido.rows[0].cocina_id, itemPedido.rows[0].id],
      );
      await database.query('DELETE FROM cocinas WHERE id = $1', [
        cocinaSecundaria,
      ]);
    }
  });

  it('crea y enruta un combo con componentes en cocinas diferentes', async () => {
    const productos = await database.query<{
      id: string;
      cocina_id: string;
      precio: string;
      precio_para_llevar: string | null;
    }>(
      `SELECT id, cocina_id, precio, precio_para_llevar FROM productos
       WHERE sucursal_id = $1 AND disponible = true
         AND nombre LIKE 'E2E Ruta Cocina %' AND cocina_id IS NOT NULL
       ORDER BY id LIMIT 3`,
      [SID],
    );
    expect(productos.rows).toHaveLength(3);
    const [principal, secundario, productoBase] = productos.rows;
    const cocinaOriginalSecundaria = secundario.cocina_id;
    const cocinaSecundaria = randomUUID();
    await database.query(
      'INSERT INTO cocinas (id, sucursal_id, nombre, activa) VALUES ($1, $2, $3, true)',
      [cocinaSecundaria, SID, 'QA Cocina combo temporal'],
    );
    cocinasQa.push(cocinaSecundaria);
    await database.query('UPDATE productos SET cocina_id = $1 WHERE id = $2', [
      cocinaSecundaria,
      secundario.id,
    ]);
    let pedidoIdStr: string | undefined;
    try {
      const creadoCombo = await api()
        .post('/api/v1/combos')
        .set(admin.auth)
        .send({
          sucursal_id: SID,
          nombre: `QA Combo decisión ${Date.now()}`,
          precio_fijo: 30000,
          items: [
            { tipo_item: 'producto', item_id: principal.id, cantidad: 1 },
            { tipo_item: 'producto', item_id: secundario.id, cantidad: 1 },
          ],
        });
      expect(creadoCombo.status).toBe(201);
      expect(creadoCombo.body?.exito).toBe(true);
      const comboId = creadoCombo.body?.datos?.id ?? creadoCombo.body?.id;
      expect(comboId).toBeTruthy();
      combos.push(comboId);

      pedidoIdStr = await crearPedidoConCombo(comboId);
      const tareas = await database.query<{
        id: string;
        pedido_item_id: string;
        componente_id: string;
        cocina_id: string;
        estado: string;
      }>(
        `SELECT id, pedido_item_id, componente_id, cocina_id, estado
         FROM pedido_combo_tareas_cocina
         WHERE pedido_id = $1 AND tipo_item = 'producto'
         ORDER BY componente_indice`,
        [pedidoIdStr],
      );
      expect(tareas.rows).toHaveLength(2);
      expect(tareas.rows.map((tarea) => tarea.cocina_id)).toEqual(
        expect.arrayContaining([principal.cocina_id, cocinaSecundaria]),
      );
      expect(new Set(tareas.rows.map((tarea) => tarea.cocina_id)).size).toBe(2);
      expect(tareas.rows.every((tarea) => tarea.estado === 'pendiente')).toBe(
        true,
      );

      for (const cocinaId of [principal.cocina_id, cocinaSecundaria]) {
        const tickets = await api()
          .get(`/api/v1/cocina/tickets/${cocinaId}`)
          .set(admin.auth);
        expect(tickets.status).toBe(200);
        const ticket = tickets.body.datos.find(
          (item: { pedido_id: string }) => item.pedido_id === pedidoIdStr,
        );
        expect(ticket?.cocina_id).toBe(cocinaId);
        expect(ticket?.items).toHaveLength(1);
      }
      const primeraLista = await api()
        .patch(`/api/v1/cocina/combo-tareas/${tareas.rows[0].id}/estado`)
        .set(admin.auth)
        .send({ estado_cocina: 'listo' });
      expect(primeraLista.status).toBe(200);
      const parcial = await database.query<{ estado_cocina: string }>(
        'SELECT estado_cocina FROM pedido_items WHERE id = $1',
        [tareas.rows[0].pedido_item_id],
      );
      expect(parcial.rows[0].estado_cocina).toBe('preparando');

      const segundaLista = await api()
        .patch(`/api/v1/cocina/combo-tareas/${tareas.rows[1].id}/estado`)
        .set(admin.auth)
        .send({ estado_cocina: 'listo' });
      expect(segundaLista.status).toBe(200);
      const completa = await database.query<{
        estado_cocina: string;
        estado_pedido: string;
      }>(
        `SELECT i.estado_cocina, p.estado AS estado_pedido
         FROM pedido_items i JOIN pedidos p ON p.id = i.pedido_id
         WHERE i.id = $1`,
        [tareas.rows[0].pedido_item_id],
      );
      expect(completa.rows[0]).toMatchObject({
        estado_cocina: 'listo',
        estado_pedido: 'listo',
      });

      const pedidoBase = await crearPedidoStaff(admin.auth, {
        sucursal_id: SID,
        tipo: 'para_llevar',
        device_id: `e2e-combo-add-${randomUUID()}`,
        metodo_pago: 'pendiente',
        items: [
          {
            producto_id: productoBase.id,
            cantidad: 1,
            precio: Number(
              productoBase.precio_para_llevar ?? productoBase.precio,
            ),
          },
        ],
      });
      expect(pedidoBase.status).toBe(201);
      const pedidoBaseId = pedidoId(pedidoBase);
      pedidosQa.push(pedidoBaseId);
      const agregado = await api()
        .post(`/api/v1/pedidos/${pedidoBaseId}/items?sucursal_id=${SID}`)
        .set(admin.auth)
        .send({
          idempotency_key: randomUUID(),
          combos: [{ combo_id: comboId, cantidad: 1, precio: 30000 }],
        });
      expect(agregado.status).toBe(201);
      expect(agregado.body?.exito).toBe(true);
      const tareasAgregadas = await database.query<{
        cocina_id: string;
        estado: string;
      }>(
        `SELECT t.cocina_id, t.estado
         FROM pedido_combo_tareas_cocina t
         JOIN pedido_combo_selecciones s ON s.pedido_item_id = t.pedido_item_id
         WHERE t.pedido_id = $1 AND s.combo_id = $2
         ORDER BY t.componente_indice`,
        [pedidoBaseId, comboId],
      );
      expect(tareasAgregadas.rows).toHaveLength(2);
      expect(tareasAgregadas.rows.map((tarea) => tarea.cocina_id)).toEqual(
        expect.arrayContaining([principal.cocina_id, cocinaSecundaria]),
      );
    } finally {
      await database.query(
        'UPDATE productos SET cocina_id = $1 WHERE id = $2',
        [cocinaOriginalSecundaria, secundario.id],
      );
    }
  });

  it('recorre combo desde menú QR hasta aprobación, cocina y cobro en Caja', async () => {
    await limpiarPedidosActivos(admin.auth);
    await ensureCajaAbierta(cajero.auth);
    const combo = await crearComboTemporal();
    const menu = await api().get(`/api/v1/menu/mesa/${QR_TOKEN}`);
    expect(menu.body?.exito).toBe(true);
    const mesaId = menu.body.datos?.mesa?.id ?? menu.body.datos?.id;
    expect(mesaId).toBeTruthy();
    const device = await registrarDispositivoCliente('e2e-combo-qr');
    const payload = {
      sucursal_id: SID,
      mesa_id: mesaId,
      device_id: device.deviceId,
      tipo: 'mesa',
      qr_token: QR_TOKEN,
      metodo_pago: 'pendiente',
      combos: [{ combo_id: combo.id, cantidad: 1, precio: 30000 }],
    };

    const estimacion = await api()
      .post('/api/v1/pedidos/estimar')
      .set(device.headers)
      .send(payload);
    expect(estimacion.body?.exito).toBe(true);
    const creado = await api()
      .post('/api/v1/pedidos')
      .set(device.headers)
      .send({ ...payload, idempotency_key: randomUUID() });
    expect(creado.status).toBe(201);
    expect(creado.body?.datos?.estado).toBe('pendiente_aprobacion');
    const id = pedidoId(creado);
    pedidosQa.push(id);

    const aprobado = await api()
      .patch(`/api/v1/pedidos/${id}/aprobar?sucursal_id=${SID}`)
      .set(admin.auth)
      .send({ mesera_id: (await meseraActiva()).id });
    expect(aprobado.status).toBe(200);
    expect(aprobado.body?.datos?.estado).toBe('en_cocina');

    const tareas = await database.query<{ id: string; cocina_id: string }>(
      `SELECT id, cocina_id FROM pedido_combo_tareas_cocina
       WHERE pedido_id = $1 ORDER BY componente_indice`,
      [id],
    );
    expect(tareas.rows).toHaveLength(2);
    let jobs = await database.query<{ id: string }>(
      'SELECT id FROM impresion_cocina_jobs WHERE pedido_id = $1 LIMIT 1',
      [id],
    );
    for (let intento = 0; intento < 20 && jobs.rows.length === 0; intento++) {
      await new Promise((resolve) => setTimeout(resolve, 50));
      jobs = await database.query(
        'SELECT id FROM impresion_cocina_jobs WHERE pedido_id = $1 LIMIT 1',
        [id],
      );
    }
    expect(jobs.rows).toHaveLength(1);
    for (const tarea of tareas.rows) {
      const listo = await api()
        .patch(`/api/v1/cocina/combo-tareas/${tarea.id}/estado`)
        .set(cocina.auth)
        .send({ estado_cocina: 'listo' });
      expect(listo.status).toBe(200);
    }
    const listo = await detallePedido(admin.auth, id);
    expect((listo.body.datos?.pedido ?? listo.body.datos).estado).toBe('listo');

    const pagando = await setEstado(cajero.auth, id, 'pagando');
    expect(pagando.body?.exito).toBe(true);
    const cobro = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(cobro.body?.exito).toBe(true);

    const conciliado = await database.query<{
      estado: string;
      total: string;
      lineas: number;
      tareas_listas: number;
      pagos: number;
    }>(
      `SELECT p.estado, p.total::text AS total,
              COUNT(DISTINCT pi.id)::int AS lineas,
              (SELECT COUNT(*)::int FROM pedido_combo_tareas_cocina t
               WHERE t.pedido_id = p.id AND t.estado = 'listo') AS tareas_listas,
              (SELECT COUNT(*)::int FROM pagos_pedido pp
               WHERE pp.pedido_id = p.id) AS pagos
       FROM pedidos p JOIN pedido_items pi ON pi.pedido_id = p.id
       WHERE p.id = $1 GROUP BY p.id`,
      [id],
    );
    expect(conciliado.rows[0]).toMatchObject({
      estado: 'pagado',
      total: Number(estimacion.body.datos.total).toFixed(2),
      lineas: 1,
      tareas_listas: 2,
      pagos: 1,
    });
  });

  it('acepta combos creados desde POS/cajero y mesero sin registrar pago anticipado', async () => {
    const comboPos = await crearComboTemporal();
    const pedidoPos = await crearPedidoConCombo(comboPos.id, cajero.auth);
    const pos = await database.query<{
      estado: string;
      monto_pagado: string;
      lineas: number;
      tareas: number;
    }>(
      `SELECT p.estado, p.monto_pagado::text AS monto_pagado,
              COUNT(DISTINCT pi.id)::int AS lineas,
              (SELECT COUNT(*)::int FROM pedido_combo_tareas_cocina t
               WHERE t.pedido_id = p.id) AS tareas
       FROM pedidos p JOIN pedido_items pi ON pi.pedido_id = p.id
       WHERE p.id = $1 GROUP BY p.id`,
      [pedidoPos],
    );
    expect(pos.rows[0]).toMatchObject({
      estado: 'en_cocina',
      monto_pagado: '0.00',
      lineas: 1,
      tareas: 2,
    });

    const email = `mesero-combo-${randomUUID()}@qa.example`;
    const creado = await api().post('/api/v1/usuarios').set(admin.auth).send({
      nombre: 'Mesero E2E Combo',
      email,
      contrasena: '123456',
      rol: 'mesero',
      sucursal_id: SID,
    });
    expect(creado.body?.exito).toBe(true);
    const usuarioId = creado.body.datos.id as string;
    try {
      const mesero = await login(email);
      const comboMesero = await crearComboTemporal();
      const pedidoMesero = await crearPedidoConCombo(
        comboMesero.id,
        mesero.auth,
      );
      const meseroPersistido = await database.query<{
        estado: string;
        monto_pagado: string;
        lineas: number;
        tareas: number;
      }>(
        `SELECT p.estado, p.monto_pagado::text AS monto_pagado,
                COUNT(DISTINCT pi.id)::int AS lineas,
                (SELECT COUNT(*)::int FROM pedido_combo_tareas_cocina t
                 WHERE t.pedido_id = p.id) AS tareas
         FROM pedidos p JOIN pedido_items pi ON pi.pedido_id = p.id
         WHERE p.id = $1 GROUP BY p.id`,
        [pedidoMesero],
      );
      expect(meseroPersistido.rows[0]).toMatchObject({
        estado: 'en_cocina',
        monto_pagado: '0.00',
        lineas: 1,
        tareas: 2,
      });
    } finally {
      await api()
        .patch(`/api/v1/usuarios/${usuarioId}/estado?sucursal_id=${SID}`)
        .set(admin.auth)
        .send({ activo: false });
    }
  });

  it('aplica sustitución aceptada, reanuda estaciones y actualiza total de la línea', async () => {
    const combo = await crearComboTemporal();
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    const { faltante, tareas } = await reportarFaltante(pedidoIdStr);

    const pendientes = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones-pendientes?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    expect(pendientes.body?.exito).toBe(true);
    const decision = pendientes.body.datos[0];
    expect(decision?.componente_anterior?.componente_id).toBe(
      combo.componenteId,
    );

    const cotizacion = await api()
      .post(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/cotizacion?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({ reemplazo_id: 'f0000000-0000-4000-8000-000000000003' });
    expect(cotizacion.status).toBe(201);
    expect(cotizacion.body?.exito).toBe(true);
    const cotizada = cotizacion.body.datos;

    const enviarRespuesta = () =>
      api()
        .patch(
          `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
        )
        .set(admin.auth)
        .send({
          accion: 'aceptar_sustitucion',
          cotizacion_version: cotizada.cotizacion_version,
          total_aceptado: cotizada.total_propuesto,
        });
    const respuestasParalelas = await Promise.all([
      enviarRespuesta(),
      enviarRespuesta(),
    ]);
    for (const respuestaConcurrente of respuestasParalelas) {
      expect(respuestaConcurrente.status).toBe(200);
      expect(respuestaConcurrente.body?.exito).toBe(true);
    }
    expect(
      respuestasParalelas
        .map((r) => Boolean(r.body?.datos?.idempotente))
        .sort(),
    ).toEqual([false, true]);
    const respuesta = respuestasParalelas.find(
      (r) => !r.body?.datos?.idempotente,
    )!;
    expect(respuesta.status).toBe(200);
    expect(respuesta.body?.exito).toBe(true);
    expect(respuesta.body.datos).toMatchObject({
      estado: 'aplicada',
      aplicado: true,
      respuesta_accion: 'aceptar_sustitucion',
    });

    const estado = await database.query<{
      total: string;
      estado: string;
      respuesta_accion: string;
      decision_estado: string;
      linea_actual: string;
      task_states: string[];
    }>(
      `SELECT p.total::text AS total, p.estado,
              d.respuesta_accion, d.estado AS decision_estado,
              (SELECT COUNT(*)::text FROM pedido_combo_selecciones s
               WHERE s.pedido_item_id = d.pedido_item_id) AS linea_actual,
              ARRAY(SELECT t.estado FROM pedido_combo_tareas_cocina t
                    WHERE t.pedido_id = p.id ORDER BY t.componente_indice) AS task_states
       FROM pedidos p
       JOIN pedido_combo_decisiones_cliente d ON d.pedido_id = p.id
       WHERE p.id = $1`,
      [pedidoIdStr],
    );
    expect(Number(estado.rows[0]?.total)).toBe(cotizada.total_propuesto);
    expect(estado.rows[0]?.decision_estado).toBe('aplicada');
    expect(estado.rows[0]?.respuesta_accion).toBe('aceptar_sustitucion');
    expect(estado.rows[0]?.task_states).toEqual(['pendiente', 'pendiente']);
    expect(tareas).toHaveLength(2);
    expect(faltante.componente_id).toBe(combo.componenteId);

    const repetida = await api()
      .patch(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({
        accion: 'aceptar_sustitucion',
        cotizacion_version: cotizada.cotizacion_version,
        total_aceptado: cotizada.total_propuesto,
      });
    expect(repetida.status).toBe(200);
    expect(repetida.body?.datos?.idempotente).toBe(true);
  });

  it('cancela el combo rechazado, conserva snapshots y permite reintento idempotente', async () => {
    const combo = await crearComboTemporal();
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    const { faltante } = await reportarFaltante(pedidoIdStr);
    const pendientes = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones-pendientes?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    const decision = pendientes.body.datos[0];

    const respuesta = await api()
      .patch(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({
        accion: 'cancelar_combo',
        motivo: 'El cliente rechaza el combo en la prueba',
      });
    expect(respuesta.status).toBe(200);
    expect(respuesta.body?.datos).toMatchObject({
      estado: 'aplicada',
      aplicado: true,
    });

    const persistido = await database.query<{
      pedido_estado: string;
      total: string;
      item_id: string | null;
      decision_estado: string;
      snapshot: Record<string, unknown> | null;
      tareas_canceladas: number;
    }>(
      `SELECT p.estado AS pedido_estado, p.total::text AS total,
              d.pedido_item_id AS item_id, d.estado AS decision_estado,
              d.linea_cancelada_snapshot AS snapshot,
              (SELECT COUNT(*)::int FROM pedido_combo_tareas_cocina t
               WHERE t.pedido_id = p.id AND t.estado = 'cancelada'
                 AND t.pedido_item_id IS NULL) AS tareas_canceladas
       FROM pedidos p
       JOIN pedido_combo_decisiones_cliente d ON d.pedido_id = p.id
       WHERE p.id = $1`,
      [pedidoIdStr],
    );
    expect(persistido.rows[0]).toMatchObject({
      pedido_estado: 'cancelado',
      total: '0.00',
      item_id: null,
      decision_estado: 'aplicada',
      tareas_canceladas: 2,
    });
    expect(persistido.rows[0].snapshot).toBeTruthy();
    expect(persistido.rows[0].snapshot).toHaveProperty('vinculos_pago');
    expect(faltante.componente_id).toBe(combo.componenteId);

    const repetida = await api()
      .patch(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({
        accion: 'cancelar_combo',
        motivo: 'Reintento de respuesta',
      });
    expect(repetida.status).toBe(200);
    expect(repetida.body?.datos?.idempotente).toBe(true);
  });

  it('cancela solo el combo rechazado y conserva las demás líneas', async () => {
    await ensureCajaAbierta(cajero.auth);
    const combo = await crearComboTemporal();
    const productoExtra = await database.query<{
      id: string;
      precio: string;
    }>(
      `SELECT id, precio::text
       FROM productos
       WHERE sucursal_id = $1 AND disponible = true
         AND nombre LIKE 'E2E Ruta Cocina %'
         AND NOT (id = ANY($2::uuid[]))
       ORDER BY id LIMIT 1`,
      [SID, combo.componentesIds],
    );
    expect(productoExtra.rows[0]).toBeTruthy();
    const precioProductoExtra = Number(productoExtra.rows[0].precio);
    const montoAbono = precioProductoExtra + 500;
    const creado = await crearPedidoStaff(admin.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `e2e-combo-con-otra-linea-${Date.now()}`,
      metodo_pago: 'pendiente',
      combos: [{ combo_id: combo.id, cantidad: 1, precio: 30000 }],
      items: [
        {
          producto_id: productoExtra.rows[0].id,
          cantidad: 1,
          precio: precioProductoExtra,
        },
      ],
    });
    expect(creado.status).toBe(201);
    expect(creado.body?.exito).toBe(true);
    const pedidoIdStr = pedidoId(creado);
    pedidosQa.push(pedidoIdStr);
    const { faltante } = await reportarFaltante(pedidoIdStr);

    expect(
      (await setEstado(cajero.auth, pedidoIdStr, 'pagando')).body.exito,
    ).toBe(true);
    const abono = await api()
      .post(`/api/v1/pedidos/${pedidoIdStr}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ monto_parcial: montoAbono, metodo_pago: 'efectivo' });
    expect(abono.body?.exito).toBe(true);
    expect(Number(abono.body?.datos?.total_cobrado)).toBe(montoAbono);

    const pendientes = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones-pendientes?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    const decision = pendientes.body.datos[0];

    const respuesta = await api()
      .patch(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({
        accion: 'cancelar_combo',
        motivo: 'Conservar producto independiente',
      });
    expect(respuesta.status).toBe(200);
    expect(respuesta.body?.datos?.aplicado).toBe(true);

    const persistido = await database.query<{
      estado: string;
      total: string;
      lineas: number;
      producto_restante: string;
      decision_estado: string;
      monto_pagado: string;
      devolucion: string;
      iva_porcentaje: string;
      iva_valor: string;
    }>(
      `SELECT p.estado, p.total::text AS total,
              COUNT(i.id)::int AS lineas,
              MAX(i.producto_id::text) AS producto_restante,
              d.estado AS decision_estado,
              p.monto_pagado::text AS monto_pagado,
              p.iva_porcentaje::text AS iva_porcentaje,
              p.iva_valor::text AS iva_valor,
              COALESCE((SELECT SUM(m.monto) FROM movimientos_caja m
                        WHERE m.pedido_id = p.id AND m.tipo = 'devolucion'), 0)::text AS devolucion
       FROM pedidos p
       JOIN pedido_combo_decisiones_cliente d ON d.pedido_id = p.id
       LEFT JOIN pedido_items i ON i.pedido_id = p.id
       WHERE p.id = $1
       GROUP BY p.id, d.estado`,
      [pedidoIdStr],
    );
    expect(persistido.rows[0]).toMatchObject({
      total: precioProductoExtra.toFixed(2),
      lineas: 1,
      producto_restante: productoExtra.rows[0].id,
      decision_estado: 'aplicada',
      monto_pagado: precioProductoExtra.toFixed(2),
      devolucion: '500.00',
    });
    expect(persistido.rows[0].estado).not.toBe('cancelado');
    expect(faltante.componente_id).toBe(combo.componenteId);
    const totalFinal = precioProductoExtra;
    const porcentajeIva = Number(persistido.rows[0].iva_porcentaje);
    const ivaEsperado =
      porcentajeIva > 0
        ? Math.round(
            (totalFinal - totalFinal / (1 + porcentajeIva / 100)) * 100,
          ) / 100
        : 0;
    expect(Number(persistido.rows[0].iva_valor)).toBe(ivaEsperado);
  });

  it('rechaza aplicar una cotización si el precio cambia antes de confirmarla', async () => {
    const combo = await crearComboTemporal();
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    await reportarFaltante(pedidoIdStr);
    const pendientes = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones-pendientes?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    const decision = pendientes.body.datos[0];
    const reemplazoId = 'f0000000-0000-4000-8000-000000000003';
    const cotizacion = await api()
      .post(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/cotizacion?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({ reemplazo_id: reemplazoId });
    expect(cotizacion.status).toBe(201);

    const precio = await database.query<{ precio: string }>(
      'SELECT precio::text FROM productos WHERE id = $1 AND sucursal_id = $2',
      [reemplazoId, SID],
    );
    const precioOriginal = Number(precio.rows[0].precio);
    try {
      await database.query(
        'UPDATE productos SET precio = $1 WHERE id = $2 AND sucursal_id = $3',
        [precioOriginal + 100, reemplazoId, SID],
      );
      const respuesta = await api()
        .patch(
          `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
        )
        .set(admin.auth)
        .send({
          accion: 'aceptar_sustitucion',
          cotizacion_version: cotizacion.body.datos.cotizacion_version,
          total_aceptado: cotizacion.body.datos.total_propuesto,
        });
      expect(respuesta.status).toBe(409);
      const persistido = await database.query<{
        estado: string;
        total: string;
      }>(
        `SELECT d.estado, p.total::text AS total
         FROM pedido_combo_decisiones_cliente d
         JOIN pedidos p ON p.id = d.pedido_id WHERE d.id = $1`,
        [decision.decision_id],
      );
      expect(persistido.rows[0]).toMatchObject({
        estado: 'pendiente_cliente',
        total: '30000.00',
      });
    } finally {
      await database.query(
        'UPDATE productos SET precio = $1 WHERE id = $2 AND sucursal_id = $3',
        [precioOriginal, reemplazoId, SID],
      );
    }
  });

  it('revierte toda la sustitución si el stock del reemplazo se agota tras cotizar', async () => {
    const combo = await crearComboTemporal();
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    await reportarFaltante(pedidoIdStr);
    const pendientes = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones-pendientes?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    const decision = pendientes.body.datos[0];
    const reemplazoId = 'f0000000-0000-4000-8000-000000000001';
    const cotizacion = await api()
      .post(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/cotizacion?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({ reemplazo_id: reemplazoId });
    expect(cotizacion.status).toBe(201);
    const ingredientes = await database.query<{
      id: string;
      stock_actual: string;
    }>(
      `SELECT i.id, i.stock_actual::text
       FROM productos p
       JOIN receta_items ri ON ri.receta_id = p.receta_id
       JOIN ingredientes i ON i.id = ri.ingrediente_id
       WHERE p.id = $1 AND p.sucursal_id = $2`,
      [reemplazoId, SID],
    );
    expect(ingredientes.rows.length).toBeGreaterThan(0);
    const stockOriginal = new Map(
      ingredientes.rows.map((fila) => [fila.id, fila.stock_actual]),
    );
    const idsIngredientes = ingredientes.rows.map((fila) => fila.id);
    try {
      await database.query(
        'UPDATE ingredientes SET stock_actual = 0 WHERE id = ANY($1::uuid[]) AND sucursal_id = $2',
        [idsIngredientes, SID],
      );
      const respuesta = await api()
        .patch(
          `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
        )
        .set(admin.auth)
        .send({
          accion: 'aceptar_sustitucion',
          cotizacion_version: cotizacion.body.datos.cotizacion_version,
          total_aceptado: cotizacion.body.datos.total_propuesto,
        });
      expect(respuesta.status).toBe(400);
      const persistido = await database.query<{
        estado: string;
        total: string;
        componente: string;
      }>(
        `SELECT d.estado, p.total::text AS total,
                pcs.componentes_snapshot->0->>'item_id' AS componente
         FROM pedido_combo_decisiones_cliente d
         JOIN pedidos p ON p.id = d.pedido_id
         JOIN pedido_combo_selecciones pcs ON pcs.pedido_item_id = d.pedido_item_id
         WHERE d.id = $1`,
        [decision.decision_id],
      );
      expect(persistido.rows[0]).toMatchObject({
        estado: 'pendiente_cliente',
        total: '30000.00',
        componente: combo.componenteId,
      });
    } finally {
      for (const [ingredienteId, stock] of stockOriginal) {
        await database.query(
          'UPDATE ingredientes SET stock_actual = $1 WHERE id = $2 AND sucursal_id = $3',
          [stock, ingredienteId, SID],
        );
      }
    }
  });

  it('registra como merma el componente listo y devuelve el que no se preparó', async () => {
    const productoIds = [
      'f0000000-0000-4000-8000-000000000001',
      'f0000000-0000-4000-8000-000000000002',
    ];
    const stockAntes = await database.query<{
      id: string;
      stock_actual: string;
    }>(
      'SELECT id, stock_actual::text FROM ingredientes WHERE sucursal_id = $1',
      [SID],
    );
    const combo = await crearComboTemporal(productoIds);
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    const tareas = await database.query<{
      id: string;
      componente_indice: number;
    }>(
      `SELECT id, componente_indice FROM pedido_combo_tareas_cocina
       WHERE pedido_id = $1 ORDER BY componente_indice`,
      [pedidoIdStr],
    );
    const lista = await api()
      .patch(`/api/v1/cocina/combo-tareas/${tareas.rows[1].id}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'listo' });
    expect(lista.status).toBe(200);
    await reportarFaltante(pedidoIdStr);
    const pendientes = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones-pendientes?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    const decision = pendientes.body.datos[0];
    const respuesta = await api()
      .patch(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({
        accion: 'cancelar_combo',
        motivo: 'El cliente rechaza tras preparar un componente',
      });
    expect(respuesta.status).toBe(200);

    const ledger = await database.query<{
      componente_indice: number;
      evento: string;
      cantidad: string;
    }>(
      `SELECT componente_indice, evento, SUM(cantidad)::text AS cantidad
       FROM pedido_combo_stock_ledger WHERE pedido_id = $1
       GROUP BY componente_indice, evento ORDER BY componente_indice, evento`,
      [pedidoIdStr],
    );
    expect(ledger.rows).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ componente_indice: 0, evento: 'devolucion' }),
        expect.objectContaining({ componente_indice: 1, evento: 'merma' }),
      ]),
    );
    const stockDespues = await database.query<{
      id: string;
      stock_actual: string;
    }>(
      'SELECT id, stock_actual::text FROM ingredientes WHERE sucursal_id = $1',
      [SID],
    );
    const consumosPreparados = await database.query<{
      ingrediente_id: string;
      cantidad: string;
    }>(
      `SELECT ingrediente_id, SUM(cantidad)::text AS cantidad
       FROM pedido_combo_stock_ledger
       WHERE pedido_id = $1 AND componente_indice = 1 AND evento = 'consumo'
       GROUP BY ingrediente_id`,
      [pedidoIdStr],
    );
    const antesPorId = new Map(
      stockAntes.rows.map((fila) => [fila.id, Number(fila.stock_actual)]),
    );
    const mermaPorIngrediente = new Map(
      consumosPreparados.rows.map((fila) => [
        fila.ingrediente_id,
        Number(fila.cantidad),
      ]),
    );
    for (const fila of stockDespues.rows) {
      const esperado =
        antesPorId.get(fila.id)! - (mermaPorIngrediente.get(fila.id) ?? 0);
      expect(Number(fila.stock_actual)).toBeCloseTo(esperado, 4);
    }
  });

  it('devuelve por ledger el stock de todos los componentes del combo cancelado', async () => {
    const productoIds = [
      'f0000000-0000-4000-8000-000000000001',
      'f0000000-0000-4000-8000-000000000002',
    ];
    const stockAntes = await database.query<{
      id: string;
      stock_actual: string;
    }>(
      `SELECT id, stock_actual::text FROM ingredientes WHERE sucursal_id = $1`,
      [SID],
    );
    const combo = await crearComboTemporal(productoIds);
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    const ledgerConsumo = await database.query<{
      cantidad: string;
      componente_indice: number;
    }>(
      `SELECT cantidad::text, componente_indice
       FROM pedido_combo_stock_ledger
       WHERE pedido_id = $1 AND evento = 'consumo'
       ORDER BY componente_indice, ingrediente_id`,
      [pedidoIdStr],
    );
    expect(ledgerConsumo.rows.length).toBeGreaterThan(0);
    const { faltante } = await reportarFaltante(pedidoIdStr);
    const pendientes = await api()
      .get(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones-pendientes?sucursal_id=${SID}`,
      )
      .set(admin.auth);
    const decision = pendientes.body.datos[0];
    const respuesta = await api()
      .patch(
        `/api/v1/pedidos/${pedidoIdStr}/combo-decisiones/${decision.decision_id}/respuesta?sucursal_id=${SID}`,
      )
      .set(admin.auth)
      .send({
        accion: 'cancelar_combo',
        motivo: 'Verificar devolución desde ledger',
      });
    expect(respuesta.status).toBe(200);

    const conciliacion = await database.query<{
      ingrediente_id: string;
      consumido: string;
      devuelto: string;
    }>(
      `SELECT ingrediente_id,
              SUM(cantidad) FILTER (WHERE evento = 'consumo')::text AS consumido,
              SUM(cantidad) FILTER (WHERE evento = 'devolucion')::text AS devuelto
       FROM pedido_combo_stock_ledger WHERE pedido_id = $1
       GROUP BY ingrediente_id ORDER BY ingrediente_id`,
      [pedidoIdStr],
    );
    expect(conciliacion.rows.length).toBeGreaterThan(0);
    for (const fila of conciliacion.rows) {
      expect(Number(fila.devuelto)).toBe(Number(fila.consumido));
    }

    const stockDespues = await database.query<{
      id: string;
      stock_actual: string;
    }>(
      `SELECT id, stock_actual::text FROM ingredientes WHERE sucursal_id = $1`,
      [SID],
    );
    const antesPorId = new Map(
      stockAntes.rows.map((fila) => [fila.id, fila.stock_actual]),
    );
    expect(stockDespues.rows).toHaveLength(stockAntes.rows.length);
    for (const fila of stockDespues.rows) {
      expect(fila.stock_actual).toBe(antesPorId.get(fila.id));
    }
    expect(faltante.componente_id).toBe(combo.componenteId);
  });

  it('cancela manualmente un combo antes de cocina ajustando línea financiera, tareas y stock', async () => {
    const productoIds = [
      'f0000000-0000-4000-8000-000000000001',
      'f0000000-0000-4000-8000-000000000002',
    ];
    const stockAntes = await database.query<{
      id: string;
      stock_actual: string;
    }>(
      `SELECT id, stock_actual::text FROM ingredientes WHERE sucursal_id = $1`,
      [SID],
    );
    const combo = await crearComboTemporal(productoIds);
    const pedidoIdStr = await crearPedidoConCombo(combo.id);
    const item = await database.query<{ id: string }>(
      `SELECT id FROM pedido_items WHERE pedido_id = $1`,
      [pedidoIdStr],
    );
    expect(item.rows).toHaveLength(1);
    const consumos = await database.query<{
      ingrediente_id: string;
      cantidad: string;
    }>(
      `SELECT ingrediente_id, SUM(cantidad)::text AS cantidad
       FROM pedido_combo_stock_ledger
       WHERE pedido_id = $1 AND evento = 'consumo'
       GROUP BY ingrediente_id`,
      [pedidoIdStr],
    );
    expect(consumos.rows.length).toBeGreaterThan(0);

    const eliminado = await api()
      .delete(`/api/v1/pedidos/${pedidoIdStr}/items/${item.rows[0].id}`)
      .query({ sucursal_id: SID })
      .set(admin.auth)
      .send({ motivo: 'QA cancela combo completo antes de preparar' });
    expect(eliminado.status).toBe(200);
    expect(eliminado.body.exito).toBe(true);

    const pedidoFinal = await database.query<{
      estado: string;
      subtotal: string;
      total: string;
    }>(
      `SELECT estado, subtotal::text, total::text FROM pedidos WHERE id = $1`,
      [pedidoIdStr],
    );
    expect(pedidoFinal.rows[0]).toMatchObject({
      estado: 'cancelado',
      subtotal: '0.00',
      total: '0.00',
    });
    const tareas = await database.query<{ estado: string }>(
      `SELECT estado FROM pedido_combo_tareas_cocina
       WHERE pedido_item_id_original = $1 ORDER BY componente_indice`,
      [item.rows[0].id],
    );
    expect(tareas.rows.length).toBe(2);
    expect(tareas.rows.every((tarea) => tarea.estado === 'cancelada')).toBe(
      true,
    );
    const devoluciones = await database.query<{
      ingrediente_id: string;
      cantidad: string;
    }>(
      `SELECT ingrediente_id, SUM(cantidad)::text AS cantidad
       FROM pedido_combo_stock_ledger
       WHERE pedido_id = $1 AND evento = 'devolucion'
       GROUP BY ingrediente_id`,
      [pedidoIdStr],
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
    const stockDespues = await database.query<{
      id: string;
      stock_actual: string;
    }>(
      `SELECT id, stock_actual::text FROM ingredientes WHERE sucursal_id = $1`,
      [SID],
    );
    const antesPorId = new Map(
      stockAntes.rows.map((fila) => [fila.id, fila.stock_actual]),
    );
    for (const fila of stockDespues.rows) {
      expect(fila.stock_actual).toBe(antesPorId.get(fila.id));
    }
  });
});
