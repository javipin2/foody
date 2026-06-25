import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { CosteoService } from '../costeo/costeo.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { ActualizarCategoriaDto } from './dto/actualizar-categoria.dto';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearCategoriaDto } from './dto/crear-categoria.dto';
import { CrearComboDto } from './dto/crear-combo.dto';
import { CrearExtraDto } from './dto/crear-extra.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ConfigurarItemsIncluidosDto } from './dto/configurar-items-incluidos.dto';

@Injectable()
export class CatalogoService {
  constructor(
    private readonly database: DatabaseService,
    private readonly costeo: CosteoService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  async listarCategorias(sucursalId: string) {
    return this.database.consultar(
      `SELECT id, nombre, orden, activa, imagen_url, created_at
       FROM categorias
       WHERE sucursal_id = $1
       ORDER BY orden ASC, nombre ASC`,
      [sucursalId],
    );
  }

  async crearCategoria(dto: CrearCategoriaDto) {
    const fila = await this.database.consultarUno(
      `INSERT INTO categorias (sucursal_id, nombre, orden, activa)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, orden, activa`,
      [dto.sucursal_id, dto.nombre, dto.orden ?? 0],
    );
    return fila;
  }

  async actualizarCategoria(
    id: string,
    sucursalId: string,
    dto: ActualizarCategoriaDto,
  ) {
    await this.exigirCategoria(id, sucursalId);
    const campos: string[] = [];
    const valores: unknown[] = [];
    let i = 1;

    if (dto.nombre !== undefined) {
      campos.push(`nombre = $${i++}`);
      valores.push(dto.nombre);
    }
    if (dto.orden !== undefined) {
      campos.push(`orden = $${i++}`);
      valores.push(dto.orden);
    }
    if (dto.activa !== undefined) {
      campos.push(`activa = $${i++}`);
      valores.push(dto.activa);
    }
    if (!campos.length) return { id };

    valores.push(id, sucursalId);
    await this.database.consultarUno(
      `UPDATE categorias SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`,
      valores,
    );
    return { id };
  }

  async eliminarCategoria(id: string, sucursalId: string) {
    await this.exigirCategoria(id, sucursalId);
    await this.database.consultarUno(
      `UPDATE categorias SET activa = false WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    return { id, activa: false };
  }

  async listarProductos(sucursalId: string) {
    return this.database.consultar(
      `SELECT p.id, p.nombre, p.descripcion, p.precio, p.precio_para_llevar,
              p.disponible, p.orden, p.categoria_id, c.nombre AS categoria_nombre, p.cocina_id
       FROM productos p
       LEFT JOIN categorias c ON c.id = p.categoria_id
       WHERE p.sucursal_id = $1
       ORDER BY c.orden ASC, p.orden ASC, p.nombre ASC`,
      [sucursalId],
    );
  }

  async crearProducto(dto: CrearProductoDto) {
    const cocinaId =
      dto.cocina_id ??
      (
        await this.database.consultarUno<{ id: string }>(
          `SELECT id FROM cocinas WHERE sucursal_id = $1 AND activa = true LIMIT 1`,
          [dto.sucursal_id],
        )
      )?.id;

    const fila = await this.database.consultarUno(
      `INSERT INTO productos (
         sucursal_id, categoria_id, cocina_id, nombre, descripcion,
         precio, precio_para_llevar, disponible, orden
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       RETURNING id, nombre, precio, precio_para_llevar, disponible, categoria_id`,
      [
        dto.sucursal_id,
        dto.categoria_id,
        cocinaId,
        dto.nombre,
        dto.descripcion ?? null,
        dto.precio,
        dto.precio_para_llevar ?? null,
        dto.disponible ?? true,
        dto.orden ?? 0,
      ],
    );
    return fila;
  }

  async actualizarProducto(
    id: string,
    sucursalId: string,
    dto: ActualizarProductoDto,
  ) {
    await this.exigirProducto(id, sucursalId);
    const campos: string[] = [];
    const valores: unknown[] = [];
    let i = 1;

    const mapa: [keyof ActualizarProductoDto, string][] = [
      ['categoria_id', 'categoria_id'],
      ['cocina_id', 'cocina_id'],
      ['nombre', 'nombre'],
      ['descripcion', 'descripcion'],
      ['precio', 'precio'],
      ['disponible', 'disponible'],
      ['orden', 'orden'],
      ['margen_objetivo', 'margen_objetivo'],
      ['precio_para_llevar', 'precio_para_llevar'],
    ];
    for (const [key, col] of mapa) {
      const v = dto[key];
      if (v !== undefined) {
        campos.push(`${col} = $${i++}`);
        valores.push(v);
      }
    }
    if (!campos.length) return { id };

    valores.push(id, sucursalId);
    await this.database.consultarUno(
      `UPDATE productos SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`,
      valores,
    );
    if (dto.margen_objetivo !== undefined || dto.precio !== undefined) {
      await this.costeo.recalcularProductoPorId(id, sucursalId);
    }
    return { id };
  }

  async cambiarDisponibilidad(
    id: string,
    sucursalId: string,
    disponible: boolean,
  ) {
    await this.exigirProducto(id, sucursalId);
    await this.database.consultarUno(
      `UPDATE productos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`,
      [disponible, id, sucursalId],
    );
    void this.realtime.catalogoDisponibilidad(sucursalId, {
      producto_ids: [id],
      disponible,
    });
    return { id, disponible };
  }

  listarToppings(sucursalId: string) {
    return this.database.consultar(
      `SELECT id, nombre, precio, disponible, created_at
       FROM toppings WHERE sucursal_id = $1 ORDER BY nombre ASC`,
      [sucursalId],
    );
  }

  async crearTopping(dto: CrearExtraDto) {
    return this.database.consultarUno(
      `INSERT INTO toppings (sucursal_id, nombre, precio, disponible)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, precio, disponible`,
      [dto.sucursal_id, dto.nombre, dto.precio],
    );
  }

  async actualizarTopping(
    id: string,
    sucursalId: string,
    datos: { nombre?: string; precio?: number; disponible?: boolean },
  ) {
    await this.exigirTopping(id, sucursalId);
    const campos: string[] = [];
    const valores: unknown[] = [];
    let i = 1;
    if (datos.nombre !== undefined) {
      campos.push(`nombre = $${i++}`);
      valores.push(datos.nombre);
    }
    if (datos.precio !== undefined) {
      campos.push(`precio = $${i++}`);
      valores.push(datos.precio);
    }
    if (datos.disponible !== undefined) {
      campos.push(`disponible = $${i++}`);
      valores.push(datos.disponible);
    }
    if (!campos.length) return { id };
    valores.push(id, sucursalId);
    await this.database.consultarUno(
      `UPDATE toppings SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`,
      valores,
    );
    return { id, ...datos };
  }

  listarBebidas(sucursalId: string) {
    return this.database.consultar(
      `SELECT id, nombre, precio, disponible, created_at
       FROM bebidas WHERE sucursal_id = $1 ORDER BY nombre ASC`,
      [sucursalId],
    );
  }

  async crearBebida(dto: CrearExtraDto) {
    return this.database.consultarUno(
      `INSERT INTO bebidas (sucursal_id, nombre, precio, disponible)
       VALUES ($1,$2,$3,true)
       RETURNING id, nombre, precio, disponible`,
      [dto.sucursal_id, dto.nombre, dto.precio],
    );
  }

  async actualizarBebida(
    id: string,
    sucursalId: string,
    datos: { nombre?: string; precio?: number; disponible?: boolean },
  ) {
    await this.exigirBebida(id, sucursalId);
    const campos: string[] = [];
    const valores: unknown[] = [];
    let i = 1;
    if (datos.nombre !== undefined) {
      campos.push(`nombre = $${i++}`);
      valores.push(datos.nombre);
    }
    if (datos.precio !== undefined) {
      campos.push(`precio = $${i++}`);
      valores.push(datos.precio);
    }
    if (datos.disponible !== undefined) {
      campos.push(`disponible = $${i++}`);
      valores.push(datos.disponible);
    }
    if (!campos.length) return { id };
    valores.push(id, sucursalId);
    await this.database.consultarUno(
      `UPDATE bebidas SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`,
      valores,
    );
    return { id, ...datos };
  }

  async vincularToppingProducto(
    productoId: string,
    toppingId: string,
    sucursalId: string,
  ) {
    await this.exigirProducto(productoId, sucursalId);
    await this.exigirTopping(toppingId, sucursalId);
    await this.database.consultarUno(
      `INSERT INTO producto_toppings (producto_id, topping_id)
       VALUES ($1,$2)
       ON CONFLICT (producto_id, topping_id) DO NOTHING`,
      [productoId, toppingId],
    );
    return { producto_id: productoId, topping_id: toppingId };
  }

  async vincularBebidaProducto(
    productoId: string,
    bebidaId: string,
    sucursalId: string,
  ) {
    await this.exigirProducto(productoId, sucursalId);
    await this.exigirBebida(bebidaId, sucursalId);
    await this.database.consultarUno(
      `INSERT INTO producto_bebidas (producto_id, bebida_id)
       VALUES ($1,$2)
       ON CONFLICT (producto_id, bebida_id) DO NOTHING`,
      [productoId, bebidaId],
    );
    return { producto_id: productoId, bebida_id: bebidaId };
  }

  listarCombos(sucursalId: string) {
    return this.database.consultar(
      `SELECT c.id, c.nombre, c.descripcion, c.precio_fijo, c.disponible, c.imagen_url,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', ci.id,
                    'tipo_item', ci.tipo_item,
                    'item_id', ci.item_id,
                    'cantidad', ci.cantidad
                  )
                ) FILTER (WHERE ci.id IS NOT NULL),
                '[]'
              ) AS items
       FROM combos c
       LEFT JOIN combo_items ci ON ci.combo_id = c.id
       WHERE c.sucursal_id = $1
       GROUP BY c.id
       ORDER BY c.nombre ASC`,
      [sucursalId],
    );
  }

  async crearCombo(dto: CrearComboDto) {
    return this.database.enTransaccion(async (client) => {
      const combo = await client.query<{ id: string }>(
        `INSERT INTO combos (sucursal_id, nombre, descripcion, precio_fijo, disponible)
         VALUES ($1,$2,$3,$4,true)
         RETURNING id`,
        [dto.sucursal_id, dto.nombre, dto.descripcion ?? null, dto.precio_fijo],
      );
      const comboId = combo.rows[0].id;

      for (const item of dto.items) {
        await this.validarComboItem(client, dto.sucursal_id, item);
        await client.query(
          `INSERT INTO combo_items (combo_id, tipo_item, item_id, cantidad)
           VALUES ($1,$2,$3,$4)`,
          [comboId, item.tipo_item, item.item_id, item.cantidad ?? 1],
        );
      }

      return { id: comboId, nombre: dto.nombre, precio_fijo: dto.precio_fijo };
    });
  }

  async cambiarDisponibilidadCombo(
    id: string,
    sucursalId: string,
    disponible: boolean,
  ) {
    await this.exigirCombo(id, sucursalId);
    await this.database.consultarUno(
      `UPDATE combos SET disponible = $1 WHERE id = $2 AND sucursal_id = $3`,
      [disponible, id, sucursalId],
    );
    return { id, disponible };
  }

  private async validarComboItem(
    client: import('pg').PoolClient,
    sucursalId: string,
    item: { tipo_item: string; item_id: string },
  ) {
    if (item.tipo_item === 'producto') {
      await this.exigirProductoEnClient(client, item.item_id, sucursalId);
    } else if (item.tipo_item === 'bebida') {
      const b = await client.query(
        `SELECT id FROM bebidas WHERE id = $1 AND sucursal_id = $2`,
        [item.item_id, sucursalId],
      );
      if (!b.rows[0]) throw new NotFoundException('Bebida no encontrada');
    } else {
      const t = await client.query(
        `SELECT id FROM toppings WHERE id = $1 AND sucursal_id = $2`,
        [item.item_id, sucursalId],
      );
      if (!t.rows[0]) throw new NotFoundException('Topping no encontrado');
    }
  }

  private async exigirCombo(id: string, sucursalId: string) {
    const c = await this.database.consultarUno(
      `SELECT id FROM combos WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!c) throw new NotFoundException('Combo no encontrado');
  }

  private async exigirProductoEnClient(
    client: import('pg').PoolClient,
    id: string,
    sucursalId: string,
  ) {
    const p = await client.query(
      `SELECT id FROM productos WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!p.rows[0]) throw new NotFoundException('Producto no encontrado');
  }

  private async exigirTopping(id: string, sucursalId: string) {
    const t = await this.database.consultarUno(
      `SELECT id FROM toppings WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!t) throw new NotFoundException('Topping no encontrado');
  }

  private async exigirBebida(id: string, sucursalId: string) {
    const b = await this.database.consultarUno(
      `SELECT id FROM bebidas WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!b) throw new NotFoundException('Bebida no encontrada');
  }

  private async exigirCategoria(id: string, sucursalId: string) {
    const c = await this.database.consultarUno(
      `SELECT id FROM categorias WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!c) throw new NotFoundException('Categoría no encontrada');
  }

  async listarItemsIncluidos(productoId: string, sucursalId: string) {
    await this.exigirProducto(productoId, sucursalId);
    return this.costeo.listarItemsIncluidosProducto(productoId, sucursalId);
  }

  async configurarItemsIncluidos(
    productoId: string,
    sucursalId: string,
    dto: ConfigurarItemsIncluidosDto,
  ) {
    await this.exigirProducto(productoId, sucursalId);
    const items = dto.items ?? [];

    for (const item of items) {
      if (item.producto_incluido_id === productoId) {
        throw new BadRequestException('Un producto no puede incluirse a sí mismo');
      }
      await this.exigirProducto(item.producto_incluido_id, sucursalId);
    }

    await this.database.enTransaccion(async (client) => {
      await this.validarSinCicloIncluidos(client, productoId, items);
      await client.query(
        `DELETE FROM producto_items_incluidos
         WHERE producto_id = $1 AND sucursal_id = $2`,
        [productoId, sucursalId],
      );
      for (const item of items) {
        await client.query(
          `INSERT INTO producto_items_incluidos (
             sucursal_id, producto_id, producto_incluido_id, cantidad
           ) VALUES ($1,$2,$3,$4)`,
          [
            sucursalId,
            productoId,
            item.producto_incluido_id,
            item.cantidad,
          ],
        );
      }
    });

    await this.costeo.recalcularProductoPorId(productoId, sucursalId);
    return this.listarItemsIncluidos(productoId, sucursalId);
  }

  private async validarSinCicloIncluidos(
    client: PoolClient,
    productoId: string,
    items: { producto_incluido_id: string }[],
  ): Promise<void> {
    for (const item of items) {
      const visitados = new Set<string>();
      const cola = [item.producto_incluido_id];
      while (cola.length) {
        const actual = cola.shift()!;
        if (actual === productoId) {
          throw new BadRequestException(
            'Configuración circular de ítems incluidos',
          );
        }
        if (visitados.has(actual)) continue;
        visitados.add(actual);
        const hijos = await client.query<{ producto_incluido_id: string }>(
          `SELECT producto_incluido_id FROM producto_items_incluidos
           WHERE producto_id = $1`,
          [actual],
        );
        for (const h of hijos.rows) {
          cola.push(h.producto_incluido_id);
        }
      }
    }
  }

  private async exigirProducto(id: string, sucursalId: string) {
    const p = await this.database.consultarUno(
      `SELECT id FROM productos WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!p) throw new NotFoundException('Producto no encontrado');
  }
}
