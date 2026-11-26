import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../../core/database/database.service';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
export type TipoImagenFoody = 'producto' | 'categoria' | 'combo' | 'promocion' | 'general';
type EntidadConImagen = 'producto' | 'promocion' | 'combo' | 'categoria';
export declare class AlmacenamientoService implements OnModuleInit {
    private readonly config;
    private readonly database;
    private readonly menuCache;
    private readonly logger;
    private readonly cliente;
    private readonly bucket;
    private readonly bucketDocumentos;
    private readonly basePublica;
    private bucketVerificado;
    private bucketDocumentosVerificado;
    constructor(config: ConfigService, database: DatabaseService, menuCache: MenuCacheService);
    onModuleInit(): Promise<void>;
    private asegurarBucket;
    private exigirCliente;
    comprimirImagen(buffer: Buffer): Promise<Buffer>;
    construirRuta(restauranteId: string, sucursalId: string, tipo: TipoImagenFoody, entidadId?: string): string;
    urlPublica(ruta: string): string;
    rutaDesdeUrl(url: string): string | null;
    eliminarPorUrl(url: string): Promise<boolean>;
    subirImagenWebp(buffer: Buffer, ruta: string): Promise<{
        ruta: string;
        url: string;
    }>;
    subirArchivoCrudo(buffer: Buffer, ruta: string, contentType: string): Promise<{
        ruta: string;
        url: string;
    }>;
    subirVideoEstado(archivo: Buffer, opciones: {
        restauranteId: string;
        sucursalId: string;
        contentType: string;
        extension: string;
        entidadId?: string;
    }): Promise<{
        ruta: string;
        url: string;
    }>;
    procesarYSubir(archivo: Buffer, opciones: {
        restauranteId: string;
        sucursalId: string;
        tipo: TipoImagenFoody;
        entidadId?: string;
    }): Promise<{
        ruta: string;
        url: string;
    }>;
    subirDocumentoDomiciliario(domiciliarioId: string, tipo: string, archivo: Buffer): Promise<{
        ruta: string;
        url: string;
    }>;
    resolverUrlDocumento(url: string): Promise<string>;
    private asegurarBucketDocumentosPrivados;
    private urlFirmadaDocumentoPrivado;
    restauranteIdDeSucursal(sucursalId: string): Promise<string>;
    parseTipoImagen(tipoQuery?: string): TipoImagenFoody;
    subirImagenDesdeSucursal(archivo: Buffer, opciones: {
        sucursalId: string;
        tipo: TipoImagenFoody;
        entidadId?: string;
    }): Promise<{
        ruta: string;
        url: string;
    }>;
    subirVideoDesdeSucursal(archivo: Buffer, opciones: {
        sucursalId: string;
        tipoQuery?: string;
        contentType: string;
        originalName?: string;
    }): Promise<{
        ruta: string;
        url: string;
    }>;
    subirImagenEntidadCatalogo(archivo: Buffer, opciones: {
        sucursalId: string;
        tipo: EntidadConImagen;
        entidadId: string;
    }): Promise<Record<string, unknown>>;
}
export {};
