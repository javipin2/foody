import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { AlmacenamientoService } from '../almacenamiento/almacenamiento.service';
import {
  ActualizarPromocionDto,
  CrearPromocionDto,
} from './dto/promocion.dto';

@Injectable()
export class PromocionesService {
  private readonly logger = new Logger(PromocionesService.name);

  constructor(
    private readonly database: DatabaseService,
    private readonly almacenamiento: AlmacenamientoService,
  ) {}

  listarActivas(sucursalId: string) {
    return this.database.consultar(
      `SELECT p.id, p.titulo, p.imagen_url, p.tipo_media, p.descripcion, p.codigo,
              p.descuento_porcentaje, p.descuento_monto,
              p.expira_at, p.vistas, p.created_at,
              p.producto_id, pr.nombre AS producto_nombre
       FROM estados_promociones p
       LEFT JOIN productos pr ON pr.id = p.producto_id
       WHERE p.sucursal_id = $1
         AND p.activa = true
         AND (p.expira_at IS NULL OR p.expira_at > now())
       ORDER BY p.created_at DESC`,
      [sucursalId],
    );
  }

  /** Historias agrupadas por restaurante en una ciudad (app cliente P02). */
  listarStoriesPorCiudad(slug: string) {
    return this.database.consultar(
      `SELECT r.id AS restaurante_id,
              r.nombre AS restaurante_nombre,
              r.logo_url,
              r.banner_url,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', p.id,
                    'titulo', p.titulo,
                    'imagen_url', p.imagen_url,
                    'tipo_media', p.tipo_media,
                    'descripcion', p.descripcion,
                    'sucursal_id', s.id,
                    'producto_id', p.producto_id,
                    'producto_nombre', pr.nombre,
                    'expira_at', p.expira_at
                  )
                  ORDER BY p.created_at DESC
                ) FILTER (WHERE p.id IS NOT NULL),
                '[]'::json
              ) AS promociones
       FROM restaurantes r
       INNER JOIN ciudades c ON c.id = r.ciudad_id
       LEFT JOIN sucursales s ON s.restaurante_id = r.id AND s.activa = true
       LEFT JOIN estados_promociones p ON p.sucursal_id = s.id
         AND p.activa = true
         AND (p.expira_at IS NULL OR p.expira_at > now())
       LEFT JOIN productos pr ON pr.id = p.producto_id
       WHERE c.slug = $1 AND c.activa = true AND r.activo = true
       GROUP BY r.id, r.nombre, r.logo_url, r.banner_url
       HAVING COUNT(p.id) > 0
       ORDER BY r.nombre ASC`,
      [slug],
    );
  }

  listarAdmin(sucursalId: string) {
    return this.database.consultar(
      `SELECT p.id, p.titulo, p.imagen_url, p.tipo_media, p.descripcion, p.codigo,
              p.descuento_porcentaje, p.descuento_monto,
              p.activa, p.expira_at, p.vistas, p.created_at,
              p.producto_id, pr.nombre AS producto_nombre
       FROM estados_promociones p
       LEFT JOIN productos pr ON pr.id = p.producto_id
       WHERE p.sucursal_id = $1
       ORDER BY p.created_at DESC`,
      [sucursalId],
    );
  }

  async crear(dto: CrearPromocionDto) {
    if (!dto.imagen_url?.trim()) {
      throw new BadRequestException('La URL de media es obligatoria');
    }
    const tipoMedia = dto.tipo_media === 'video' ? 'video' : 'imagen';
    this.validarDescuentoDto(dto.descuento_porcentaje, dto.descuento_monto, dto.codigo);
    if (dto.producto_id) {
      await this.exigirProductoDeSucursal(dto.producto_id, dto.sucursal_id);
    }
    // ponytail: estados tipo WhatsApp — 24h por defecto si no envían fecha
    const expiraAt =
      dto.expira_at ?? new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
    return this.database.consultarUno(
      `INSERT INTO estados_promociones (
         sucursal_id, titulo, imagen_url, tipo_media, descripcion, expira_at, activa,
         codigo, descuento_porcentaje, descuento_monto, producto_id
       ) VALUES ($1, $2, $3, $4, $5, $6, true, $7, $8, $9, $10)
       RETURNING id, titulo, imagen_url, tipo_media, descripcion, codigo,
                 descuento_porcentaje, descuento_monto, activa, expira_at,
                 vistas, created_at, producto_id`,
      [
        dto.sucursal_id,
        dto.titulo?.trim() || null,
        dto.imagen_url.trim(),
        tipoMedia,
        dto.descripcion?.trim() || null,
        expiraAt,
        dto.codigo?.trim().toUpperCase() || null,
        dto.descuento_porcentaje ?? null,
        dto.descuento_monto ?? null,
        dto.producto_id ?? null,
      ],
    );
  }

