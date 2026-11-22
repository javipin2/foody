import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { pedidoTerminalOperativo } from '../pedidos/pedido-estados';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { GuardarConfigFiscalDto } from './dto/guardar-config-fiscal.dto';

export interface DesgloseIva {
  subtotal: number;
  iva: number;
  total: number;
}

export interface ConfigFiscalRow {
  id: string;
  sucursal_id: string;
  nit: string | null;
  razon_social: string | null;
  regimen: string;
  aplica_iva: boolean;
  porcentaje_iva: string;
  resolucion_dian: string | null;
  prefijo_factura: string | null;
  consecutivo_actual: number;
}

@Injectable()
export class FacturacionService {
  constructor(
    private readonly database: DatabaseService,
    private readonly auditoria: AuditoriaService,
  ) {}

  calcularDesgloseIva(
    total: number,
    config: Pick<ConfigFiscalRow, 'aplica_iva' | 'porcentaje_iva'>,
  ): DesgloseIva {
    const aplica = config.aplica_iva && Number(config.porcentaje_iva) > 0;
    if (!aplica) {
      return {
        subtotal: this.redondear(total),
        iva: 0,
        total: this.redondear(total),
      };
    }
    const pct = Number(config.porcentaje_iva) / 100;
    const subtotal = total / (1 + pct);
    const iva = total - subtotal;
    return {
      subtotal: this.redondear(subtotal),
      iva: this.redondear(iva),
      total: this.redondear(total),
    };
  }

  async obtenerConfig(sucursalId: string) {
    const config = await this.database.consultarUno<ConfigFiscalRow>(
      `SELECT id, sucursal_id, nit, razon_social, regimen, aplica_iva,
              porcentaje_iva, resolucion_dian, prefijo_factura, consecutivo_actual
       FROM configuracion_fiscal_sucursal
       WHERE sucursal_id = $1`,
      [sucursalId],
    );
    return config;
  }

  async guardarConfig(dto: GuardarConfigFiscalDto) {
    const aplicaIva =
      dto.aplica_iva ?? (dto.regimen === 'comun');
    const pctIva = dto.porcentaje_iva ?? (aplicaIva ? 19 : 0);

    const existente = await this.obtenerConfig(dto.sucursal_id);
    if (existente) {
      return this.database.consultarUno(
        `UPDATE configuracion_fiscal_sucursal SET
           nit = $2, razon_social = $3, regimen = $4, aplica_iva = $5,
           porcentaje_iva = $6, resolucion_dian = $7, prefijo_factura = $8
         WHERE sucursal_id = $1
         RETURNING *`,
        [
          dto.sucursal_id,
          dto.nit,
          dto.razon_social,
          dto.regimen,
          aplicaIva,
          pctIva,
          dto.resolucion_dian ?? null,
          dto.prefijo_factura ?? 'FE',
        ],
      );
    }

    return this.database.consultarUno(
      `INSERT INTO configuracion_fiscal_sucursal (
         sucursal_id, nit, razon_social, regimen, aplica_iva,
         porcentaje_iva, resolucion_dian, prefijo_factura
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`,
      [
        dto.sucursal_id,
        dto.nit,
        dto.razon_social,
        dto.regimen,
        aplicaIva,
        pctIva,
        dto.resolucion_dian ?? null,
        dto.prefijo_factura ?? 'FE',
      ],
    );
  }

  async listarFacturas(sucursalId: string, estado?: string) {
    const filtro = estado ? 'AND f.estado = $2' : '';
    const params = estado ? [sucursalId, estado] : [sucursalId];
    return this.database.consultar(
      `SELECT f.id, f.pedido_id, f.numero_factura, f.nit_cliente,
              f.nombre_fiscal_cliente, f.email_cliente,
              f.subtotal, f.iva, f.total, f.estado, f.emitida_at, f.created_at,
              p.numero_pedido
       FROM facturas f
       LEFT JOIN pedidos p ON p.id = f.pedido_id
       WHERE f.sucursal_id = $1 ${filtro}
       ORDER BY f.created_at DESC
       LIMIT 200`,
      params,
    );
  }

