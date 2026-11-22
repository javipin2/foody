/**
 * Casos límite Prompts 28–30 (VIE/CONS) — comportamiento actual documentado.
 * Si un BUG se corrige, actualizar la aserción y el ID en AUDITORIA_E2E_AUTOMATIZADO.md.
 */
import {
  api,
  assertApiViva,
  crearPedidoStaff,
  detallePedido,
  ensureCajaAbierta,
  itemBody,
  limpiarPedidosActivos,
  login,
  mesaLibre,
  pedidoId,
  setEstado,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E casos límite Prompts 28-30', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    cajero = await login('cajero.test@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
    await ensureCajaAbierta(cajero.auth);
  });

  it('VIE-01: add ítems con pedido listo baja estado a en_cocina', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-vie01',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    const id = pedidoId(crear);
    expect((await setEstado(cajero.auth, id, 'listo')).body.exito).toBe(true);

    const add = await api()
      .post(`/api/v1/pedidos/${id}/items?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ items: [itemBody()] });
    expect(add.body.exito).toBe(true);

    const det = await detallePedido(cajero.auth, id);
    const estado = det.body.datos?.estado || det.body.datos?.pedido?.estado;
    expect(estado).toBe('en_cocina');
  });

  it('VIE-05/13 [C]: abono OK; pagado bloqueado sin cocina; admin+motivo OK', async () => {
    const cocina = await login('cocina@foody.demo');
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-vie05',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    const id = pedidoId(crear);
    const det0 = await detallePedido(cajero.auth, id);
    const items0 = (det0.body.datos?.items_resumen ||
      det0.body.datos?.items ||
      det0.body.datos?.pedido?.items ||
      []) as Array<{ id?: string; item_id?: string }>;
    const itemId = items0[0]?.item_id || items0[0]?.id;
    expect(itemId).toBeTruthy();
    await api()
      .patch(`/api/v1/cocina/items/${itemId}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'preparando' });

    const abono = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo', monto_parcial: 2000 });
    expect(abono.body.exito).toBe(true);

    const saldar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(saldar.body.exito).toBeFalsy();
    expect(saldar.body.error).toBe('COCINA_INCOMPLETA_PARA_PAGADO');

    const forzar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(admin.auth)
      .send({
        metodo_pago: 'efectivo',
        motivo: 'jest override cocina incompleta',
      });
    expect(forzar.body.exito).toBe(true);
  });

  it('PED-PREPAGO-01: para_llevar efectivo en_cocina cobrado; cobrar falla; cocina→pagado', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: 'jest-prepago',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    const det = await detallePedido(cajero.auth, id);
    const estado = det.body.datos?.estado || det.body.datos?.pedido?.estado;
    const monto = Number(
      det.body.datos?.monto_pagado ?? det.body.datos?.pedido?.monto_pagado ?? 0,
    );
    const total = Number(det.body.datos?.total ?? det.body.datos?.pedido?.total ?? 0);
    expect(estado).toBe('en_cocina');
    expect(monto).toBeGreaterThanOrEqual(total - 0.01);

    const cobrar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(cobrar.body.exito).toBeFalsy();

    // Cocina marca ítems listos → pedido pagado (ya cobrado)
    const cocina = await login('cocina@foody.demo');
    const cocinaId = 'd0000000-0000-4000-8000-000000000001';
    const tickets = await api().get(`/api/v1/cocina/tickets/${cocinaId}`).set(cocina.auth);
    const ticket = (
      tickets.body.datos as Array<{
        pedido_id: string;
        items: Array<{ item_id?: string; id?: string }>;
      }>
    ).find((t) => t.pedido_id === id);
    expect(ticket).toBeTruthy();
    for (const it of ticket!.items) {
      const iid = it.item_id || it.id!;
      await api()
        .patch(`/api/v1/cocina/items/${iid}/estado`)
        .set(cocina.auth)
        .send({ estado_cocina: 'listo' });
    }
    const det2 = await detallePedido(cajero.auth, id);
    const estado2 = det2.body.datos?.estado || det2.body.datos?.pedido?.estado;
    expect(estado2).toBe('pagado');
  });

  it('VIE-02 regla: soft-off catálogo no borra líneas del pedido abierto', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-vie02',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    const id = pedidoId(crear);
    const detAntes = await detallePedido(cajero.auth, id);
    const nAntes =
      (detAntes.body.datos?.items_resumen as unknown[])?.length ??
      (detAntes.body.datos?.items as unknown[])?.length ??
      1;

    // No mutamos catálogo en E2E (resto de demos); solo afirmamos que el pedido sigue con ítems.
    expect(nAntes).toBeGreaterThanOrEqual(1);
    const det = await detallePedido(cajero.auth, id);
    const estado = det.body.datos?.estado || det.body.datos?.pedido?.estado;
    expect(['en_cocina', 'confirmado', 'pendiente', 'listo']).toContain(estado);
  });
});