  async actualizar(
    id: string,
    sucursalId: string,
    dto: ActualizarPromocionDto,
  ) {
    await this.exigirPromocion(id, sucursalId);
    const campos: string[] = [];
    const valores: unknown[] = [];
    let i = 1;
    if (dto.titulo !== undefined) {
      campos.push(`titulo = $${i++}`);
      valores.push(dto.titulo.trim() || null);
    }
    if (dto.imagen_url !== undefined) {
      campos.push(`imagen_url = $${i++}`);
      valores.push(dto.imagen_url.trim());
    }
    if (dto.descripcion !== undefined) {
      campos.push(`descripcion = $${i++}`);
      valores.push(dto.descripcion.trim() || null);
    }
    if (dto.expira_at !== undefined) {
      campos.push(`expira_at = $${i++}`);
      valores.push(dto.expira_at || null);
    }
    if (dto.activa !== undefined) {
      campos.push(`activa = $${i++}`);
      valores.push(dto.activa);
    }
    if (dto.codigo !== undefined) {
      campos.push(`codigo = $${i++}`);
      valores.push(dto.codigo.trim().toUpperCase() || null);
    }
    if (dto.descuento_porcentaje !== undefined) {
      campos.push(`descuento_porcentaje = $${i++}`);
      valores.push(dto.descuento_porcentaje);
    }
    if (dto.descuento_monto !== undefined) {
      campos.push(`descuento_monto = $${i++}`);
      valores.push(dto.descuento_monto);
    }
    if (dto.producto_id !== undefined) {
      if (dto.producto_id) {
        await this.exigirProductoDeSucursal(dto.producto_id, sucursalId);
      }
      campos.push(`producto_id = $${i++}`);
      valores.push(dto.producto_id || null);
    }
    if (!campos.length) return { id };
    valores.push(id, sucursalId);
    return this.database.consultarUno(
      `UPDATE estados_promociones SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}
       RETURNING id, titulo, imagen_url, descripcion, codigo,
                 descuento_porcentaje, descuento_monto, activa, expira_at,
                 vistas, created_at, producto_id`,
      valores,
    );
  }

  /** Valida código y calcula monto de descuento sobre subtotal (checkout). */
  async previewCodigo(sucursalId: string, codigo: string, subtotal: number) {
    return this.database.enTransaccion((client) =>
      this.resolverDescuentoPorCodigo(client, sucursalId, codigo, subtotal),
    );
  }

  async resolverDescuentoPorCodigo(
    client: PoolClient,
    sucursalId: string,
    codigo: string,
    subtotal: number,
  ): Promise<{ promocion_id: string; monto: number; motivo: string }> {
    const normalizado = codigo.trim().toUpperCase();
    if (!normalizado) {
      throw new BadRequestException({
        error: 'PROMOCION_CODIGO_VACIO',
        message: 'Indica un código promocional',
      });
    }

    const promo = await client.query<{
      id: string;
      titulo: string | null;
      codigo: string;
      descuento_porcentaje: string | null;
      descuento_monto: string | null;
    }>(
      `SELECT id, titulo, codigo, descuento_porcentaje, descuento_monto
       FROM estados_promociones
       WHERE sucursal_id = $1
         AND activa = true
         AND (expira_at IS NULL OR expira_at > now())
         AND lower(trim(codigo)) = lower($2)`,
      [sucursalId, normalizado],
    );

    const fila = promo.rows[0];
    if (!fila) {
      throw new BadRequestException({
        error: 'PROMOCION_INVALIDA',
        message: 'Código promocional no válido o expirado',
      });
    }

    const pct = fila.descuento_porcentaje != null
      ? Number(fila.descuento_porcentaje)
      : null;
    const fijo = fila.descuento_monto != null ? Number(fila.descuento_monto) : null;

    if ((pct == null || pct <= 0) && (fijo == null || fijo <= 0)) {
      throw new BadRequestException({
        error: 'PROMOCION_SIN_DESCUENTO',
        message: 'Esta promoción no tiene descuento configurado',
      });
    }

    let monto = 0;
    if (pct != null && pct > 0) {
      monto = Math.round((subtotal * pct) / 100);
    } else if (fijo != null && fijo > 0) {
      monto = Math.round(fijo);
    }
    monto = Math.min(monto, subtotal);
    if (monto <= 0) {
      throw new BadRequestException({
        error: 'PROMOCION_SIN_APLICAR',
        message: 'El descuento no aplica al subtotal actual',
      });
    }

    const motivo = fila.titulo?.trim()
      ? `Promoción: ${fila.titulo} (${fila.codigo})`
      : `Promoción ${fila.codigo}`;

    return { promocion_id: fila.id, monto, motivo };
  }

