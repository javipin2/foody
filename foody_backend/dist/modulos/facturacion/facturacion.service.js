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
Object.defineProperty(exports, "__esModule", { value: true });
exports.FacturacionService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
let FacturacionService = class FacturacionService {
    database;
    constructor(database) {
        this.database = database;
    }
    calcularDesgloseIva(total, config) {
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
    async obtenerConfig(sucursalId) {
        const config = await this.database.consultarUno(`SELECT id, sucursal_id, nit, razon_social, regimen, aplica_iva,
              porcentaje_iva, resolucion_dian, prefijo_factura, consecutivo_actual
       FROM configuracion_fiscal_sucursal
       WHERE sucursal_id = $1`, [sucursalId]);
        return config;
    }
    async guardarConfig(dto) {
        const aplicaIva = dto.aplica_iva ?? (dto.regimen === 'comun');
        const pctIva = dto.porcentaje_iva ?? (aplicaIva ? 19 : 0);
        const existente = await this.obtenerConfig(dto.sucursal_id);
        if (existente) {
            return this.database.consultarUno(`UPDATE configuracion_fiscal_sucursal SET
           nit = $2, razon_social = $3, regimen = $4, aplica_iva = $5,
           porcentaje_iva = $6, resolucion_dian = $7, prefijo_factura = $8
         WHERE sucursal_id = $1
         RETURNING *`, [
                dto.sucursal_id,
                dto.nit,
                dto.razon_social,
                dto.regimen,
                aplicaIva,
                pctIva,
                dto.resolucion_dian ?? null,
                dto.prefijo_factura ?? 'FE',
            ]);
        }
        return this.database.consultarUno(`INSERT INTO configuracion_fiscal_sucursal (
         sucursal_id, nit, razon_social, regimen, aplica_iva,
         porcentaje_iva, resolucion_dian, prefijo_factura
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
       RETURNING *`, [
            dto.sucursal_id,
            dto.nit,
            dto.razon_social,
            dto.regimen,
            aplicaIva,
            pctIva,
            dto.resolucion_dian ?? null,
            dto.prefijo_factura ?? 'FE',
        ]);
    }
    async listarFacturas(sucursalId, estado) {
        const filtro = estado ? 'AND f.estado = $2' : '';
        const params = estado ? [sucursalId, estado] : [sucursalId];
        return this.database.consultar(`SELECT f.id, f.pedido_id, f.numero_factura, f.nit_cliente,
              f.nombre_fiscal_cliente, f.email_cliente,
              f.subtotal, f.iva, f.total, f.estado, f.emitida_at, f.created_at,
              p.numero_pedido
       FROM facturas f
       LEFT JOIN pedidos p ON p.id = f.pedido_id
       WHERE f.sucursal_id = $1 ${filtro}
       ORDER BY f.created_at DESC
       LIMIT 200`, params);
    }
    async crearBorradorEnTransaccion(client, params) {
        const config = await this.consultarConfigCliente(client, params.sucursalId);
        const desglose = this.calcularDesgloseIva(params.total, config);
        const insert = await client.query(`INSERT INTO facturas (
         sucursal_id, pedido_id, nit_cliente, nombre_fiscal_cliente,
         email_cliente, subtotal, iva, total, estado
       ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'borrador')
       RETURNING id`, [
            params.sucursalId,
            params.pedidoId,
            params.nitCliente,
            params.nombreFiscalCliente,
            params.emailCliente,
            desglose.subtotal,
            desglose.iva,
            desglose.total,
        ]);
        const facturaId = insert.rows[0].id;
        await client.query(`UPDATE pedidos SET factura_id = $1 WHERE id = $2`, [facturaId, params.pedidoId]);
        return facturaId;
    }
    async calcularIvaParaPedidoEnTransaccion(client, sucursalId, total) {
        const config = await this.consultarConfigCliente(client, sucursalId);
        const desglose = this.calcularDesgloseIva(total, config);
        const pct = config.aplica_iva && Number(config.porcentaje_iva) > 0
            ? Number(config.porcentaje_iva)
            : 0;
        return { iva_porcentaje: pct, iva_valor: desglose.iva };
    }
    async emitir(pedidoId, sucursalId) {
        return this.database.enTransaccion(async (client) => {
            const config = await this.consultarConfigCliente(client, sucursalId);
            if (!config.nit || !config.razon_social) {
                throw new common_1.BadRequestException({
                    error: 'CONFIG_FISCAL_INCOMPLETA',
                    message: 'Configura NIT y razón social antes de emitir',
                });
            }
            const factura = await this.consultarUnoCliente(client, `SELECT id, estado, pedido_id FROM facturas
         WHERE pedido_id = $1 AND sucursal_id = $2
         ORDER BY created_at DESC LIMIT 1`, [pedidoId, sucursalId]);
            if (!factura) {
                throw new common_1.NotFoundException('No hay factura borrador para este pedido');
            }
            if (factura.estado === 'emitida') {
                throw new common_1.BadRequestException({
                    error: 'FACTURA_YA_EMITIDA',
                    message: 'La factura ya fue emitida',
                });
            }
            if (factura.estado === 'anulada') {
                throw new common_1.BadRequestException({
                    error: 'FACTURA_ANULADA',
                    message: 'La factura está anulada',
                });
            }
            const siguiente = (config.consecutivo_actual ?? 0) + 1;
            const prefijo = config.prefijo_factura ?? 'FE';
            const numeroFactura = `${prefijo}-${String(siguiente).padStart(8, '0')}`;
            await client.query(`UPDATE configuracion_fiscal_sucursal
         SET consecutivo_actual = $1
         WHERE sucursal_id = $2`, [siguiente, sucursalId]);
            const actualizada = await this.consultarUnoCliente(client, `UPDATE facturas SET
           numero_factura = $1,
           estado = 'emitida',
           emitida_at = now()
         WHERE id = $2
         RETURNING *`, [numeroFactura, factura.id]);
            return actualizada;
        });
    }
    async anular(facturaId, sucursalId, usuarioId, motivo) {
        return this.database.enTransaccion(async (client) => {
            const factura = await this.consultarUnoCliente(client, `SELECT id, estado, pedido_id, total FROM facturas
         WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [facturaId, sucursalId]);
            if (!factura)
                throw new common_1.NotFoundException('Factura no encontrada');
            if (factura.estado !== 'emitida') {
                throw new common_1.BadRequestException('Solo se pueden anular facturas emitidas');
            }
            if (!motivo?.trim()) {
                throw new common_1.BadRequestException('El motivo de anulación es obligatorio');
            }
            await client.query(`UPDATE facturas SET estado = 'anulada' WHERE id = $1`, [facturaId]);
            await client.query(`INSERT INTO auditoria_logs (
           sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues
         ) VALUES ($1,$2,'ANULAR_FACTURA','facturas',$3,$4::jsonb)`, [
                sucursalId,
                usuarioId,
                facturaId,
                JSON.stringify({ motivo: motivo.trim(), pedido_id: factura.pedido_id }),
            ]);
            return {
                factura_id: facturaId,
                estado: 'anulada',
                nota: 'Nota crédito DIAN pendiente integración proveedor',
            };
        });
    }
    async obtenerPdf(facturaId, sucursalId) {
        const factura = await this.database.consultarUno(`SELECT f.*, p.numero_pedido
       FROM facturas f
       LEFT JOIN pedidos p ON p.id = f.pedido_id
       WHERE f.id = $1 AND f.sucursal_id = $2`, [facturaId, sucursalId]);
        if (!factura)
            throw new common_1.NotFoundException('Factura no encontrada');
        const config = await this.obtenerConfig(sucursalId);
        const html = this.generarHtmlFactura(factura, config);
        return { html, factura };
    }
    generarHtmlFactura(factura, config) {
        const fmt = (n) => Number(n ?? 0).toLocaleString('es-CO', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0,
        });
        const emisor = config?.razon_social ?? 'Restaurante';
        const nitEmisor = config?.nit ?? '—';
        const resolucion = config?.resolucion_dian ?? '—';
        const estado = String(factura.estado ?? 'borrador');
        const titulo = estado === 'emitida' ? 'Factura electrónica' : 'Borrador de factura';
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
  <p class="muted">Resolución DIAN: ${resolucion}</p>
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
    async consultarConfigCliente(client, sucursalId) {
        const config = await this.consultarUnoCliente(client, `SELECT id, sucursal_id, nit, razon_social, regimen, aplica_iva,
              porcentaje_iva, resolucion_dian, prefijo_factura, consecutivo_actual
       FROM configuracion_fiscal_sucursal
       WHERE sucursal_id = $1`, [sucursalId]);
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
    async consultarUnoCliente(client, sql, params) {
        const res = await client.query(sql, params);
        return res.rows[0] ?? null;
    }
    redondear(n) {
        return Math.round(n * 100) / 100;
    }
};
exports.FacturacionService = FacturacionService;
exports.FacturacionService = FacturacionService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], FacturacionService);
//# sourceMappingURL=facturacion.service.js.map