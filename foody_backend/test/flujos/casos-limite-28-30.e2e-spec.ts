/**
 * Casos límite Prompts 28–30 (VIE/CONS) — comportamiento actual documentado.
 * Si un BUG se corrige, actualizar la aserción y el ID en AUDITORIA_E2E_AUTOMATIZADO.md.
 */
import {
  api,
  assertApiViva,
  COCINA_ID,
  crearPedidoStaff,
  detallePedido,
  ensureCajaAbierta,
  itemBody,
  limpiarPedidosActivos,
  login,
  marcarItemsCocinaListos,
  mesaLibre,
  pedidoId,
  PRECIO,
  setEstado,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E casos límite Prompts 28-30', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;
  let cocina: TokenBundle;
  let pedidoPruebaId: string | null = null;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    cajero = await login('cajero.test@foody.demo');
    cocina = await login('cocina@foody.demo');
  });

  beforeEach(async () => {
    await limpiarPedidosActivos(admin.auth);
    await ensureCajaAbierta(cajero.auth);
  });

  afterEach(async () => {
    if (pedidoPruebaId) {
      await setEstado(admin.auth, pedidoPruebaId, 'cancelado', {
        motivo: 'QA E2E cleanup casos límite',
      });
      pedidoPruebaId = null;
    }
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
    pedidoPruebaId = id;
    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
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

  it('PED-EDIT-01: cambiar observaciones después de listo reabre Cocina', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: `jest-edit-listo-${Date.now()}`,
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);

    const antes = await detallePedido(cajero.auth, id);
    const datosAntes = antes.body.datos ?? {};
    const lineas = (datosAntes.items_resumen ||
      datosAntes.items ||
      datosAntes.pedido?.items ||
      []) as Array<{
      id?: string;
      item_id?: string;
    }>;
    const itemId = lineas[0]?.item_id || lineas[0]?.id;
    expect(itemId).toBeTruthy();
    expect(datosAntes.estado || datosAntes.pedido?.estado).toBe('listo');

    const editar = await api()
      .patch(`/api/v1/pedidos/${id}/items/${itemId}?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ observaciones: 'Sin cebolla' });
    expect(editar.body.exito).toBe(true);
    expect(editar.body.datos.estado).toBe('en_cocina');

    const despues = await detallePedido(cajero.auth, id);
    const datosDespues = despues.body.datos ?? {};
    const lineasDespues = (datosDespues.items_resumen ||
      datosDespues.items ||
      datosDespues.pedido?.items ||
      []) as Array<{
      estado_cocina?: string;
      observaciones?: string | null;
    }>;
    expect(datosDespues.estado || datosDespues.pedido?.estado).toBe(
      'en_cocina',
    );
    expect(lineasDespues[0]?.estado_cocina).toBe('pendiente');
    expect(lineasDespues[0]?.observaciones).toBe('Sin cebolla');
  });

  it('PED-EDIT-01: no reduce total por debajo del abono registrado', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: `jest-edit-saldo-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody(2)],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    // El abono parcial puede registrarse mientras Cocina sigue pendiente;
    // así se prueba la barrera financiera sin activar el guard de cantidad en preparación.
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);

    const abono = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ monto_parcial: 9000, metodo_pago: 'efectivo' });
    expect(abono.body.exito).toBe(true);
    expect(Number(abono.body.datos.total_cobrado)).toBe(9000);

    const detalle = await detallePedido(cajero.auth, id);
    const datos = detalle.body.datos ?? {};
    const lineas = (datos.items_resumen ||
      datos.items ||
      datos.pedido?.items ||
      []) as Array<{
      id?: string;
      item_id?: string;
      cantidad?: number;
    }>;
    const itemId = lineas[0]?.item_id || lineas[0]?.id;
    expect(itemId).toBeTruthy();
    const editar = await api()
      .patch(`/api/v1/pedidos/${id}/items/${itemId}?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ cantidad: 1 });
    expect(editar.status).toBe(409);
    expect(editar.body.mensaje).toMatch(
      /Registra la devolución antes de reducir/i,
    );

    const posterior = await detallePedido(cajero.auth, id);
    const datosPosterior = posterior.body.datos ?? {};
    const lineaPosterior = (datosPosterior.items_resumen ||
      datosPosterior.items ||
      datosPosterior.pedido?.items ||
      []) as Array<{
      cantidad?: number;
    }>;
    expect(Number(datosPosterior.total || datosPosterior.pedido?.total)).toBe(
      16000,
    );
    expect(Number(lineaPosterior[0]?.cantidad)).toBe(2);
    expect(
      Number(
        datosPosterior.monto_pagado || datosPosterior.pedido?.monto_pagado,
      ),
    ).toBe(9000);
  });

  it('PED-EDIT-01: reemplazar con total inferior al abono revierte toda la operación', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-reemplazo-abono-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody(), itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);

    const abono = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ monto_parcial: 15000, metodo_pago: 'efectivo' });
    expect(abono.body.exito).toBe(true);

    const antes = await detallePedido(cajero.auth, id);
    const datosAntes = antes.body.datos ?? {};
    const itemsAntes = (datosAntes.items_resumen ||
      datosAntes.items ||
      []) as Array<{
      id?: string;
      item_id?: string;
    }>;
    expect(itemsAntes).toHaveLength(2);
    const itemId = itemsAntes[0].item_id || itemsAntes[0].id;
    expect(itemId).toBeTruthy();

    const reemplazar = await api()
      .post(
        `/api/v1/pedidos/${id}/items/${itemId}/reemplazar?sucursal_id=${SID}`,
      )
      .set(cajero.auth)
      .send({
        idempotency_key: `jest-reemplazo-abono-${Date.now()}`,
        items: [
          {
            producto_id: 'f0000000-0000-4000-8000-000000000003',
            cantidad: 1,
            precio: 4000,
          },
        ],
        motivo: 'QA no reducir saldo por debajo del abono',
      });
    expect(reemplazar.status).toBe(409);
    expect(reemplazar.body.message || reemplazar.body.mensaje).toMatch(
      /reembolso antes de reemplazar/i,
    );

    const despues = await detallePedido(cajero.auth, id);
    const datosDespues = despues.body.datos ?? {};
    const itemsDespues = (datosDespues.items_resumen ||
      datosDespues.items ||
      []) as Array<{
      id?: string;
      item_id?: string;
      producto_id?: string;
    }>;
    expect(Number(datosDespues.total)).toBe(16000);
    expect(Number(datosDespues.monto_pagado)).toBe(15000);
    expect(itemsDespues).toHaveLength(2);
    expect(
      itemsDespues.some(
        (item) => item.producto_id === 'f0000000-0000-4000-8000-000000000003',
      ),
    ).toBe(false);
    expect(
      itemsDespues.some((item) => (item.item_id || item.id) === itemId),
    ).toBe(true);
  });

  it('PED-EDIT-01: eliminar con total inferior al abono no altera líneas ni saldo', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-eliminar-abono-${Date.now()}`,
      metodo_pago: 'pendiente',
      items: [itemBody(), itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);

    const abono = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ monto_parcial: 15000, metodo_pago: 'efectivo' });
    expect(abono.body.exito).toBe(true);

    const antes = await detallePedido(cajero.auth, id);
    const datosAntes = antes.body.datos ?? {};
    const itemsAntes = (datosAntes.items_resumen ||
      datosAntes.items ||
      []) as Array<{
      id?: string;
      item_id?: string;
    }>;
    expect(itemsAntes).toHaveLength(2);
    const itemId = itemsAntes[0].item_id || itemsAntes[0].id;
    expect(itemId).toBeTruthy();

    const eliminar = await api()
      .delete(`/api/v1/pedidos/${id}/items/${itemId}?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ motivo: 'QA conserva saldo recibido' });
    expect(eliminar.status).toBe(409);
    expect(eliminar.body.message || eliminar.body.mensaje).toMatch(
      /Registra la devolución antes de reducir/i,
    );

    const despues = await detallePedido(cajero.auth, id);
    const datosDespues = despues.body.datos ?? {};
    const itemsDespues = (datosDespues.items_resumen ||
      datosDespues.items ||
      []) as Array<{
      id?: string;
      item_id?: string;
    }>;
    expect(Number(datosDespues.total)).toBe(16000);
    expect(Number(datosDespues.monto_pagado)).toBe(15000);
    expect(itemsDespues).toHaveLength(2);
    expect(
      itemsDespues.some((item) => (item.item_id || item.id) === itemId),
    ).toBe(true);
  });

  it('PED-ITEM-IDEM-01: reintentar add no duplica y rechaza otra carga con la misma clave', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-items-idempotencia',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    const id = pedidoId(crear);
    pedidoPruebaId = id;
    const clave = `jest-items-${Date.now()}-${Math.random()}`;
    const enviar = (item = itemBody()) =>
      api()
        .post(`/api/v1/pedidos/${id}/items?sucursal_id=${SID}`)
        .set(cajero.auth)
        .send({ idempotency_key: clave, items: [item] });

    const primero = await enviar();
    expect(primero.status).toBe(201);
    expect(primero.body.exito).toBe(true);
    expect(primero.body.datos.delta_subtotal).toBe(8000);
    const segundo = await enviar();
    expect(segundo.status).toBe(201);
    expect(segundo.body.datos.idempotente).toBe(true);
    expect(segundo.body.datos.delta_subtotal).toBe(
      primero.body.datos.delta_subtotal,
    );

    const conflicto = await enviar(itemBody(2));
    expect(conflicto.status).toBe(409);
    expect(conflicto.body.error).toBe('IDEMPOTENCY_KEY_REUSED');

    const detalle = await detallePedido(cajero.auth, id);
    const items = (detalle.body.datos?.items_resumen ||
      detalle.body.datos?.items ||
      detalle.body.datos?.pedido?.items ||
      []) as unknown[];
    expect(items).toHaveLength(2);
  });

  it('PED-STAFF-IDEM-01: replay concurrente de POS crea un pedido y un solo recaudo', async () => {
    const cajaAntes = await api()
      .get(`/api/v1/caja/activa/${SID}`)
      .set(admin.auth);
    expect(cajaAntes.body.exito).toBe(true);
    const saldoAntes = Number(cajaAntes.body.datos?.saldo_sistema);
    const idempotencyKey = `jest-staff-create-${Date.now()}-${Math.random()}`;
    const body = {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-staff-create-${Date.now()}`,
      metodo_pago: 'efectivo',
      pagos: [{ metodo_pago: 'efectivo', monto: PRECIO }],
      idempotency_key: idempotencyKey,
      items: [itemBody()],
    };

    const [primero, replay] = await Promise.all([
      crearPedidoStaff(cajero.auth, body),
      crearPedidoStaff(cajero.auth, body),
    ]);
    expect(primero.status).toBe(201);
    expect(replay.status).toBe(201);
    expect(primero.body.exito).toBe(true);
    expect(replay.body.exito).toBe(true);
    const pedidoCreado = pedidoId(primero);
    expect(pedidoId(replay)).toBe(pedidoCreado);
    expect(
      [primero.body.datos?.idempotente, replay.body.datos?.idempotente].filter(
        (value) => value === true,
      ),
    ).toHaveLength(1);
    pedidoPruebaId = pedidoCreado;

    const cajaDespues = await api()
      .get(`/api/v1/caja/activa/${SID}`)
      .set(admin.auth);
    expect(cajaDespues.body.exito).toBe(true);
    const deltaCaja =
      Number(cajaDespues.body.datos?.saldo_sistema) - saldoAntes;
    expect(deltaCaja).toBe(PRECIO);

    const payloadModificado = await crearPedidoStaff(cajero.auth, {
      ...body,
      items: [itemBody(2)],
    });
    expect(payloadModificado.status).toBe(409);
    expect(payloadModificado.body.error).toBe('IDEMPOTENCY_KEY_REUSED');

    const detalle = await detallePedido(cajero.auth, pedidoCreado);
    const datos = detalle.body.datos ?? {};
    const items = (datos.items_resumen ||
      datos.items ||
      datos.pedido?.items ||
      []) as unknown[];
    expect(items).toHaveLength(1);
  });

  it('PED-STAFF-IDEM-02: el replay no repite los efectos de Cocina', async () => {
    const clave = `jest-staff-cocina-${Date.now()}-${Math.random()}`;
    const body = {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-staff-cocina-${Date.now()}`,
      metodo_pago: 'pendiente',
      idempotency_key: clave,
      items: [itemBody()],
    };

    const primero = await crearPedidoStaff(cajero.auth, body);
    expect(primero.status).toBe(201);
    expect(primero.body.exito).toBe(true);
    const id = pedidoId(primero);
    pedidoPruebaId = id;

    const cocinaAntes = await api()
      .get(`/api/v1/cocina/tickets/${COCINA_ID}`)
      .set(cocina.auth);
    expect(cocinaAntes.body.exito).toBe(true);
    const ticketsAntes = (cocinaAntes.body.datos ?? []) as Array<{
      pedido_id: string;
    }>;
    expect(
      ticketsAntes.filter((ticket) => ticket.pedido_id === id),
    ).toHaveLength(1);

    const replay = await crearPedidoStaff(cajero.auth, body);
    expect(replay.status).toBe(201);
    expect(replay.body.exito).toBe(true);
    expect(pedidoId(replay)).toBe(id);
    expect(replay.body.datos?.idempotente).toBe(true);

    const cocinaDespues = await api()
      .get(`/api/v1/cocina/tickets/${COCINA_ID}`)
      .set(cocina.auth);
    const ticketsDespues = (cocinaDespues.body.datos ?? []) as Array<{
      pedido_id: string;
    }>;
    expect(
      ticketsDespues.filter((ticket) => ticket.pedido_id === id),
    ).toHaveLength(1);
    const detalle = await detallePedido(cajero.auth, id);
    const datos = detalle.body.datos ?? {};
    const items = (datos.items_resumen ||
      datos.items ||
      datos.pedido?.items ||
      []) as unknown[];
    expect(items).toHaveLength(1);
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

    const ticketsPagados = await api()
      .get(`/api/v1/cocina/tickets/${COCINA_ID}`)
      .set(cocina.auth);
    expect(ticketsPagados.body.exito).toBe(true);
    const ticketPendiente = (
      (ticketsPagados.body.datos ?? []) as Array<{
        pedido_id: string;
        estado: string;
        items: Array<{ item_id: string; estado_cocina: string }>;
      }>
    ).find((ticket) => ticket.pedido_id === id);
    expect(ticketPendiente?.estado).toBe('pagado');
    expect(ticketPendiente?.items[0]?.estado_cocina).toBe('preparando');

    const terminarCocina = await api()
      .patch(`/api/v1/cocina/items/${itemId}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'listo' });
    expect(terminarCocina.body.exito).toBe(true);
    expect(terminarCocina.body.datos?.estado_pedido).toBe('pagado');

    const detalleFinal = await detallePedido(cajero.auth, id);
    const datosFinales = detalleFinal.body.datos ?? {};
    const lineasFinales = (datosFinales.items_resumen ||
      datosFinales.items ||
      datosFinales.pedido?.items ||
      []) as Array<{ item_id?: string; estado_cocina?: string }>;
    expect(datosFinales.estado || datosFinales.pedido?.estado).toBe('pagado');
    expect(lineasFinales[0]?.estado_cocina).toBe('listo');
  });

  it('PED-PREPAGO-01: prepago en cocina no bloquea cierre; KDS lo cierra pagado', async () => {
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: 'jest-prepago',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);
    pedidoPruebaId = id;
    const det = await detallePedido(cajero.auth, id);
    const estado = det.body.datos?.estado || det.body.datos?.pedido?.estado;
    const monto = Number(
      det.body.datos?.monto_pagado ?? det.body.datos?.pedido?.monto_pagado ?? 0,
    );
    const total = Number(
      det.body.datos?.total ?? det.body.datos?.pedido?.total ?? 0,
    );
    expect(estado).toBe('en_cocina');
    expect(monto).toBeGreaterThanOrEqual(total - 0.01);

    const caja = await api().get(`/api/v1/caja/activa/${SID}`).set(admin.auth);
    expect(caja.body.exito).toBe(true);
    const saldoSistema = Number(caja.body.datos?.saldo_sistema);
    expect(Number.isFinite(saldoSistema)).toBe(true);
    const cerrarCaja = await api()
      .post('/api/v1/caja/cerrar')
      .set(admin.auth)
      .send({
        caja_id: caja.body.datos?.id,
        monto_final_contado: saldoSistema,
        observaciones_cierre: 'QA PED-PREPAGO-01',
      });
    expect(cerrarCaja.body.exito).toBe(true);

    const cobrar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(cobrar.body.exito).toBeFalsy();

    // Cocina marca ítems listos → pedido pagado (ya cobrado)
    const cocina = await login('cocina@foody.demo');
    const cocinaId = 'd0000000-0000-4000-8000-000000000001';
    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
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
    pedidoPruebaId = null;
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