  async crearBorradorEnTransaccion(
    client: PoolClient,
    params: {
      sucursalId: string;
      pedidoId: string;
      total: number;
      nitCliente: string;
      nombreFiscalCliente: string;
      emailCliente: string;
    },
  ): Promise<string> {
    const config = await this.consultarConfigCliente(client, params.sucursalId);
    const desglose = this.calcularDesgloseIva(params.total, config);

    const insert = await client.query<{ id: string }>(
      `INSERT INTO facturas (
         sucursal_id, pedido_id, nit_cliente, nombre_fiscal_cliente,
         email_cliente, subtotal, iva, total, estado
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'borrador')
       RETURNING id`,
      [
        params.sucursalId,
        params.pedidoId,
        params.nitCliente,
        params.nombreFiscalCliente,
        params.emailCliente,
        desglose.subtotal,
        desglose.iva,
        desglose.total,
      ],
    );
    const facturaId = insert.rows[0].id;

    await client.query(
      `UPDATE pedidos SET factura_id = $1 WHERE id = $2`,
      [facturaId, params.pedidoId],
    );

    return facturaId;
  }

  /**
   * F-08: alinear borrador con `pedidos.total` tras agregar/eliminar ítems o descuento.
   * No-op si no hay factura en borrador vinculada al pedido.
   */
  async sincronizarBorradorDesdePedidoEnTransaccion(
    client: PoolClient,
    sucursalId: string,
    pedidoId: string,
  ): Promise<boolean> {
    const pedido = await this.consultarUnoCliente<{
      factura_id: string | null;
      total: string;
    }>(
      client,
      `SELECT factura_id, total FROM pedidos
       WHERE id = $1 AND sucursal_id = $2`,
      [pedidoId, sucursalId],
    );
    if (!pedido?.factura_id) return false;

    const factura = await this.consultarUnoCliente<{ id: string; estado: string }>(
      client,
      `SELECT id, estado FROM facturas
       WHERE id = $1 AND sucursal_id = $2 AND pedido_id = $3`,
      [pedido.factura_id, sucursalId, pedidoId],
    );
    if (!factura || factura.estado !== 'borrador') return false;

    const total = Number(pedido.total);
    const config = await this.consultarConfigCliente(client, sucursalId);
    const desglose = this.calcularDesgloseIva(total, config);

    await client.query(
      `UPDATE facturas SET subtotal = $1, iva = $2, total = $3
       WHERE id = $4 AND estado = 'borrador'`,
      [desglose.subtotal, desglose.iva, desglose.total, factura.id],
    );
    return true;
  }

  /** IVA incluido en precios — extrae desglose para guardar en el pedido. */
  async calcularIvaParaPedidoEnTransaccion(
    client: PoolClient,
    sucursalId: string,
    total: number,
  ): Promise<{ iva_porcentaje: number; iva_valor: number }> {
    const config = await this.consultarConfigCliente(client, sucursalId);
    const desglose = this.calcularDesgloseIva(total, config);
    const pct =
      config.aplica_iva && Number(config.porcentaje_iva) > 0
        ? Number(config.porcentaje_iva)
        : 0;
    return { iva_porcentaje: pct, iva_valor: desglose.iva };
  }