  /** Mejor promo vigente sin código (mayor descuento aplicable). */
  async resolverMejorAutomatica(
    client: PoolClient,
    sucursalId: string,
    subtotal: number,
  ): Promise<{ promocion_id: string; monto: number; motivo: string } | null> {
    const promos = await client.query<{
      id: string;
      titulo: string;
      descuento_porcentaje: string | null;
      descuento_monto: string | null;
    }>(
      `SELECT id, titulo, descuento_porcentaje, descuento_monto
       FROM estados_promociones
       WHERE sucursal_id = $1
         AND activa = true
         AND (expira_at IS NULL OR expira_at > now())
         AND (codigo IS NULL OR trim(codigo) = '')
         AND (descuento_porcentaje > 0 OR descuento_monto > 0)`,
      [sucursalId],
    );
    let mejor: { promocion_id: string; monto: number; motivo: string } | null =
      null;
    for (const fila of promos.rows) {
      const pct =
        fila.descuento_porcentaje != null
          ? Number(fila.descuento_porcentaje)
          : null;
      const fijo =
        fila.descuento_monto != null ? Number(fila.descuento_monto) : null;
      let monto = 0;
      if (pct != null && pct > 0) monto = Math.round((subtotal * pct) / 100);
      else if (fijo != null && fijo > 0) monto = Math.round(fijo);
      monto = Math.min(monto, subtotal);
      if (monto <= 0) continue;
      if (!mejor || monto > mejor.monto) {
        mejor = {
          promocion_id: fila.id,
          monto,
          motivo: fila.titulo?.trim()
            ? `Promo automática: ${fila.titulo}`
            : 'Promoción automática',
        };
      }
    }
    return mejor;
  }

  private validarDescuentoDto(
    porcentaje?: number,
    monto?: number,
    codigo?: string,
  ) {
    if (codigo?.trim() && porcentaje == null && monto == null) {
      throw new BadRequestException(
        'Si defines un código, indica descuento_porcentaje o descuento_monto',
      );
    }
    if (porcentaje != null && monto != null) {
      throw new BadRequestException(
        'Usa solo descuento_porcentaje o descuento_monto, no ambos',
      );
    }
  }

  async registrarVista(promocionId: string, deviceId: string) {
    const promo = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM estados_promociones
       WHERE id = $1 AND activa = true
         AND (expira_at IS NULL OR expira_at > now())`,
      [promocionId],
    );
    if (!promo) throw new NotFoundException('Promoción no encontrada');

    await this.database.consultar(
      `INSERT INTO dispositivos_cliente (device_id, ultimo_acceso)
       VALUES ($1, now())
       ON CONFLICT (device_id) DO UPDATE SET ultimo_acceso = now()`,
      [deviceId],
    );

    const existente = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM promocion_vistas
       WHERE promocion_id = $1 AND device_id = $2`,
      [promocionId, deviceId],
    );
    if (!existente) {
      await this.database.consultar(
        `INSERT INTO promocion_vistas (promocion_id, device_id) VALUES ($1, $2)`,
        [promocionId, deviceId],
      );
      await this.database.consultar(
        `UPDATE estados_promociones SET vistas = vistas + 1 WHERE id = $1`,
        [promocionId],
      );
    }
    return { registrado: true };
  }

  private async exigirPromocion(id: string, sucursalId: string) {
    const fila = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM estados_promociones WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!fila) throw new NotFoundException('Promoción no encontrada');
  }

  async eliminar(id: string, sucursalId: string) {
    const fila = await this.database.consultarUno<{
      id: string;
      imagen_url: string;
    }>(
      `SELECT id, imagen_url FROM estados_promociones WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!fila) throw new NotFoundException('Promoción no encontrada');
    await this.database.consultar(
      `DELETE FROM promocion_vistas WHERE promocion_id = $1`,
      [id],
    );
    await this.database.consultar(
      `DELETE FROM estados_promociones WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    await this.almacenamiento.eliminarPorUrl(fila.imagen_url);
    return { eliminado: true };
  }

  /**
   * STOR-01: borra estados con expira_at < now()-7d y su objeto en Storage.
   * Idempotente. Grace 7 días por si alguien reabre ventana de vistas.
   */
  async limpiarExpiradas(diasGracia = 7): Promise<{
    filas: number;
    objetos_storage: number;
  }> {
    const gracia = Number.isFinite(diasGracia) && diasGracia >= 0 ? diasGracia : 7;
    const filas = await this.database.consultar<{
      id: string;
      imagen_url: string;
    }>(
      `SELECT id, imagen_url FROM estados_promociones
       WHERE expira_at IS NOT NULL
         AND expira_at < now() - ($1::int * interval '1 day')
       LIMIT 200`,
      [gracia],
    );
    let objetos = 0;
    for (const f of filas) {
      if (await this.almacenamiento.eliminarPorUrl(f.imagen_url)) objetos += 1;
      await this.database.consultar(
        `DELETE FROM promocion_vistas WHERE promocion_id = $1`,
        [f.id],
      );
      await this.database.consultar(
        `DELETE FROM estados_promociones WHERE id = $1`,
        [f.id],
      );
    }
    if (filas.length > 0) {
      this.logger.log(
        `Limpieza estados: ${filas.length} filas, ${objetos} objetos Storage`,
      );
    }
    return { filas: filas.length, objetos_storage: objetos };
  }

  private async exigirProductoDeSucursal(
    productoId: string,
    sucursalId: string,
  ) {
    const fila = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM productos
       WHERE id = $1 AND sucursal_id = $2 AND disponible = true`,
      [productoId, sucursalId],
    );
    if (!fila) {
      throw new BadRequestException(
        'El producto no pertenece a esta sede o no está disponible',
      );
    }
  }
}
