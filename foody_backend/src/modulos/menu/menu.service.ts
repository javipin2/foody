import { Injectable, NotFoundException } from '@nestjs/common';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { DatabaseService } from '../../core/database/database.service';

interface ProductoFila {
  id: string;
  categoria_id: string;
  nombre: string;
  descripcion: string | null;
  precio: string;
  precio_para_llevar: string | null;
  imagen_url: string | null;
  disponible: boolean;
  orden: number;
  es_encargo: boolean;
}

interface ToppingFila {
  producto_id: string;
  id: string;
  nombre: string;
  precio: string;
}

interface BebidaFila {
  producto_id: string;
  id: string;
  nombre: string;
  precio: string;
}

export interface ComboItemFila {
  combo_id: string;
  id: string;
  tipo_item: string;
  item_id: string;
  cantidad: number;
  nombre_item: string;
}

@Injectable()
export class MenuService {
  constructor(
    private readonly database: DatabaseService,
    private readonly menuCache: MenuCacheService,
  ) {}

  // Single-flight para evitar reconstrucciones paralelas del menú cuando el cache expira.
  private readonly menuConstruyendose = new Map<
    string,
    Promise<Awaited<ReturnType<MenuService['construirMenuSucursal']>>>
  >();

  async obtenerPorMesaQr(qrToken: string) {
    const mesa = await this.database.consultarUno<{
      id: string;
      nombre: string;
      sucursal_id: string;
    }>(
      `SELECT m.id, m.nombre, m.sucursal_id
       FROM mesas m
       INNER JOIN sucursales s ON s.id = m.sucursal_id AND s.activa = true
       WHERE m.qr_token = $1 AND m.activa = true`,
      [qrToken],
    );
    if (!mesa) {
      throw new NotFoundException('MESA_NO_ENCONTRADA');
    }

    const menu = await this.obtenerPorSucursal(mesa.sucursal_id);

    const resumenPedidos = await this.database.consultarUno<{
      activos: number;
      pendientes_qr: number;
      total_pendiente: string;
    }>(
      `SELECT
         COUNT(*)::int AS activos,
         COUNT(*) FILTER (WHERE estado = 'pendiente_aprobacion')::int AS pendientes_qr,
         COALESCE(SUM(total), 0)::text AS total_pendiente
       FROM pedidos
       WHERE mesa_id = $1 AND sucursal_id = $2
         AND estado NOT IN ('cancelado', 'rechazado', 'pagado')`,
      [mesa.id, mesa.sucursal_id],
    );

    return {
      mesa: {
        id: mesa.id,
        nombre: mesa.nombre,
        qr_token: qrToken,
        pedidos_activos: resumenPedidos?.activos ?? 0,
        pedidos_pendientes_qr: resumenPedidos?.pendientes_qr ?? 0,
        total_pendiente_mesa: Number(resumenPedidos?.total_pendiente ?? 0),
      },
      ...menu,
    };
  }

  async obtenerPorSucursal(sucursalId: string) {
    const enCache = await this.menuCache.obtener<Record<string, unknown>>(
      sucursalId,
    );
    if (enCache) return enCache as Awaited<ReturnType<MenuService['construirMenuSucursal']>>;

    const yaEnCurso = this.menuConstruyendose.get(sucursalId);
    if (yaEnCurso) return yaEnCurso;

    const promesa = (async () => {
      const menu = await this.construirMenuSucursal(sucursalId);
      await this.menuCache.guardar(sucursalId, menu);
      return menu;
    })();

    this.menuConstruyendose.set(sucursalId, promesa);
    try {
      return await promesa;
    } finally {
      this.menuConstruyendose.delete(sucursalId);
    }
  }