  async emitir(pedidoId: string, sucursalId: string) {
    return this.database.enTransaccion(async (client) => {
      const config = await this.consultarConfigCliente(client, sucursalId);
      if (!config.nit || !config.razon_social) {
        throw new BadRequestException({
          error: 'CONFIG_FISCAL_INCOMPLETA',
          message: 'Configura NIT y razón social antes de emitir',
        });
      }

      const factura = await this.consultarUnoCliente<{
        id: string;
        estado: string;
        pedido_id: string;
      }>(
        client,
        `SELECT id, estado, pedido_id FROM facturas
         WHERE pedido_id = $1 AND sucursal_id = $2
         ORDER BY created_at DESC LIMIT 1`,
        [pedidoId, sucursalId],
      );

      if (!factura) {
        throw new NotFoundException('No hay factura borrador para este pedido');
      }
      if (factura.estado === 'emitida') {
        throw new BadRequestException({
          error: 'FACTURA_YA_EMITIDA',
          message: 'La factura ya fue emitida',
        });
      }
      if (factura.estado === 'anulada') {
        throw new BadRequestException({
          error: 'FACTURA_ANULADA',
          message: 'La factura está anulada',
        });
      }

      const pedido = await this.consultarUnoCliente<{
        estado: string;
        tipo: string;
        total: string;
        monto_pagado: string | null;
      }>(
        client,
        `SELECT estado, tipo, total, monto_pagado FROM pedidos
         WHERE id = $1 AND sucursal_id = $2`,
        [pedidoId, sucursalId],
      );
      if (!pedido) throw new NotFoundException('Pedido no encontrado');

      if (!pedidoTerminalOperativo(pedido)) {
        throw new BadRequestException({
          error: 'PEDIDO_NO_FACTURABLE',
          message:
            pedido.tipo === 'domicilio'
              ? 'Solo puedes emitir factura cuando el domicilio está entregado y cobrado.'
              : 'Solo puedes emitir factura cuando el pedido está pagado en caja.',
        });
      }

      await this.sincronizarBorradorDesdePedidoEnTransaccion(
        client,
        sucursalId,
        pedidoId,
      );

      const siguiente = (config.consecutivo_actual ?? 0) + 1;
      const prefijo = config.prefijo_factura ?? 'FE';
      const numeroFactura = `${prefijo}-${String(siguiente).padStart(8, '0')}`;

      await client.query(
        `UPDATE configuracion_fiscal_sucursal
         SET consecutivo_actual = $1
         WHERE sucursal_id = $2`,
        [siguiente, sucursalId],
      );

      const actualizada = await this.consultarUnoCliente<Record<string, unknown>>(
        client,
        `UPDATE facturas SET
           numero_factura = $1,
           estado = 'emitida',
           emitida_at = now()
         WHERE id = $2
         RETURNING *`,
        [numeroFactura, factura.id],
      );

      return actualizada;
    });
  }

