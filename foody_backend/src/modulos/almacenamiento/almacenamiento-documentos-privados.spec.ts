import {
  BadRequestException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import sharp from 'sharp';
import { DatabaseService } from '../../core/database/database.service';
import { MenuCacheService } from '../../core/cache/menu-cache.service';
import { AlmacenamientoService } from './almacenamiento.service';

describe('AlmacenamientoService — documentos privados', () => {
  const storage = {
    listBuckets: jest.fn(),
    createBucket: jest.fn(),
    from: jest.fn(),
  };
  const cliente = { storage };
  const signedUrl = 'https://storage.test/signed/documento?token=temporal';
  let upload: jest.Mock;
  let createSignedUrl: jest.Mock;

  const crearServicio = () => {
    const servicio = new AlmacenamientoService(
      {
        get: () => undefined,
      } as ConfigService,
      {} as DatabaseService,
      {} as MenuCacheService,
    );
    Object.defineProperty(servicio, 'cliente', { value: cliente });
    return servicio;
  };

  beforeEach(() => {
    jest.clearAllMocks();
    upload = jest.fn().mockResolvedValue({ error: null });
    createSignedUrl = jest.fn().mockResolvedValue({
      data: { signedUrl },
      error: null,
    });
    storage.from.mockReturnValue({ upload, createSignedUrl });
    storage.listBuckets.mockResolvedValue({
      data: [
        {
          id: 'foody-documentos-privados',
          name: 'foody-documentos-privados',
          public: false,
        },
      ],
      error: null,
    });
    storage.createBucket.mockResolvedValue({ error: null });
  });

  it('sube WEBP solo al bucket privado y devuelve enlace firmado temporal', async () => {
    const servicio = crearServicio();
    const imagen = await sharp({
      create: {
        width: 4,
        height: 4,
        channels: 3,
        background: '#ffffff',
      },
    })
      .png()
      .toBuffer();

    const resultado = await servicio.subirDocumentoDomiciliario(
      'courier-qa',
      'cedula_frente',
      imagen,
    );

    expect(storage.from).toHaveBeenCalledWith('foody-documentos-privados');
    expect(upload).toHaveBeenCalledWith(
      'domiciliarios/courier-qa/cedula_frente.webp',
      expect.any(Buffer),
      { contentType: 'image/webp', upsert: true },
    );
    expect(createSignedUrl).toHaveBeenCalledWith(
      'domiciliarios/courier-qa/cedula_frente.webp',
      900,
    );
    expect(resultado).toEqual({
      ruta: 'privado://domiciliarios/courier-qa/cedula_frente.webp',
      url: signedUrl,
    });
  });

  it('crea el bucket privado si no existe y nunca lo crea como público', async () => {
    const servicio = crearServicio();
    storage.listBuckets.mockResolvedValue({ data: [], error: null });
    const imagen = await sharp({
      create: {
        width: 2,
        height: 2,
        channels: 3,
        background: '#ffffff',
      },
    })
      .png()
      .toBuffer();

    await servicio.subirDocumentoDomiciliario(
      'courier-qa',
      'cedula_reverso',
      imagen,
    );

    expect(storage.createBucket).toHaveBeenCalledWith(
      'foody-documentos-privados',
      {
        public: false,
        fileSizeLimit: 5 * 1024 * 1024,
        allowedMimeTypes: ['image/webp'],
      },
    );
    expect(upload).toHaveBeenCalledTimes(1);
  });

  it('rechaza si un bucket con el nombre privado está configurado como público', async () => {
    const servicio = crearServicio();
    storage.listBuckets.mockResolvedValue({
      data: [
        {
          id: 'foody-documentos-privados',
          name: 'foody-documentos-privados',
          public: true,
        },
      ],
      error: null,
    });
    const imagen = await sharp({
      create: {
        width: 2,
        height: 2,
        channels: 3,
        background: '#ffffff',
      },
    })
      .png()
      .toBuffer();

    await expect(
      servicio.subirDocumentoDomiciliario(
        'courier-qa',
        'foto_vehiculo',
        imagen,
      ),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(upload).not.toHaveBeenCalled();
  });

  it('rechaza bytes que no representan una imagen antes de usar Storage', async () => {
    const servicio = crearServicio();
    await expect(
      servicio.subirDocumentoDomiciliario(
        'courier-qa',
        'cedula_frente',
        Buffer.from('no es una imagen'),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(storage.listBuckets).not.toHaveBeenCalled();
    expect(upload).not.toHaveBeenCalled();
  });

  it('conserva URLs históricas públicas sin confundirlas con rutas privadas', async () => {
    const servicio = crearServicio();
    const legado =
      'https://storage.test/storage/v1/object/public/foody-assets/domiciliarios/courier/cedula.webp';

    await expect(servicio.resolverUrlDocumento(legado)).resolves.toBe(legado);
    expect(storage.listBuckets).not.toHaveBeenCalled();
  });

  it('resuelve una ruta privada a un enlace temporal al consultar documentos', async () => {
    const servicio = crearServicio();

    await expect(
      servicio.resolverUrlDocumento(
        'privado://domiciliarios/courier-qa/cedula_frente.webp',
      ),
    ).resolves.toBe(signedUrl);

    expect(storage.from).toHaveBeenCalledWith('foody-documentos-privados');
    expect(createSignedUrl).toHaveBeenCalledWith(
      'domiciliarios/courier-qa/cedula_frente.webp',
      900,
    );
  });
});