  private async construirMenuSucursal(sucursalId: string) {
    const sucursal = await this.database.consultarUno<{
      id: string;
      nombre: string;
      restaurante_id: string;
      restaurante_nombre: string;
      ciudad_id: string;
      ciudad_nombre: string;
      ciudad_slug: string;
    }>(
      `SELECT s.id, s.nombre,
              r.id AS restaurante_id, r.nombre AS restaurante_nombre,
              c.id AS ciudad_id, c.nombre AS ciudad_nombre, c.slug AS ciudad_slug
       FROM sucursales s
       INNER JOIN restaurantes r ON r.id = s.restaurante_id AND r.activo = true
       INNER JOIN ciudades c ON c.id = s.ciudad_id AND c.activa = true
       WHERE s.id = $1 AND s.activa = true`,
      [sucursalId],
    );
    if (!sucursal) {
      throw new NotFoundException('Sucursal no encontrada');
    }

    const horario = await this.database.consultarUno<{ activo: boolean }>(
      `SELECT EXISTS (
         SELECT 1 FROM horarios_sucursal h
         WHERE h.sucursal_id = $1
           AND h.activo = true
           AND h.dia_semana = EXTRACT(DOW FROM NOW() AT TIME ZONE 'America/Bogota')::int
           AND (NOW() AT TIME ZONE 'America/Bogota')::time
             BETWEEN h.hora_apertura AND h.hora_cierre
       ) AS activo`,
      [sucursalId],
    );

    const categorias = await this.database.consultar<{
      id: string;
      nombre: string;
      orden: number;
    }>(
      `SELECT id, nombre, orden
       FROM categorias
       WHERE sucursal_id = $1 AND activa = true
       ORDER BY orden ASC, nombre ASC`,
      [sucursalId],
    );

    const productos = await this.database.consultar<ProductoFila>(
      `SELECT id, categoria_id, nombre, descripcion, precio, precio_para_llevar,
              imagen_url, disponible, orden, es_encargo
       FROM productos
       WHERE sucursal_id = $1 AND disponible = true
       ORDER BY orden ASC, nombre ASC`,
      [sucursalId],
    );

    const toppings = await this.database.consultar<ToppingFila>(
      `SELECT pt.producto_id, t.id, t.nombre, t.precio
       FROM producto_toppings pt
       INNER JOIN toppings t ON t.id = pt.topping_id
       WHERE t.sucursal_id = $1 AND t.disponible = true`,
      [sucursalId],
    );

    const bebidas = await this.database.consultar<BebidaFila>(
      `SELECT pb.producto_id, b.id, b.nombre, b.precio
       FROM producto_bebidas pb
       INNER JOIN bebidas b ON b.id = pb.bebida_id
       WHERE b.sucursal_id = $1 AND b.disponible = true`,
      [sucursalId],
    );

    const combosRaw = await this.database.consultar<{
      id: string;
      nombre: string;
      descripcion: string | null;
      precio_fijo: string;
      imagen_url: string | null;
      disponible: boolean;
    }>(
      `SELECT id, nombre, descripcion, precio_fijo, imagen_url, disponible
       FROM combos
       WHERE sucursal_id = $1 AND disponible = true
       ORDER BY nombre ASC`,
      [sucursalId],
    );

    // ponytail: AQ-SCALE-03 — evitar N+1 queries por combo
    // Traemos todos los combo_items de una vez y agrupamos por combo_id.
    const comboIds = combosRaw.map((c) => c.id);
    const itemsRaw = comboIds.length
      ? await this.database.consultar<ComboItemFila>(
          `SELECT ci.combo_id,
                  ci.id,
                  ci.tipo_item,
                  ci.item_id,
                  ci.cantidad,
                  COALESCE(p.nombre, b.nombre, t.nombre, 'Ítem') AS nombre_item
           FROM combo_items ci
           LEFT JOIN productos p
             ON ci.tipo_item = 'producto' AND p.id = ci.item_id
           LEFT JOIN bebidas b
             ON ci.tipo_item = 'bebida' AND b.id = ci.item_id
           LEFT JOIN toppings t
             ON ci.tipo_item = 'topping' AND t.id = ci.item_id
           WHERE ci.combo_id = ANY($1::uuid[])
           ORDER BY ci.combo_id ASC, ci.id ASC`,
          [comboIds],
        )
      : [];

    const itemsPorCombo = new Map<string, ComboItemFila[]>();
    for (const it of itemsRaw) {
      const lista = itemsPorCombo.get(it.combo_id) ?? [];
      lista.push(it);
      itemsPorCombo.set(it.combo_id, lista);
    }

    const combos = combosRaw.map((combo) => ({
      id: combo.id,
      nombre: combo.nombre,
      descripcion: combo.descripcion,
      precio_fijo: Number(combo.precio_fijo),
      imagen_url: combo.imagen_url,
      disponible: combo.disponible,
      items: itemsPorCombo.get(combo.id) ?? [],
    }));

    const toppingsPorProducto = this.agruparPorProducto(toppings);
    const bebidasPorProducto = this.agruparPorProducto(bebidas);

    const productosPorCategoria = new Map<string, ProductoFila[]>();
    for (const producto of productos) {
      const lista = productosPorCategoria.get(producto.categoria_id) ?? [];
      lista.push(producto);
      productosPorCategoria.set(producto.categoria_id, lista);
    }

    const categoriasConProductos = categorias.map((categoria) => ({
      id: categoria.id,
      nombre: categoria.nombre,
      orden: categoria.orden,
      productos: (productosPorCategoria.get(categoria.id) ?? []).map(
        (producto) => ({
          id: producto.id,
          nombre: producto.nombre,
          descripcion: producto.descripcion,
          precio: Number(producto.precio),
          precio_para_llevar:
            producto.precio_para_llevar != null
              ? Number(producto.precio_para_llevar)
              : null,
          imagen_url: producto.imagen_url,
          disponible: producto.disponible,
          es_encargo: producto.es_encargo ?? false,
          toppings_disponibles: (
            toppingsPorProducto.get(producto.id) ?? []
          ).map((t) => ({
            id: t.id,
            nombre: t.nombre,
            precio: Number(t.precio),
          })),
          bebidas_disponibles: (bebidasPorProducto.get(producto.id) ?? []).map(
            (b) => ({
              id: b.id,
              nombre: b.nombre,
              precio: Number(b.precio),
            }),
          ),
        }),
      ),
    }));

    return {
      sucursal: {
        id: sucursal.id,
        nombre: sucursal.nombre,
        horario_activo: horario?.activo ?? false,
        restaurante: {
          id: sucursal.restaurante_id,
          nombre: sucursal.restaurante_nombre,
        },
        ciudad: {
          id: sucursal.ciudad_id,
          nombre: sucursal.ciudad_nombre,
          slug: sucursal.ciudad_slug,
        },
      },
      categorias: categoriasConProductos,
      combos,
    };
  }

  private agruparPorProducto<T extends { producto_id: string }>(
    filas: T[],
  ): Map<string, T[]> {
    const mapa = new Map<string, T[]>();
    for (const fila of filas) {
      const lista = mapa.get(fila.producto_id) ?? [];
      lista.push(fila);
      mapa.set(fila.producto_id, lista);
    }
    return mapa;
  }
}