  async anular(facturaId: string, sucursalId: string, usuarioId: string, motivo: string) {
    return this.database.enTransaccion(async (client) => {
      const factura = await this.consultarUnoCliente<{
        id: string;
        estado: string;
        pedido_id: string;
        total: string;
      }>(
        client,
        `SELECT id, estado, pedido_id, total FROM facturas
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [facturaId, sucursalId],
      );
      if (!factura) throw new NotFoundException('Factura no encontrada');
      if (factura.estado !== 'emitida') {
        throw new BadRequestException('Solo se pueden anular facturas emitidas');
      }
      if (!motivo?.trim()) {
        throw new BadRequestException('El motivo de anulación es obligatorio');
      }

      await client.query(
        `UPDATE facturas SET estado = 'anulada' WHERE id = $1`,
        [facturaId],
      );

      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'ANULAR_FACTURA',
        tablaAfectada: 'facturas',
        registroId: facturaId,
        usuarioId,
        datosDespues: {
          motivo: motivo.trim(),
          pedido_id: factura.pedido_id,
        },
      });

      return {
        factura_id: facturaId,
        estado: 'anulada',
        nota: 'Nota crédito DIAN pendiente integración proveedor',
      };
    });
  }

  async obtenerPdf(facturaId: string, sucursalId: string) {
    const factura = await this.database.consultarUno<Record<string, unknown>>(
      `SELECT f.*, p.numero_pedido
       FROM facturas f
       LEFT JOIN pedidos p ON p.id = f.pedido_id
       WHERE f.id = $1 AND f.sucursal_id = $2`,
      [facturaId, sucursalId],
    );
    if (!factura) throw new NotFoundException('Factura no encontrada');

    const config = await this.obtenerConfig(sucursalId);
    const html = this.generarHtmlFactura(factura, config);
    return { html, factura };
  }

  private generarHtmlFactura(
    factura: Record<string, unknown>,
    config: ConfigFiscalRow | null,
  ): string {
    const fmt = (n: unknown) =>
      Number(n ?? 0).toLocaleString('es-CO', {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
      });
    const emisor = config?.razon_social ?? 'Restaurante';
    const nitEmisor = config?.nit ?? '—';
    // Ponytail: actualmente la capa DIAN/CUFE/XML se mantiene pausada (FE interna).
    // No mostramos "Resolución DIAN" en el documento informativo para evitar claim legal
    // aunque exista valor guardado en BD.
    const resolucion = '—';
    const estado = String(factura.estado ?? 'borrador');
    const titulo =
      estado === 'emitida' ? 'Factura electrónica' : 'Borrador de factura';

    return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>${titulo}</title>
<style>
  body{font-family:Arial,sans-serif;max-width:640px;margin:24px auto;color:#1e293b}
  h1{font-size:20px;color:#FF6B35}
  table{width:100%;border-collapse:collapse;margin-top:16px}
  td{padding:6px 0;border-bottom:1px solid #e2e8f0}
  .total{font-weight:bold;font-size:18px}
  .muted{color:#64748b;font-size:13px}
</style></head>
<body>
  <h1>${titulo}</h1>
  <p class="muted">${emisor} · NIT ${nitEmisor}</p>
  <p class="muted">DIAN electrónico pausado (CUFE/XML no enviado)</p>
  <table>
    <tr><td>Número</td><td>${factura.numero_factura ?? 'Pendiente'}</td></tr>
    <tr><td>Pedido</td><td>${factura.numero_pedido ?? '—'}</td></tr>
    <tr><td>Cliente</td><td>${factura.nombre_fiscal_cliente ?? '—'}</td></tr>
    <tr><td>NIT/C.C.</td><td>${factura.nit_cliente ?? '—'}</td></tr>
    <tr><td>Email</td><td>${factura.email_cliente ?? '—'}</td></tr>
    <tr><td>Estado</td><td>${estado}</td></tr>
    <tr><td>Subtotal</td><td>$ ${fmt(factura.subtotal)}</td></tr>
    <tr><td>IVA</td><td>$ ${fmt(factura.iva)}</td></tr>
    <tr class="total"><td>Total</td><td>$ ${fmt(factura.total)}</td></tr>
  </table>
  <p class="muted" style="margin-top:24px">Generado por Foody · Documento informativo (DIAN vía proveedor FE en producción)</p>
</body></html>`;
  }

  private async consultarConfigCliente(
    client: PoolClient,
    sucursalId: string,
  ): Promise<ConfigFiscalRow> {
    const config = await this.consultarUnoCliente<ConfigFiscalRow>(
      client,
      `SELECT id, sucursal_id, nit, razon_social, regimen, aplica_iva,
              porcentaje_iva, resolucion_dian, prefijo_factura, consecutivo_actual
       FROM configuracion_fiscal_sucursal
       WHERE sucursal_id = $1`,
      [sucursalId],
    );
    if (!config) {
      return {
        id: '',
        sucursal_id: sucursalId,
        nit: null,
        razon_social: null,
        regimen: 'simplificado',
        aplica_iva: false,
        porcentaje_iva: '0',
        resolucion_dian: null,
        prefijo_factura: 'FE',
        consecutivo_actual: 0,
      };
    }
    return config;
  }

  private async consultarUnoCliente<T extends QueryResultRow>(
    client: PoolClient,
    sql: string,
    params: unknown[],
  ): Promise<T | null> {
    const res = await client.query<T>(sql, params);
    return res.rows[0] ?? null;
  }

  private redondear(n: number): number {
    return Math.round(n * 100) / 100;
  }
}
