import {
  BadRequestException,
  Injectable,
  Logger,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';
import sharp from 'sharp';
import { DatabaseService } from '../../core/database/database.service';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { esQaSinEfectosExternos } from '../../core/config/qa-safety';

export type TipoImagenFoody =
  | 'producto'
  | 'categoria'
  | 'combo'
  | 'promocion'
  | 'general';

const TIPOS_IMAGEN: TipoImagenFoody[] = [
  'producto',
  'categoria',
  'combo',
  'promocion',
  'general',
];

/** Entidades con imagen_url + ownership por sucursal (BN-FIX-01 / AQ-DUP-04). */
type EntidadConImagen = 'producto' | 'promocion' | 'combo' | 'categoria';

const ENTIDAD_IMAGEN: Record<
  EntidadConImagen,
  {
    tabla: string;
    etiqueta: string;
    invalidarMenu: boolean;
    claveRespuesta: string;
  }
> = {
  producto: {
    tabla: 'productos',
    etiqueta: 'Producto',
    invalidarMenu: true,
    claveRespuesta: 'producto_id',
  },
  promocion: {
    tabla: 'promociones',
    etiqueta: 'Promoción',
    invalidarMenu: false,
    claveRespuesta: 'promocion_id',
  },
  combo: {
    tabla: 'combos',
    etiqueta: 'Combo',
    invalidarMenu: true,
    claveRespuesta: 'combo_id',
  },
  categoria: {
    tabla: 'categorias',
    etiqueta: 'Categoría',
    invalidarMenu: true,
    claveRespuesta: 'categoria_id',
  },
};

@Injectable()
export class AlmacenamientoService implements OnModuleInit {
  private readonly logger = new Logger(AlmacenamientoService.name);
  private readonly cliente: SupabaseClient | null;
  private readonly bucket: string;
  private readonly basePublica: string;
  private bucketVerificado = false;

  constructor(
    private readonly config: ConfigService,
    private readonly database: DatabaseService,
    private readonly menuCache: MenuCacheService,
  ) {
    const aislado = esQaSinEfectosExternos();
    const url = aislado ? undefined : this.config.get<string>('SUPABASE_URL');
    const key = aislado
      ? undefined
      : this.config.get<string>('SUPABASE_SERVICE_KEY');
    if (aislado) {
      this.logger.warn('Storage desactivado por FOODY_QA_SIN_EFECTOS');
    }
    this.bucket =
      this.config.get<string>('SUPABASE_STORAGE_BUCKET') ?? 'foody-assets';
    this.cliente = url && key ? createClient(url, key) : null;
    this.basePublica = url
      ? `${url.replace(/\/$/, '')}/storage/v1/object/public/${this.bucket}`
      : '';
  }

  async onModuleInit(): Promise<void> {
    await this.asegurarBucket();
  }

  private async asegurarBucket(): Promise<void> {
    if (!this.cliente || this.bucketVerificado) return;

    const { data: buckets, error: listError } =
      await this.cliente.storage.listBuckets();
    if (listError) {
      this.logger.warn(`Storage listBuckets: ${listError.message}`);
    }

    const existe = buckets?.some(
      (b) => b.id === this.bucket || b.name === this.bucket,
    );
    if (!existe) {
      const { error } = await this.cliente.storage.createBucket(this.bucket, {
        public: true,
        fileSizeLimit: 20 * 1024 * 1024,
        allowedMimeTypes: [
          'image/webp',
          'image/jpeg',
          'image/png',
          'image/gif',
          'video/mp4',
          'video/webm',
          'video/quicktime',
        ],
      });
      if (error) {
        this.logger.warn(
          `Bucket «${this.bucket}» no existe y no se pudo crear: ${error.message}. ` +
            'Ejecuta foody_supabase/migrations/057 y 077 en supabase-db.',
        );
        return;
      }
      this.logger.log(`Bucket storage «${this.bucket}» creado`);
    }
    this.bucketVerificado = true;
  }

  private exigirCliente(): SupabaseClient {
    if (!this.cliente) {
      throw new ServiceUnavailableException(
        'Storage no configurado (SUPABASE_URL / SUPABASE_SERVICE_KEY)',
      );
    }
    return this.cliente;
  }

  async comprimirImagen(buffer: Buffer): Promise<Buffer> {
    return sharp(buffer)
      .rotate()
      .resize(800, 800, {
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 80 })
      .toBuffer();
  }

  construirRuta(
    restauranteId: string,
    sucursalId: string,
    tipo: TipoImagenFoody,
    entidadId?: string,
  ): string {
    const id = entidadId ?? randomUUID();
    return `${restauranteId}/${sucursalId}/${tipo}/${id}.webp`;
  }

  urlPublica(ruta: string): string {
    return `${this.basePublica}/${ruta}`;
  }

  /** Extrae path del bucket desde URL pública o path relativo. */
  rutaDesdeUrl(url: string): string | null {
    const u = (url ?? '').trim();
    if (!u) return null;
    if (!u.startsWith('http')) return u.replace(/^\//, '');
    const marker = `/storage/v1/object/public/${this.bucket}/`;
    const i = u.indexOf(marker);
    if (i < 0) return null;
    return decodeURIComponent(u.slice(i + marker.length));
  }

  /** Best-effort: no lanza si el objeto no existe o Storage no está configurado. */
  async eliminarPorUrl(url: string): Promise<boolean> {
    const ruta = this.rutaDesdeUrl(url);
    if (!ruta || !this.cliente) return false;
    try {
      await this.asegurarBucket();
      const { error } = await this.cliente.storage.from(this.bucket).remove([ruta]);
      if (error) {
        this.logger.warn(`Storage remove «${ruta}»: ${error.message}`);
        return false;
      }
      return true;
    } catch (e) {
      this.logger.warn(
        `Storage remove falló: ${e instanceof Error ? e.message : String(e)}`,
      );
      return false;
    }
  }

  async subirImagenWebp(
    buffer: Buffer,
    ruta: string,
  ): Promise<{ ruta: string; url: string }> {
    const cliente = this.exigirCliente();
    await this.asegurarBucket();

    const intentar = async () =>
      cliente.storage.from(this.bucket).upload(ruta, buffer, {
        contentType: 'image/webp',
        upsert: true,
      });

    let { error } = await intentar();
    if (error?.message?.toLowerCase().includes('bucket not found')) {
      this.bucketVerificado = false;
      await this.asegurarBucket();
      ({ error } = await intentar());
    }

    if (error) {
      this.logger.error(`Storage upload: ${error.message}`);
      const hint =
        error.message.toLowerCase().includes('bucket not found')
          ? ' Crea el bucket con la migración 057 en supabase-db.'
          : '';
      throw new BadRequestException(
        `No se pudo subir la imagen: ${error.message}.${hint}`,
      );
    }
    return { ruta, url: this.urlPublica(ruta) };
  }

  async subirArchivoCrudo(
    buffer: Buffer,
    ruta: string,
    contentType: string,
  ): Promise<{ ruta: string; url: string }> {
    const cliente = this.exigirCliente();
    await this.asegurarBucket();
    const { error } = await cliente.storage.from(this.bucket).upload(ruta, buffer, {
      contentType,
      upsert: true,
    });
    if (error) {
      this.logger.error(`Storage upload: ${error.message}`);
      throw new BadRequestException(
        `No se pudo subir el archivo: ${error.message}`,
      );
    }
    return { ruta, url: this.urlPublica(ruta) };
  }

  /** Video de estado (sin Sharp). Duración máx. 30s la valida el cliente. */
  async subirVideoEstado(
    archivo: Buffer,
    opciones: {
      restauranteId: string;
      sucursalId: string;
      contentType: string;
      extension: string;
      entidadId?: string;
    },
  ): Promise<{ ruta: string; url: string }> {
    if (!archivo?.length) {
      throw new BadRequestException('Archivo vacío');
    }
    if (archivo.length > 20 * 1024 * 1024) {
      throw new BadRequestException('El video no puede superar 20 MB');
    }
    const mime = opciones.contentType.toLowerCase();
    if (!mime.startsWith('video/')) {
      throw new BadRequestException('Solo se permiten videos');
    }
    const id = opciones.entidadId ?? randomUUID();
    const ext = opciones.extension.replace(/^\./, '') || 'mp4';
    const ruta = `${opciones.restauranteId}/${opciones.sucursalId}/promocion/${id}.${ext}`;
    return this.subirArchivoCrudo(archivo, ruta, mime);
  }

  async procesarYSubir(
    archivo: Buffer,
    opciones: {
      restauranteId: string;
      sucursalId: string;
      tipo: TipoImagenFoody;
      entidadId?: string;
    },
  ): Promise<{ ruta: string; url: string }> {
    if (!archivo?.length) {
      throw new BadRequestException('Archivo vacío');
    }
    if (archivo.length > 5 * 1024 * 1024) {
      throw new BadRequestException('La imagen no puede superar 5 MB');
    }
    const webp = await this.comprimirImagen(archivo);
    const ruta = this.construirRuta(
      opciones.restauranteId,
      opciones.sucursalId,
      opciones.tipo,
      opciones.entidadId,
    );
    return this.subirImagenWebp(webp, ruta);
  }

  async subirDocumentoDomiciliario(
    domiciliarioId: string,
    tipo: string,
    archivo: Buffer,
  ): Promise<{ ruta: string; url: string }> {
    if (!archivo?.length) {
      throw new BadRequestException('Archivo vacío');
    }
    if (archivo.length > 5 * 1024 * 1024) {
      throw new BadRequestException('La imagen no puede superar 5 MB');
    }
    const webp = await this.comprimirImagen(archivo);
    const ruta = `domiciliarios/${domiciliarioId}/${tipo}.webp`;
    return this.subirImagenWebp(webp, ruta);
  }

  /** BN-FIX-01: ownership + upload genérico (controller delgado). */
  async restauranteIdDeSucursal(sucursalId: string): Promise<string> {
    const fila = await this.database.consultarUno<{ restaurante_id: string }>(
      `SELECT restaurante_id FROM sucursales WHERE id = $1`,
      [sucursalId],
    );
    if (!fila?.restaurante_id) {
      throw new BadRequestException('Sucursal sin restaurante');
    }
    return fila.restaurante_id;
  }

  parseTipoImagen(tipoQuery?: string): TipoImagenFoody {
    const tipo = (tipoQuery ?? 'general') as TipoImagenFoody;
    if (!TIPOS_IMAGEN.includes(tipo)) {
      throw new BadRequestException(`tipo inválido: ${tipoQuery}`);
    }
    return tipo;
  }

  async subirImagenDesdeSucursal(
    archivo: Buffer,
    opciones: {
      sucursalId: string;
      tipo: TipoImagenFoody;
      entidadId?: string;
    },
  ): Promise<{ ruta: string; url: string }> {
    const restauranteId = await this.restauranteIdDeSucursal(opciones.sucursalId);
    return this.procesarYSubir(archivo, {
      restauranteId,
      sucursalId: opciones.sucursalId,
      tipo: opciones.tipo,
      entidadId: opciones.entidadId,
    });
  }

  async subirVideoDesdeSucursal(
    archivo: Buffer,
    opciones: {
      sucursalId: string;
      tipoQuery?: string;
      contentType: string;
      originalName?: string;
    },
  ): Promise<{ ruta: string; url: string }> {
    const tipo = (opciones.tipoQuery ?? 'promocion') as TipoImagenFoody;
    if (tipo !== 'promocion' && tipo !== 'general') {
      throw new BadRequestException('Video solo para promocion o general');
    }
    const restauranteId = await this.restauranteIdDeSucursal(opciones.sucursalId);
    const nombre = opciones.originalName || 'estado.mp4';
    const ext = nombre.includes('.')
      ? nombre.split('.').pop()!.toLowerCase()
      : 'mp4';
    return this.subirVideoEstado(archivo, {
      restauranteId,
      sucursalId: opciones.sucursalId,
      contentType: opciones.contentType,
      extension: ext,
    });
  }

  /**
   * Upload + UPDATE imagen_url + invalidar menú (producto/combo/categoría).
   * Un solo camino para las 4 rutas (AQ-DUP-04).
   */
  async subirImagenEntidadCatalogo(
    archivo: Buffer,
    opciones: {
      sucursalId: string;
      tipo: EntidadConImagen;
      entidadId: string;
    },
  ): Promise<Record<string, unknown>> {
    const meta = ENTIDAD_IMAGEN[opciones.tipo];
    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM ${meta.tabla} WHERE id = $1 AND sucursal_id = $2`,
      [opciones.entidadId, opciones.sucursalId],
    );
    if (!existe) {
      throw new BadRequestException(
        `${meta.etiqueta} no encontrada en esta sucursal`,
      );
    }

    const subida = await this.subirImagenDesdeSucursal(archivo, {
      sucursalId: opciones.sucursalId,
      tipo: opciones.tipo,
      entidadId: opciones.entidadId,
    });

    await this.database.consultar(
      `UPDATE ${meta.tabla} SET imagen_url = $1 WHERE id = $2 AND sucursal_id = $3`,
      [subida.url, opciones.entidadId, opciones.sucursalId],
    );

    if (meta.invalidarMenu) {
      await this.menuCache.invalidar(opciones.sucursalId);
    }

    return { ...subida, [meta.claveRespuesta]: opciones.entidadId };
  }
}
