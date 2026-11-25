/**
 * COC-PRODUCT-KITCHEN-ROUTE-01: valida Catalogo -> pedido -> KDS en una API
 * E2E conectada exclusivamente a una base QA desechable.
 */
import {
  api,
  assertApiViva,
  crearPedidoStaff,
  detallePedido,
  login,
  pedidoId,
  SID,
  TokenBundle,
} from '../helpers/foody-e2e';

describe('E2E enrutamiento Catálogo -> Cocina/KDS', () => {
  let admin: TokenBundle;
  let cajero: TokenBundle;
  let cocina: TokenBundle;
  let cocinaId: string;
  let categoriaId: string;

  beforeAll(async () => {
    await assertApiViva();
    admin = await login('admin@foody.demo');
    cajero = await login('cajero.test@foody.demo');
    cocina = await login('cocina@foody.demo');

    const [cocinas, categorias] = await Promise.all([
      api().get(`/api/v1/cocinas/${SID}`).set(admin.auth),
      api().get(`/api/v1/categorias/${SID}`).set(admin.auth),
    ]);
    expect(cocinas.body.exito).toBe(true);
    expect(categorias.body.exito).toBe(true);
    cocinaId = cocinas.body.datos.find(
      (item: { activa: boolean }) => item.activa,
    )?.id;
    categoriaId = categorias.body.datos.find(
      (item: { activa: boolean }) => item.activa,
    )?.id;
    expect(cocinaId).toBeTruthy();
    expect(categoriaId).toBeTruthy();
  });

  it('asigna cocina predeterminada y enruta el producto nuevo hasta el ticket listo', async () => {
    const sufijo = `${Date.now()}-${Math.floor(Math.random() * 10000)}`;
    const nombre = `E2E Ruta Cocina ${sufijo}`;
    const precio = 12345;
    const crearProducto = await api()
      .post('/api/v1/productos')
      .set(admin.auth)
      .send({
        sucursal_id: SID,
        categoria_id: categoriaId,
        nombre,
        precio,
      });

    expect(crearProducto.status).toBe(201);
    expect(crearProducto.body.exito).toBe(true);
    const productoId = crearProducto.body.datos.id;
    expect(productoId).toBeTruthy();

    const productos = await api()
      .get(`/api/v1/productos/sucursal/${SID}`)
      .set(admin.auth);
    const producto = (
      productos.body.datos as Array<{
        id: string;
        nombre: string;
        precio: number | string;
        cocina_id: string | null;
        disponible: boolean;
      }>
    ).find((item) => item.id === productoId);
    expect(producto).toMatchObject({
      nombre,
      cocina_id: cocinaId,
      disponible: true,
    });
    expect(Number(producto?.precio)).toBe(precio);

    const pedido = await crearPedidoStaff(cajero.auth, {
      sucursal_id: SID,
      tipo: 'para_llevar',
      device_id: `jest-catalogo-cocina-${sufijo}`,
      metodo_pago: 'pendiente',
      items: [{ producto_id: productoId, cantidad: 1, precio }],
    });
    expect(pedido.body.exito).toBe(true);
    const idPedido = pedidoId(pedido);

    const tickets = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    expect(tickets.body.exito).toBe(true);
    const ticket = (
      tickets.body.datos as Array<{
        pedido_id: string;
        items: Array<{
          item_id?: string;
          id?: string;
          nombre?: string;
          producto_nombre?: string;
          producto?: string;
          producto_id?: string;
          estado_cocina?: string;
        }>;
      }>
    ).find((row) => row.pedido_id === idPedido);
    expect(ticket).toBeTruthy();
    const item = ticket!.items.find(
      (row) =>
        row.nombre === nombre ||
        row.producto_nombre === nombre ||
        row.producto === nombre ||
        row.producto_id === productoId,
    );
    expect(item).toBeTruthy();
    const itemId = item!.item_id || item!.id;
    expect(itemId).toBeTruthy();

    const preparando = await api()
      .patch(`/api/v1/cocina/items/${itemId}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'preparando' });
    expect(preparando.body.exito).toBe(true);
    const listo = await api()
      .patch(`/api/v1/cocina/items/${itemId}/estado`)
      .set(cocina.auth)
      .send({ estado_cocina: 'listo' });
    expect(listo.body.exito).toBe(true);

    const detalle = await detallePedido(cajero.auth, idPedido);
    expect(detalle.body.exito).toBe(true);
    expect(detalle.body.datos.estado).toBe('listo');
    const ticketsFinales = await api()
      .get(`/api/v1/cocina/tickets/${cocinaId}`)
      .set(cocina.auth);
    const ticketFinal = (
      ticketsFinales.body.datos as Array<{
        pedido_id: string;
        items: Array<{ producto?: string; estado_cocina?: string }>;
      }>
    ).find((row) => row.pedido_id === idPedido);
    expect(ticketFinal?.items).toContainEqual(
      expect.objectContaining({ producto: nombre, estado_cocina: 'listo' }),
    );
  });
});
