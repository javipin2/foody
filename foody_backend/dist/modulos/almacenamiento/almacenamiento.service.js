"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
var AlmacenamientoService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AlmacenamientoService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const supabase_js_1 = require("@supabase/supabase-js");
const crypto_1 = require("crypto");
const sharp_1 = __importDefault(require("sharp"));
const database_service_1 = require("../../core/database/database.service");
const menu_cache_service_1 = require("../../core/cache/menu-cache.service");
const TIPOS_IMAGEN = [
    'producto',
    'categoria',
    'combo',
    'promocion',
    'general',
];
const ENTIDAD_IMAGEN = {
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
let AlmacenamientoService = AlmacenamientoService_1 = class AlmacenamientoService {
    config;
    database;
    menuCache;
    logger = new common_1.Logger(AlmacenamientoService_1.name);
    cliente;
    bucket;
    basePublica;
    bucketVerificado = false;
    constructor(config, database, menuCache) {
        this.config = config;
        this.database = database;
        this.menuCache = menuCache;
        const url = this.config.get('SUPABASE_URL');
        const key = this.config.get('SUPABASE_SERVICE_KEY');
        this.bucket =
            this.config.get('SUPABASE_STORAGE_BUCKET') ?? 'foody-assets';
        this.cliente = url && key ? (0, supabase_js_1.createClient)(url, key) : null;
        this.basePublica = url
            ? `${url.replace(/\/$/, '')}/storage/v1/object/public/${this.bucket}`
            : '';
    }
    async onModuleInit() {
        await this.asegurarBucket();
    }
    async asegurarBucket() {
        if (!this.cliente || this.bucketVerificado)
            return;
        const { data: buckets, error: listError } = await this.cliente.storage.listBuckets();
        if (listError) {
            this.logger.warn(`Storage listBuckets: ${listError.message}`);
        }
        const existe = buckets?.some((b) => b.id === this.bucket || b.name === this.bucket);
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
                this.logger.warn(`Bucket «${this.bucket}» no existe y no se pudo crear: ${error.message}. ` +
                    'Ejecuta foody_supabase/migrations/057 y 077 en supabase-db.');
                return;
            }
            this.logger.log(`Bucket storage «${this.bucket}» creado`);
        }
        this.bucketVerificado = true;
    }
    exigirCliente() {
        if (!this.cliente) {
            throw new common_1.ServiceUnavailableException('Storage no configurado (SUPABASE_URL / SUPABASE_SERVICE_KEY)');
        }
        return this.cliente;
    }
    async comprimirImagen(buffer) {
        return (0, sharp_1.default)(buffer)
            .rotate()
            .resize(800, 800, {
            fit: 'inside',
            withoutEnlargement: true,
        })
            .webp({ quality: 80 })
            .toBuffer();
    }
    construirRuta(restauranteId, sucursalId, tipo, entidadId) {
        const id = entidadId ?? (0, crypto_1.randomUUID)();
        return `${restauranteId}/${sucursalId}/${tipo}/${id}.webp`;
    }
    urlPublica(ruta) {
        return `${this.basePublica}/${ruta}`;
    }
    rutaDesdeUrl(url) {
        const u = (url ?? '').trim();
        if (!u)
            return null;
        if (!u.startsWith('http'))
            return u.replace(/^\//, '');
        const marker = `/storage/v1/object/public/${this.bucket}/`;
        const i = u.indexOf(marker);
        if (i < 0)
            return null;
        return decodeURIComponent(u.slice(i + marker.length));
    }
    async eliminarPorUrl(url) {
        const ruta = this.rutaDesdeUrl(url);
        if (!ruta || !this.cliente)
            return false;
        try {
            await this.asegurarBucket();
            const { error } = await this.cliente.storage.from(this.bucket).remove([ruta]);
            if (error) {
                this.logger.warn(`Storage remove «${ruta}»: ${error.message}`);
                return false;
            }
            return true;
        }
        catch (e) {
            this.logger.warn(`Storage remove falló: ${e instanceof Error ? e.message : String(e)}`);
            return false;
        }
    }
    async subirImagenWebp(buffer, ruta) {
        const cliente = this.exigirCliente();
        await this.asegurarBucket();
        const intentar = async () => cliente.storage.from(this.bucket).upload(ruta, buffer, {
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
            const hint = error.message.toLowerCase().includes('bucket not found')
                ? ' Crea el bucket con la migración 057 en supabase-db.'
                : '';
            throw new common_1.BadRequestException(`No se pudo subir la imagen: ${error.message}.${hint}`);
        }
        return { ruta, url: this.urlPublica(ruta) };
    }
    async subirArchivoCrudo(buffer, ruta, contentType) {
        const cliente = this.exigirCliente();
        await this.asegurarBucket();
        const { error } = await cliente.storage.from(this.bucket).upload(ruta, buffer, {
            contentType,
            upsert: true,
        });
        if (error) {
            this.logger.error(`Storage upload: ${error.message}`);
            throw new common_1.BadRequestException(`No se pudo subir el archivo: ${error.message}`);
        }
        return { ruta, url: this.urlPublica(ruta) };
    }
    async subirVideoEstado(archivo, opciones) {
        if (!archivo?.length) {
            throw new common_1.BadRequestException('Archivo vacío');
        }
        if (archivo.length > 20 * 1024 * 1024) {
            throw new common_1.BadRequestException('El video no puede superar 20 MB');
        }
        const mime = opciones.contentType.toLowerCase();
        if (!mime.startsWith('video/')) {
            throw new common_1.BadRequestException('Solo se permiten videos');
        }
        const id = opciones.entidadId ?? (0, crypto_1.randomUUID)();
        const ext = opciones.extension.replace(/^\./, '') || 'mp4';
        const ruta = `${opciones.restauranteId}/${opciones.sucursalId}/promocion/${id}.${ext}`;
        return this.subirArchivoCrudo(archivo, ruta, mime);
    }
    async procesarYSubir(archivo, opciones) {
        if (!archivo?.length) {
            throw new common_1.BadRequestException('Archivo vacío');
        }
        if (archivo.length > 5 * 1024 * 1024) {
            throw new common_1.BadRequestException('La imagen no puede superar 5 MB');
        }
        const webp = await this.comprimirImagen(archivo);
        const ruta = this.construirRuta(opciones.restauranteId, opciones.sucursalId, opciones.tipo, opciones.entidadId);
        return this.subirImagenWebp(webp, ruta);
    }
    async subirDocumentoDomiciliario(domiciliarioId, tipo, archivo) {
        if (!archivo?.length) {
            throw new common_1.BadRequestException('Archivo vacío');
        }
        if (archivo.length > 5 * 1024 * 1024) {
            throw new common_1.BadRequestException('La imagen no puede superar 5 MB');
        }
        const webp = await this.comprimirImagen(archivo);
        const ruta = `domiciliarios/${domiciliarioId}/${tipo}.webp`;
        return this.subirImagenWebp(webp, ruta);
    }
    async restauranteIdDeSucursal(sucursalId) {
        const fila = await this.database.consultarUno(`SELECT restaurante_id FROM sucursales WHERE id = $1`, [sucursalId]);
        if (!fila?.restaurante_id) {
            throw new common_1.BadRequestException('Sucursal sin restaurante');
        }
        return fila.restaurante_id;
    }
    parseTipoImagen(tipoQuery) {
        const tipo = (tipoQuery ?? 'general');
        if (!TIPOS_IMAGEN.includes(tipo)) {
            throw new common_1.BadRequestException(`tipo inválido: ${tipoQuery}`);
        }
        return tipo;
    }
    async subirImagenDesdeSucursal(archivo, opciones) {
        const restauranteId = await this.restauranteIdDeSucursal(opciones.sucursalId);
        return this.procesarYSubir(archivo, {
            restauranteId,
            sucursalId: opciones.sucursalId,
            tipo: opciones.tipo,
            entidadId: opciones.entidadId,
        });
    }
    async subirVideoDesdeSucursal(archivo, opciones) {
        const tipo = (opciones.tipoQuery ?? 'promocion');
        if (tipo !== 'promocion' && tipo !== 'general') {
            throw new common_1.BadRequestException('Video solo para promocion o general');
        }
        const restauranteId = await this.restauranteIdDeSucursal(opciones.sucursalId);
        const nombre = opciones.originalName || 'estado.mp4';
        const ext = nombre.includes('.')
            ? nombre.split('.').pop().toLowerCase()
            : 'mp4';
        return this.subirVideoEstado(archivo, {
            restauranteId,
            sucursalId: opciones.sucursalId,
            contentType: opciones.contentType,
            extension: ext,
        });
    }
    async subirImagenEntidadCatalogo(archivo, opciones) {
        const meta = ENTIDAD_IMAGEN[opciones.tipo];
        const existe = await this.database.consultarUno(`SELECT id FROM ${meta.tabla} WHERE id = $1 AND sucursal_id = $2`, [opciones.entidadId, opciones.sucursalId]);
        if (!existe) {
            throw new common_1.BadRequestException(`${meta.etiqueta} no encontrada en esta sucursal`);
        }
        const subida = await this.subirImagenDesdeSucursal(archivo, {
            sucursalId: opciones.sucursalId,
            tipo: opciones.tipo,
            entidadId: opciones.entidadId,
        });
        await this.database.consultar(`UPDATE ${meta.tabla} SET imagen_url = $1 WHERE id = $2 AND sucursal_id = $3`, [subida.url, opciones.entidadId, opciones.sucursalId]);
        if (meta.invalidarMenu) {
            await this.menuCache.invalidar(opciones.sucursalId);
        }
        return { ...subida, [meta.claveRespuesta]: opciones.entidadId };
    }
};
exports.AlmacenamientoService = AlmacenamientoService;
exports.AlmacenamientoService = AlmacenamientoService = AlmacenamientoService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService,
        database_service_1.DatabaseService,
        menu_cache_service_1.MenuCacheService])
], AlmacenamientoService);
//# sourceMappingURL=almacenamiento.service.js.map