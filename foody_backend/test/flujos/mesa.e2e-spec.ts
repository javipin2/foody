/**
 * Flujo crítico: mesa (staff) — crear → listo → pagando → bloquear entregado sin cobro → cobrar.
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
  marcarItemsCocinaListos,
  mesaLibre,
  PRECIO,
  pedidoId,
  setEstado,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';
import { randomUUID } from 'crypto';

describe('E2E mesa', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;
  let cocina: TokenBundle;

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

  it('ciclo mesa: cobro y bloqueo entregado sin pagar (R1)', async () => {
    const mesa = await mesaLibre(cajero.auth);
    const crear = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      mesa_id: mesa,
      tipo: 'mesa',
      device_id: 'jest-mesa-ciclo',
      metodo_pago: 'efectivo',
      items: [itemBody()],
    });
    expect(crear.body.exito).toBe(true);
    const id = pedidoId(crear);

    await marcarItemsCocinaListos(cocina.auth, id, cajero.auth);
    // Si cocina ya dejó el pedido en listo, setEstado es no-op OK
    const aListo = await setEstado(cajero.auth, id, 'listo');
    if (!aListo.body.exito) {
      const det = await api()
        .get(`/api/v1/pedidos/${id}/detalle?sucursal_id=${SID}`)
        .set(cajero.auth);
      const est = det.body.datos?.estado || det.body.datos?.pedido?.estado;
      expect(est).toBe('listo');
    }
    expect((await setEstado(cajero.auth, id, 'pagando')).body.exito).toBe(true);

    const saltar = await setEstado(cajero.auth, id, 'entregado');
    expect(saltar.body.exito).toBeFalsy();

    const cobrar = await api()
      .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
      .set(cajero.auth)
      .send({ metodo_pago: 'efectivo' });
    expect(cobrar.body.exito).toBe(true);
  });

  it('mesero crea y presenta cuenta, pero no cocina ni cobra', async () => {
    const email = `mesero-e2e-${randomUUID()}@qa.example`;
    const creado = await api().post('/api/v1/usuarios').set(admin.auth).send({
      nombre: 'Mesero E2E',
      email,
      contrasena: '123456',
      rol: 'mesero',
      sucursal_id: SID,
    });
    expect(creado.body.exito).toBe(true);
    const usuarioId = creado.body.datos?.id as string;
    expect(usuarioId).toBeTruthy();

    try {
      const mesero = await login(email);
      const recoger = await crearPedidoStaff(mesero.auth, {
        sucursal_id: SID,
        tipo: 'para_llevar',
        device_id: `jest-mesero-recoger-${Date.now()}`,
        metodo_pago: 'efectivo',
        items: [itemBody()],
      });
      expect(recoger.body.exito).toBe(true);
      const recogerId = pedidoId(recoger);
      const detalleRecoger = await detallePedido(admin.auth, recogerId);
      const pedidoRecoger =
        detalleRecoger.body.datos?.pedido ?? detalleRecoger.body.datos;
      expect(Number(pedidoRecoger.monto_pagado ?? 0)).toBe(0);
      const pagoSinPermiso = await crearPedidoStaff(mesero.auth, {
        sucursal_id: SID,
        tipo: 'para_llevar',
        device_id: `jest-mesero-pago-${Date.now()}`,
        metodo_pago: 'efectivo',
        pagos: [{ metodo_pago: 'efectivo', monto: PRECIO }],
        items: [itemBody()],
      });
      expect(pagoSinPermiso.status).toBe(403);

      const mesa = await mesaLibre(cajero.auth);
      const crear = await crearPedidoStaff(mesero.auth, {
        sucursal_id: SID,
        mesa_id: mesa,
        tipo: 'mesa',
        device_id: `jest-mesero-${Date.now()}`,
        metodo_pago: 'pendiente',
        items: [itemBody()],
      });
      expect(crear.body.exito).toBe(true);
      const id = pedidoId(crear);
      expect(crear.body.datos?.estado).toBe('en_cocina');

      const cocinaNoPermitida = await setEstado(mesero.auth, id, 'listo');
      expect(cocinaNoPermitida.status).toBe(403);

      const presentar = await setEstado(mesero.auth, id, 'pagando');
      expect(presentar.body.exito).toBe(true);
      expect(presentar.body.datos?.estado).toBe('pagando');

      const cobrar = await api()
        .post(`/api/v1/pedidos/${id}/cobrar?sucursal_id=${SID}`)
        .set(mesero.auth)
        .send({ metodo_pago: 'efectivo' });
      expect(cobrar.status).toBe(403);
    } finally {
      await api()
        .patch(`/api/v1/usuarios/${usuarioId}/estado?sucursal_id=${SID}`)
        .set(admin.auth)
        .send({ activo: false });
      await limpiarPedidosActivos(admin.auth);
    }
  });

  it('muestra desde una mesa secundaria la cuenta unificada de todo el grupo', async () => {
    const mesas = await api().get(`/api/v1/mesas/${SID}`).set(admin.auth);
    expect(mesas.body.exito).toBe(true);
    const disponibles = (
      mesas.body.datos as Array<{
        id: string;
        pedido_id?: string;
        mesa_grupo_id?: string | null;
      }>
    ).filter((m) => !m.pedido_id);
    expect(disponibles.length).toBeGreaterThanOrEqual(2);
    const [principal, secundaria] = disponibles;
    console.log(`QA_MESAS_GRUPO=${principal.id},${secundaria.id}`);

    const pedidos = [principal, secundaria];
    for (const [index, mesa] of pedidos.entries()) {
      const creado = await crearPedidoStaff(cajero.auth, {
        sucursal_id: SID,
        mesa_id: mesa.id,
        tipo: 'mesa',
        device_id: `jest-mesa-grupo-${Date.now()}-${index}`,
        metodo_pago: 'efectivo',
        items: [itemBody()],
      });
      expect(creado.body.exito).toBe(true);
    }

    const unir = await api()
      .post('/api/v1/mesas/unir')
      .set(admin.auth)
      .send({
        sucursal_id: SID,
        mesa_principal_id: principal.id,
        mesas_secundarias: [secundaria.id],
      });
    expect(unir.body.exito).toBe(true);

    const cuenta = await api()
      .get(`/api/v1/pedidos/mesa/${secundaria.id}?sucursal_id=${SID}`)
      .set(cajero.auth);
    expect(cuenta.body.exito).toBe(true);
    expect(cuenta.body.datos.cuenta.cantidad_tickets).toBe(2);
    expect(cuenta.body.datos.pedidos).toHaveLength(2);
    expect(cuenta.body.datos.total_acumulado).toBe(PRECIO * 2);
  });

  it('consolida grupos existentes sin dejar miembros huérfanos', async () => {
    const mesas = await api().get(`/api/v1/mesas/${SID}`).set(admin.auth);
    expect(mesas.body.exito).toBe(true);
    const disponibles = (
      mesas.body.datos as Array<{
        id: string;
        pedido_id?: string;
        mesa_grupo_id?: string | null;
      }>
    ).filter((m) => !m.pedido_id);
    expect(disponibles.length).toBeGreaterThanOrEqual(3);
    const [principalAnterior, miembroAnterior, nuevoPrincipal] = disponibles;
    console.log(
      `QA_MESAS_REAGRUPADAS=${principalAnterior.id},${miembroAnterior.id},${nuevoPrincipal.id}`,
    );

    for (const [index, mesa] of [
      principalAnterior,
      miembroAnterior,
      nuevoPrincipal,
    ].entries()) {
      const creado = await crearPedidoStaff(cajero.auth, {
        sucursal_id: SID,
        mesa_id: mesa.id,
        tipo: 'mesa',
        device_id: `jest-mesa-regrupo-${Date.now()}-${index}`,
        metodo_pago: 'efectivo',
        items: [itemBody()],
      });
      expect(creado.body.exito).toBe(true);
    }

    const grupoInicial = await api()
      .post('/api/v1/mesas/unir')
      .set(admin.auth)
      .send({
        sucursal_id: SID,
        mesa_principal_id: principalAnterior.id,
        mesas_secundarias: [miembroAnterior.id],
      });
    expect(grupoInicial.body.exito).toBe(true);

    const [grupoAmpliado, grupoAmpliadoEnParalelo] = await Promise.all([
      api()
        .post('/api/v1/mesas/unir')
        .set(admin.auth)
        .send({
          sucursal_id: SID,
          mesa_principal_id: nuevoPrincipal.id,
          mesas_secundarias: [principalAnterior.id],
        }),
      api()
        .post('/api/v1/mesas/unir')
        .set(admin.auth)
        .send({
          sucursal_id: SID,
          mesa_principal_id: principalAnterior.id,
          mesas_secundarias: [miembroAnterior.id],
        }),
    ]);
    expect(grupoAmpliado.body.exito).toBe(true);
    expect(grupoAmpliadoEnParalelo.body.exito).toBe(true);

    const cuenta = await api()
      .get(`/api/v1/pedidos/mesa/${miembroAnterior.id}?sucursal_id=${SID}`)
      .set(cajero.auth);
    expect(cuenta.body.exito).toBe(true);
    expect(cuenta.body.datos.cuenta.cantidad_tickets).toBe(3);
    expect(cuenta.body.datos.pedidos).toHaveLength(3);
    expect(cuenta.body.datos.total_acumulado).toBe(PRECIO * 3);
  });
});
