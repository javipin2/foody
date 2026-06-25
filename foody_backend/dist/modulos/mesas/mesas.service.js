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
exports.MesasService = void 0;
const common_1 = require("@nestjs/common");
const crypto_1 = require("crypto");
const database_service_1 = require("../../core/database/database.service");
const realtime_broadcast_service_1 = require("../../core/realtime/realtime-broadcast.service");
const alertas_riesgo_service_1 = require("../alertas/alertas-riesgo.service");
const ESTADOS_PEDIDO_CERRADO = [
    'entregado',
    'cancelado',
    'rechazado',
    'pagado',
];
let MesasService = class MesasService {
    database;
    realtime;
    alertasRiesgo;
    constructor(database, realtime, alertasRiesgo) {
        this.database = database;
        this.realtime = realtime;
        this.alertasRiesgo = alertasRiesgo;
    }
    async listarConEstado(sucursalId, incluirInactivas = false) {
        const filtroActiva = incluirInactivas ? '' : 'AND m.activa = true';
        return this.database.consultar(`SELECT m.id, m.nombre, m.qr_token, m.activa,
              m.mesera_asignada_id,
              m.mesera_asignada_at,
              m.estado_operativo,
              m.reserva_hasta,
              m.reserva_cliente_nombre,
              m.reserva_cliente_telefono,
              m.mesa_grupo_id,
              u.nombre AS mesera_nombre,
              p.id AS pedido_id,
              p.estado AS pedido_estado,
              p.numero_pedido,
              p.created_at AS pedido_creado_at
       FROM mesas m
       LEFT JOIN usuarios u ON u.id = m.mesera_asignada_id
       LEFT JOIN LATERAL (
         SELECT id, estado, numero_pedido, created_at
         FROM pedidos
         WHERE mesa_id = m.id
           AND estado NOT IN ('cancelado', 'rechazado', 'pagado')
           AND (
             estado <> 'entregado'
             OR COALESCE(monto_pagado, 0) < total - 0.01
           )
         ORDER BY created_at DESC
         LIMIT 1
       ) p ON true
       WHERE m.sucursal_id = $1 ${filtroActiva}
       ORDER BY m.nombre ASC`, [sucursalId]);
    }
    async crear(dto) {
        const qrToken = dto.qr_token?.trim() || this.generarQrToken(dto.nombre);
        const existe = await this.database.consultarUno(`SELECT id FROM mesas WHERE qr_token = $1`, [qrToken]);
        if (existe) {
            throw new common_1.BadRequestException({
                error: 'QR_TOKEN_DUPLICADO',
                message: 'El token QR ya está en uso',
            });
        }
        const mesa = await this.database.consultarUno(`INSERT INTO mesas (sucursal_id, nombre, qr_token, activa)
       VALUES ($1, $2, $3, true)
       RETURNING id, sucursal_id, nombre, qr_token, activa, created_at`, [dto.sucursal_id, dto.nombre.trim(), qrToken]);
        void this.realtime.mesasActualizadas(dto.sucursal_id);
        return mesa;
    }
    async actualizar(mesaId, sucursalId, dto) {
        const mesa = await this.obtenerMesa(mesaId, sucursalId);
        if (dto.nombre === undefined &&
            dto.activa === undefined &&
            dto.mesera_asignada_id === undefined) {
            return mesa;
        }
        if (dto.mesera_asignada_id) {
            const mesera = await this.database.consultarUno(`SELECT id FROM usuarios
         WHERE id = $1 AND sucursal_id = $2 AND activo = true AND rol = 'mesero'`, [dto.mesera_asignada_id, sucursalId]);
            if (!mesera) {
                throw new common_1.BadRequestException({
                    error: 'MESERA_INVALIDA',
                    message: 'La mesera indicada no es válida para esta sucursal',
                });
            }
        }
        let sqlMesera = '';
        const params = [
            mesaId,
            sucursalId,
            dto.nombre?.trim() ?? null,
            dto.activa ?? null,
        ];
        if (dto.mesera_asignada_id !== undefined) {
            if (dto.mesera_asignada_id === null) {
                sqlMesera =
                    ', mesera_asignada_id = NULL, mesera_asignada_at = NULL';
            }
            else {
                sqlMesera =
                    ', mesera_asignada_id = $5, mesera_asignada_at = now()';
                params.push(dto.mesera_asignada_id);
            }
        }
        const actualizada = await this.database.consultarUno(`UPDATE mesas SET
         nombre = COALESCE($3, nombre),
         activa = COALESCE($4, activa)
         ${sqlMesera}
       WHERE id = $1 AND sucursal_id = $2
       RETURNING id, sucursal_id, nombre, qr_token, activa,
                 mesera_asignada_id, mesera_asignada_at, created_at`, params);
        void this.realtime.mesasActualizadas(sucursalId);
        return actualizada;
    }
    async asignarTurno(dto) {
        if (!dto.asignaciones.length) {
            throw new common_1.BadRequestException('Indica al menos una mesa');
        }
        const idsMesas = dto.asignaciones.map((a) => a.mesa_id);
        const meserasIds = dto.asignaciones
            .map((a) => a.mesera_asignada_id)
            .filter((id) => !!id);
        if (meserasIds.length) {
            const meseras = await this.database.consultar(`SELECT id FROM usuarios
         WHERE id = ANY($1::uuid[]) AND sucursal_id = $2
           AND activo = true AND rol = 'mesero'`, [meserasIds, dto.sucursal_id]);
            if (meseras.length !== new Set(meserasIds).size) {
                throw new common_1.BadRequestException({
                    error: 'MESERA_INVALIDA',
                    message: 'Una o más meseras no son válidas para esta sucursal',
                });
            }
        }
        await this.database.enTransaccion(async (client) => {
            for (const a of dto.asignaciones) {
                const mesa = await client.query(`SELECT id FROM mesas WHERE id = $1 AND sucursal_id = $2`, [a.mesa_id, dto.sucursal_id]);
                if (!mesa.rows[0]) {
                    throw new common_1.NotFoundException(`Mesa ${a.mesa_id} no encontrada`);
                }
                if (a.mesera_asignada_id) {
                    await client.query(`UPDATE mesas SET mesera_asignada_id = $3, mesera_asignada_at = now()
             WHERE id = $1 AND sucursal_id = $2`, [a.mesa_id, dto.sucursal_id, a.mesera_asignada_id]);
                }
                else {
                    await client.query(`UPDATE mesas SET mesera_asignada_id = NULL, mesera_asignada_at = NULL
             WHERE id = $1 AND sucursal_id = $2`, [a.mesa_id, dto.sucursal_id]);
                }
            }
        });
        void this.realtime.mesasActualizadas(dto.sucursal_id);
        return {
            sucursal_id: dto.sucursal_id,
            mesas_actualizadas: dto.asignaciones.length,
        };
    }
    async desactivar(mesaId, sucursalId) {
        const ocupada = await this.database.consultarUno(`SELECT p.id FROM pedidos p
       WHERE p.mesa_id = $1
         AND p.estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
       LIMIT 1`, [mesaId]);
        if (ocupada) {
            throw new common_1.BadRequestException({
                error: 'MESA_CON_PEDIDO_ACTIVO',
                message: 'Cierra o cancela el pedido activo antes de eliminar la mesa',
            });
        }
        return this.actualizar(mesaId, sucursalId, { activa: false });
    }
    async reservar(mesaId, sucursalId, dto) {
        await this.obtenerMesa(mesaId, sucursalId);
        const activo = await this.database.consultarUno(`SELECT id FROM pedidos
       WHERE mesa_id = $1 AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
       LIMIT 1`, [mesaId]);
        if (activo) {
            throw new common_1.BadRequestException({
                error: 'MESA_OCUPADA',
                message: 'No puedes reservar una mesa con pedido activo',
            });
        }
        await this.database.consultar(`UPDATE mesas SET
         estado_operativo = 'reservada',
         reserva_cliente_nombre = $3,
         reserva_cliente_telefono = $4,
         reserva_hasta = $5
       WHERE id = $1 AND sucursal_id = $2`, [
            mesaId,
            sucursalId,
            dto.cliente_nombre.trim(),
            dto.cliente_telefono?.trim() ?? null,
            dto.reserva_hasta,
        ]);
        void this.realtime.mesasActualizadas(sucursalId);
        return { mesa_id: mesaId, estado_operativo: 'reservada' };
    }
    async cancelarReserva(mesaId, sucursalId) {
        await this.obtenerMesa(mesaId, sucursalId);
        await this.database.consultar(`UPDATE mesas SET
         estado_operativo = 'libre',
         reserva_cliente_nombre = NULL,
         reserva_cliente_telefono = NULL,
         reserva_hasta = NULL
       WHERE id = $1 AND sucursal_id = $2`, [mesaId, sucursalId]);
        void this.realtime.mesasActualizadas(sucursalId);
        return { mesa_id: mesaId, estado_operativo: 'libre' };
    }
    async unirMesas(sucursalId, mesaPrincipalId, mesasSecundarias, usuarioId) {
        if (mesasSecundarias.includes(mesaPrincipalId)) {
            throw new common_1.BadRequestException('La mesa principal no puede estar en secundarias');
        }
        await this.obtenerMesa(mesaPrincipalId, sucursalId);
        for (const id of mesasSecundarias) {
            await this.obtenerMesa(id, sucursalId);
        }
        await this.database.enTransaccion(async (client) => {
            for (const secId of mesasSecundarias) {
                await client.query(`UPDATE mesas SET mesa_grupo_id = $3, estado_operativo = 'ocupada'
           WHERE id = $1 AND sucursal_id = $2`, [secId, sucursalId, mesaPrincipalId]);
                await client.query(`UPDATE pedidos SET mesa_id = $3
           WHERE mesa_id = $1 AND sucursal_id = $2
             AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')`, [secId, sucursalId, mesaPrincipalId]);
            }
            await client.query(`UPDATE mesas SET mesa_grupo_id = $2, estado_operativo = 'ocupada'
         WHERE id = $1 AND sucursal_id = $3`, [mesaPrincipalId, mesaPrincipalId, sucursalId]);
            await client.query(`INSERT INTO auditoria_logs (sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues)
         VALUES ($1,$2,'UNIR_MESAS','mesas',$3,$4::jsonb)`, [
                sucursalId,
                usuarioId,
                mesaPrincipalId,
                JSON.stringify({ mesas_secundarias: mesasSecundarias }),
            ]);
        });
        void this.realtime.mesasActualizadas(sucursalId);
        return {
            mesa_principal_id: mesaPrincipalId,
            mesas_unidas: mesasSecundarias,
        };
    }
    async registrarSalidaSinPagar(mesaId, sucursalId, usuarioId, dto) {
        const result = await this.database.enTransaccion(async (client) => {
            const pedidos = await client.query(`SELECT id, numero_pedido, total, COALESCE(monto_pagado, 0) AS monto_pagado
         FROM pedidos
         WHERE mesa_id = $1 AND sucursal_id = $2
           AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
         FOR UPDATE`, [mesaId, sucursalId]);
            if (!pedidos.rows.length) {
                throw new common_1.BadRequestException('No hay pedidos activos en la mesa');
            }
            const cuentas = [];
            for (const p of pedidos.rows) {
                const saldo = Number(p.total) - Number(p.monto_pagado);
                if (saldo <= 0)
                    continue;
                await client.query(`INSERT INTO cuentas_por_cobrar (
             sucursal_id, pedido_id, cliente_nombre, cliente_telefono, monto, usuario_id
           ) VALUES ($1,$2,$3,$4,$5,$6)`, [
                    sucursalId,
                    p.id,
                    dto.cliente_nombre.trim(),
                    dto.cliente_telefono?.trim() ?? null,
                    saldo,
                    usuarioId,
                ]);
                cuentas.push({ pedido_id: p.id, monto: saldo });
            }
            await this.alertasRiesgo.registrarEnTransaccion(client, {
                sucursalId,
                tipo: 'salio_sin_pagar',
                nivel: 'alto',
                descripcion: `Mesa sin pago: ${dto.motivo.trim()}`,
                referenciaId: mesaId,
                referenciaTipo: 'mesa',
                deduplicar: false,
            });
            await client.query(`INSERT INTO auditoria_logs (sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues)
         VALUES ($1,$2,'SALIO_SIN_PAGAR','mesas',$3,$4::jsonb)`, [
                sucursalId,
                usuarioId,
                mesaId,
                JSON.stringify({ motivo: dto.motivo, cuentas }),
            ]);
            return { mesa_id: mesaId, cuentas_creadas: cuentas };
        });
        void this.realtime.mesasActualizadas(sucursalId);
        return result;
    }
    async transferir(dto, usuarioId) {
        if (dto.mesa_origen_id === dto.mesa_destino_id) {
            throw new common_1.BadRequestException({
                error: 'MISMA_MESA',
                message: 'La mesa destino debe ser distinta a la origen',
            });
        }
        await this.obtenerMesa(dto.mesa_origen_id, dto.sucursal_id);
        await this.obtenerMesa(dto.mesa_destino_id, dto.sucursal_id);
        const result = await this.database.enTransaccion(async (client) => {
            await client.query(`SELECT id FROM mesas WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`, [dto.mesa_destino_id, dto.sucursal_id]);
            const pedido = await client.query(`SELECT id, mesa_id, tipo, estado, numero_pedido
         FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`, [dto.pedido_id, dto.sucursal_id]);
            const fila = pedido.rows[0];
            if (!fila) {
                throw new common_1.NotFoundException('Pedido no encontrado');
            }
            if (fila.tipo !== 'mesa') {
                throw new common_1.BadRequestException({
                    error: 'NO_ES_PEDIDO_MESA',
                    message: 'Solo se pueden transferir pedidos de mesa',
                });
            }
            if (fila.mesa_id !== dto.mesa_origen_id) {
                throw new common_1.BadRequestException({
                    error: 'PEDIDO_NO_EN_MESA_ORIGEN',
                    message: 'El pedido no está en la mesa origen indicada',
                });
            }
            if (ESTADOS_PEDIDO_CERRADO.includes(fila.estado)) {
                throw new common_1.BadRequestException({
                    error: 'PEDIDO_CERRADO',
                    message: 'No se puede transferir un pedido cerrado',
                });
            }
            const destinoOcupada = await client.query(`SELECT id FROM pedidos
         WHERE mesa_id = $1
           AND id <> $2
           AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
         LIMIT 1`, [dto.mesa_destino_id, dto.pedido_id]);
            if (destinoOcupada.rows[0]) {
                throw new common_1.BadRequestException({
                    error: 'MESA_DESTINO_OCUPADA',
                    message: 'La mesa destino tiene otro pedido activo',
                });
            }
            await client.query(`UPDATE pedidos SET mesa_id = $2 WHERE id = $1`, [dto.pedido_id, dto.mesa_destino_id]);
            await client.query(`UPDATE mesas SET estado_operativo = 'ocupada'
         WHERE id = $1 AND sucursal_id = $2`, [dto.mesa_destino_id, dto.sucursal_id]);
            const transferencia = await client.query(`INSERT INTO transferencias_mesa
           (pedido_id, mesa_origen_id, mesa_destino_id, usuario_id, motivo)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`, [
                dto.pedido_id,
                dto.mesa_origen_id,
                dto.mesa_destino_id,
                usuarioId,
                dto.motivo?.trim() || null,
            ]);
            const previas = await client.query(`SELECT COUNT(*)::text AS total FROM transferencias_mesa WHERE pedido_id = $1`, [dto.pedido_id]);
            const totalTransferencias = Number(previas.rows[0]?.total ?? 0);
            await client.query(`INSERT INTO auditoria_logs (sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_despues)
         VALUES ($1,$2,'TRANSFERIR_MESA','mesas',$3,$4::jsonb)`, [
                dto.sucursal_id,
                usuarioId,
                dto.pedido_id,
                JSON.stringify({
                    pedido_id: dto.pedido_id,
                    numero_pedido: fila.numero_pedido,
                    mesa_origen_id: dto.mesa_origen_id,
                    mesa_destino_id: dto.mesa_destino_id,
                    motivo: dto.motivo?.trim() || null,
                }),
            ]);
            if (totalTransferencias > alertas_riesgo_service_1.UMBRALES_ALERTA.transferenciasMesa) {
                await this.alertasRiesgo.registrarEnTransaccion(client, {
                    sucursalId: dto.sucursal_id,
                    tipo: 'transferencia_mesa_multiple',
                    nivel: 'bajo',
                    descripcion: `${fila.numero_pedido}: ${totalTransferencias} transferencias de mesa`,
                    referenciaId: dto.pedido_id,
                    referenciaTipo: 'pedido',
                    deduplicar: true,
                });
            }
            return {
                transferencia_id: transferencia.rows[0]?.id,
                pedido_id: dto.pedido_id,
                numero_pedido: fila.numero_pedido,
                mesa_origen_id: dto.mesa_origen_id,
                mesa_destino_id: dto.mesa_destino_id,
                total_transferencias: totalTransferencias,
                alerta_transferencias_multiples: totalTransferencias > alertas_riesgo_service_1.UMBRALES_ALERTA.transferenciasMesa,
            };
        });
        void this.realtime.mesasActualizadas(dto.sucursal_id);
        void this.realtime.pedidoActualizado({
            pedido_id: dto.pedido_id,
            sucursal_id: dto.sucursal_id,
        });
        return result;
    }
    normalizarOrigenWeb(baseUrl) {
        const raw = (baseUrl ?? process.env.CLIENT_WEB_URL ?? 'http://localhost')
            .trim()
            .replace(/\/$/, '');
        try {
            const conProtocolo = raw.includes('://') ? raw : `http://${raw}`;
            const u = new URL(conProtocolo);
            return `${u.protocol}//${u.host}`;
        }
        catch {
            return raw.split('/').slice(0, 3).join('/') || 'http://localhost';
        }
    }
    async obtenerQr(mesaId, sucursalId, baseUrl) {
        const mesa = await this.obtenerMesa(mesaId, sucursalId);
        const origen = this.normalizarOrigenWeb(baseUrl);
        const url = `${origen}/mesa/${mesa.qr_token}`;
        const html = this.generarHtmlQr(mesa.nombre, url, mesa.qr_token);
        return { mesa, url, html };
    }
    async obtenerMesa(mesaId, sucursalId) {
        const mesa = await this.database.consultarUno(`SELECT id, nombre, qr_token, activa, sucursal_id
       FROM mesas WHERE id = $1 AND sucursal_id = $2`, [mesaId, sucursalId]);
        if (!mesa)
            throw new common_1.NotFoundException('Mesa no encontrada');
        return mesa;
    }
    generarQrToken(_nombre) {
        return (0, crypto_1.randomBytes)(16).toString('hex');
    }
    generarHtmlQr(nombre, url, token) {
        return `<!DOCTYPE html>
<html lang="es">
<head><meta charset="utf-8"><title>QR ${nombre}</title>
<style>
  body{font-family:Arial,sans-serif;text-align:center;padding:32px;color:#1e293b}
  h1{color:#FF6B35;font-size:22px}
  .url{font-size:14px;word-break:break-all;margin:16px 0;padding:12px;background:#f1f5f9;border-radius:8px}
  .token{font-size:12px;color:#64748b}
</style></head>
<body>
  <h1>${nombre}</h1>
  <p>Escanea o abre este enlace para pedir desde la mesa:</p>
  <div class="url"><a href="${url}">${url}</a></div>
  <p class="token">Token: ${token}</p>
  <p style="font-size:12px;color:#94a3b8">Foody · Imprime y coloca en la mesa</p>
</body></html>`;
    }
};
exports.MesasService = MesasService;
exports.MesasService = MesasService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        realtime_broadcast_service_1.RealtimeBroadcastService,
        alertas_riesgo_service_1.AlertasRiesgoService])
], MesasService);
//# sourceMappingURL=mesas.service.js.map