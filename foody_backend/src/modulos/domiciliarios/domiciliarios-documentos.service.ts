import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { AlmacenamientoService } from '../almacenamiento/almacenamiento.service';
import {
  TIPOS_DOCUMENTO_DOMICILIARIO,
  esTipoDocumentoDomiciliario,
} from './domiciliarios-documentos.config';

type DocumentoDomiciliarioRow = {
  [key: string]: unknown;
  id: string;
  tipo: string;
  url: string;
  estado: string;
  motivo_rechazo: string | null;
  created_at: Date | string;
  revisado_por: string | null;
};

@Injectable()
export class DomiciliariosDocumentosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly almacenamiento: AlmacenamientoService,
  ) {}

  listarTiposRequeridos() {
    return TIPOS_DOCUMENTO_DOMICILIARIO;
  }

  async listarPorDomiciliario(domiciliarioId: string) {
    const docs = await this.database.consultar<DocumentoDomiciliarioRow>(
      `SELECT id, tipo, url, estado, motivo_rechazo, created_at, revisado_por
       FROM documentos_domiciliario
       WHERE domiciliario_id = $1
       ORDER BY created_at DESC`,
      [domiciliarioId],
    );
    return Promise.all(
      docs.map(async (doc) => ({
        ...doc,
        url: await this.almacenamiento.resolverUrlDocumento(doc.url),
      })),
    );
  }

  async resumenCarga(domiciliarioId: string) {
    const docs = await this.listarPorDomiciliario(domiciliarioId);
    const porTipo = new Map<string, (typeof docs)[number]>();
    for (const d of docs) {
      const actual = porTipo.get(d.tipo as string);
      if (!actual || new Date(d.created_at) > new Date(actual.created_at)) {
        porTipo.set(d.tipo as string, d);
      }
    }

    const faltantes = TIPOS_DOCUMENTO_DOMICILIARIO.filter((t) => {
      const doc = porTipo.get(t);
      return !doc || doc.estado === 'rechazado';
    });

    const pendientesRevision = [...porTipo.values()].filter(
      (d) => d.estado === 'pendiente',
    ).length;

    return {
      documentos: [...porTipo.values()],
      faltantes,
      completo: faltantes.length === 0,
      pendientes_revision: pendientesRevision,
    };
  }

  async subir(domiciliarioId: string, tipo: string, archivo: Buffer) {
    if (!esTipoDocumentoDomiciliario(tipo)) {
      throw new BadRequestException('Tipo de documento no válido');
    }

    const dom = await this.database.consultarUno<{ estado_cuenta: string }>(
      `SELECT estado_cuenta FROM domiciliarios_independientes WHERE id = $1`,
      [domiciliarioId],
    );
    if (!dom) throw new NotFoundException('Domiciliario no encontrado');
    if (dom.estado_cuenta === 'activo') {
      const aprobado = await this.database.consultarUno<{ id: string }>(
        `SELECT id FROM documentos_domiciliario
         WHERE domiciliario_id = $1 AND tipo = $2 AND estado = 'aprobado'
         LIMIT 1`,
        [domiciliarioId, tipo],
      );
      if (aprobado) {
        throw new BadRequestException(
          'Este documento ya fue aprobado. Contacta a soporte si necesitas actualizarlo.',
        );
      }
    }

    const { ruta, url } = await this.almacenamiento.subirDocumentoDomiciliario(
      domiciliarioId,
      tipo,
      archivo,
    );

    const existente = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM documentos_domiciliario
       WHERE domiciliario_id = $1 AND tipo = $2
         AND estado IN ('pendiente', 'rechazado')
       ORDER BY created_at DESC
       LIMIT 1`,
      [domiciliarioId, tipo],
    );

    if (existente) {
      await this.database.consultar(
        `UPDATE documentos_domiciliario SET
           url = $2,
           estado = 'pendiente',
           motivo_rechazo = NULL,
           revisado_por = NULL
         WHERE id = $1`,
        [existente.id, ruta],
      );
      return { id: existente.id, tipo, url, estado: 'pendiente' };
    }

    const fila = await this.database.consultarUno<{ id: string }>(
      `INSERT INTO documentos_domiciliario (domiciliario_id, tipo, url, estado)
       VALUES ($1, $2, $3, 'pendiente')
       RETURNING id`,
      [domiciliarioId, tipo, ruta],
    );

    return { id: fila!.id, tipo, url, estado: 'pendiente' };
  }
}
