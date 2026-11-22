import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomBytes } from 'crypto';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { PedidosCuentaMesaService } from '../pedidos/pedidos-cuenta-mesa.service';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import {
  AlertasRiesgoService,
  UMBRALES_ALERTA,
} from '../alertas/alertas-riesgo.service';
import { ActualizarMesaDto } from './dto/crear-mesa.dto';
import { CrearMesaDto } from './dto/crear-mesa.dto';
import { TransferirMesaDto } from './dto/transferir-mesa.dto';
import { AsignarTurnoMesasDto } from './dto/asignar-turno-mesas.dto';
import { SQL_WHERE_PEDIDO_BLOQUEA_MESA } from '../pedidos/pedido-estados';
import { AuditoriaService } from '../auditoria/auditoria.service';

const ESTADOS_PEDIDO_CERRADO = [
  'entregado',
  'cancelado',
  'rechazado',
  'pagado',
] as const;

import { PlanFeaturesService } from '../../core/auth/plan-features.service';

@Injectable()
export class MesasService {
  constructor(
    private readonly database: DatabaseService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly planFeatures: PlanFeaturesService,
    private readonly cuentaMesa: PedidosCuentaMesaService,
    private readonly auditoria: AuditoriaService,
    private readonly estadoPedido: PedidosEstadoCommandService,
  ) {}

  async listarConEstado(sucursalId: string, incluirInactivas = false) {
    const filtroActiva = incluirInactivas ? '' : 'AND m.activa = true';
    return this.database.consultar(
      `SELECT m.id, m.nombre, m.qr_token, m.activa,
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
              p.created_at AS pedido_creado_at,
              (SELECT COUNT(*)::int FROM pedidos pq
               WHERE pq.mesa_id = m.id AND pq.estado = 'pendiente_aprobacion'
              ) AS qr_pendientes_count
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
       ORDER BY m.nombre ASC`,
      [sucursalId],
    );
  }

  async crear(dto: CrearMesaDto, restauranteId?: string) {
    if (restauranteId) {
      await this.planFeatures.assertLimiteMesas(restauranteId, dto.sucursal_id);
    }
    const qrToken = dto.qr_token?.trim() || this.generarQrToken(dto.nombre);

    const existe = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM mesas WHERE qr_token = $1`,
      [qrToken],
    );
    if (existe) {
      throw new BadRequestException({
        error: 'QR_TOKEN_DUPLICADO',
        message: 'El token QR ya está en uso',
      });
    }

    const mesa = await this.database.consultarUno(
      `INSERT INTO mesas (sucursal_id, nombre, qr_token, activa)
       VALUES ($1, $2, $3, true)
       RETURNING id, sucursal_id, nombre, qr_token, activa, created_at`,
      [dto.sucursal_id, dto.nombre.trim(), qrToken],
    );
    void this.realtime.mesasActualizadas(dto.sucursal_id);
    return mesa;
  }

  async actualizar(mesaId: string, sucursalId: string, dto: ActualizarMesaDto) {
    const mesa = await this.obtenerMesa(mesaId, sucursalId);

    if (
      dto.nombre === undefined &&
      dto.activa === undefined &&
      dto.mesera_asignada_id === undefined
    ) {
      return mesa;
    }

    if (dto.mesera_asignada_id) {
      const mesera = await this.database.consultarUno<{ id: string }>(
        `SELECT id FROM usuarios
         WHERE id = $1 AND sucursal_id = $2 AND activo = true AND rol = 'mesero'`,
        [dto.mesera_asignada_id, sucursalId],
      );
      if (!mesera) {
        throw new BadRequestException({
          error: 'MESERA_INVALIDA',
          message: 'La mesera indicada no es válida para esta sucursal',
        });
      }
    }

    let sqlMesera = '';
    const params: unknown[] = [
      mesaId,
      sucursalId,
      dto.nombre?.trim() ?? null,
      dto.activa ?? null,
    ];
    if (dto.mesera_asignada_id !== undefined) {
      if (dto.mesera_asignada_id === null) {
        sqlMesera =
          ', mesera_asignada_id = NULL, mesera_asignada_at = NULL';
      } else {
        sqlMesera =
          ', mesera_asignada_id = $5, mesera_asignada_at = now()';
        params.push(dto.mesera_asignada_id);
      }
    }

    const actualizada = await this.database.consultarUno(
      `UPDATE mesas SET
         nombre = COALESCE($3, nombre),
         activa = COALESCE($4, activa)
         ${sqlMesera}
       WHERE id = $1 AND sucursal_id = $2
       RETURNING id, sucursal_id, nombre, qr_token, activa,
                 mesera_asignada_id, mesera_asignada_at, created_at`,
      params,
    );
    void this.realtime.mesasActualizadas(sucursalId);
    return actualizada;
  }

  /** Asignación masiva de mesas por turno (admin/gerente). */
  async asignarTurno(dto: AsignarTurnoMesasDto) {
    if (!dto.asignaciones.length) {
      throw new BadRequestException('Indica al menos una mesa');
    }

    const idsMesas = dto.asignaciones.map((a) => a.mesa_id);
    const meserasIds = dto.asignaciones
      .map((a) => a.mesera_asignada_id)
      .filter((id): id is string => !!id);

    if (meserasIds.length) {
      const meseras = await this.database.consultar<{ id: string }>(
        `SELECT id FROM usuarios
         WHERE id = ANY($1::uuid[]) AND sucursal_id = $2
           AND activo = true AND rol = 'mesero'`,
        [meserasIds, dto.sucursal_id],
      );
      if (meseras.length !== new Set(meserasIds).size) {
        throw new BadRequestException({
          error: 'MESERA_INVALIDA',
          message: 'Una o más meseras no son válidas para esta sucursal',
        });
      }
    }

    await this.database.enTransaccion(async (client) => {
      for (const a of dto.asignaciones) {
        const mesa = await client.query<{ id: string }>(
          `SELECT id FROM mesas WHERE id = $1 AND sucursal_id = $2`,
          [a.mesa_id, dto.sucursal_id],
        );
        if (!mesa.rows[0]) {
          throw new NotFoundException(`Mesa ${a.mesa_id} no encontrada`);
        }

        if (a.mesera_asignada_id) {
          await client.query(
            `UPDATE mesas SET mesera_asignada_id = $3, mesera_asignada_at = now()
             WHERE id = $1 AND sucursal_id = $2`,
            [a.mesa_id, dto.sucursal_id, a.mesera_asignada_id],
          );
        } else {
          await client.query(
            `UPDATE mesas SET mesera_asignada_id = NULL, mesera_asignada_at = NULL
             WHERE id = $1 AND sucursal_id = $2`,
            [a.mesa_id, dto.sucursal_id],
          );
        }
      }
    });

    void this.realtime.mesasActualizadas(dto.sucursal_id);
    return {
      sucursal_id: dto.sucursal_id,
      mesas_actualizadas: dto.asignaciones.length,
    };
  }

  async desactivar(mesaId: string, sucursalId: string) {
    const ocupada = await this.database.consultarUno<{ id: string }>(
      `SELECT p.id FROM pedidos p
       WHERE p.mesa_id = $1
         AND p.estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
       LIMIT 1`,
      [mesaId],
    );
    if (ocupada) {
      throw new BadRequestException({
        error: 'MESA_CON_PEDIDO_ACTIVO',
        message: 'Cierra o cancela el pedido activo antes de eliminar la mesa',
      });
    }
    return this.actualizar(mesaId, sucursalId, { activa: false });
  }

  async reservar(
    mesaId: string,
    sucursalId: string,
    dto: { cliente_nombre: string; cliente_telefono?: string; reserva_hasta: string },
  ) {
    await this.obtenerMesa(mesaId, sucursalId);
    const activo = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM pedidos
       WHERE mesa_id = $1 AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
       LIMIT 1`,
      [mesaId],
    );
    if (activo) {
      throw new BadRequestException({
        error: 'MESA_OCUPADA',
        message: 'No puedes reservar una mesa con pedido activo',
      });
    }
    await this.database.consultar(
      `UPDATE mesas SET
         estado_operativo = 'reservada',
         reserva_cliente_nombre = $3,
         reserva_cliente_telefono = $4,
         reserva_hasta = $5
       WHERE id = $1 AND sucursal_id = $2`,
      [
        mesaId,
        sucursalId,
        dto.cliente_nombre.trim(),
        dto.cliente_telefono?.trim() ?? null,
        dto.reserva_hasta,
      ],
    );
    void this.realtime.mesasActualizadas(sucursalId);
    return { mesa_id: mesaId, estado_operativo: 'reservada' };
  }

  async cancelarReserva(mesaId: string, sucursalId: string) {
    await this.obtenerMesa(mesaId, sucursalId);
    await this.database.consultar(
      `UPDATE mesas SET
         estado_operativo = 'libre',
         reserva_cliente_nombre = NULL,
         reserva_cliente_telefono = NULL,
         reserva_hasta = NULL
       WHERE id = $1 AND sucursal_id = $2`,
      [mesaId, sucursalId],
    );
    void this.realtime.mesasActualizadas(sucursalId);
    return { mesa_id: mesaId, estado_operativo: 'libre' };
  }

  async unirMesas(
    sucursalId: string,
    mesaPrincipalId: string,
    mesasSecundarias: string[],
    usuarioId: string,
  ) {
    if (mesasSecundarias.includes(mesaPrincipalId)) {
      throw new BadRequestException('La mesa principal no puede estar en secundarias');
    }
    await this.obtenerMesa(mesaPrincipalId, sucursalId);
    for (const id of mesasSecundarias) {
      await this.obtenerMesa(id, sucursalId);
    }

    await this.database.enTransaccion(async (client) => {
      for (const secId of mesasSecundarias) {
        await client.query(
          `UPDATE mesas SET mesa_grupo_id = $3, estado_operativo = 'ocupada'
           WHERE id = $1 AND sucursal_id = $2`,
          [secId, sucursalId, mesaPrincipalId],
        );
        await client.query(
          `UPDATE pedidos SET mesa_id = $3
           WHERE mesa_id = $1 AND sucursal_id = $2
             AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')`,
          [secId, sucursalId, mesaPrincipalId],
        );
      }
      await client.query(
        `UPDATE mesas SET mesa_grupo_id = $2, estado_operativo = 'ocupada'
         WHERE id = $1 AND sucursal_id = $3`,
        [mesaPrincipalId, mesaPrincipalId, sucursalId],
      );
      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'UNIR_MESAS',
        tablaAfectada: 'mesas',
        registroId: mesaPrincipalId,
        usuarioId,
        datosDespues: { mesas_secundarias: mesasSecundarias },
      });
    });

    void this.realtime.mesasActualizadas(sucursalId);
    return {
      mesa_principal_id: mesaPrincipalId,
      mesas_unidas: mesasSecundarias,
    };
  }

  async registrarSalidaSinPagar(
    mesaId: string,
    sucursalId: string,
    usuarioId: string,
    dto: { cliente_nombre: string; cliente_telefono?: string; motivo: string },
    rolUsuario?: string | null,
  ) {
    const motivo = dto.motivo?.trim();
    const clienteNombre = dto.cliente_nombre?.trim();
    if (!clienteNombre) {
      throw new BadRequestException('El nombre del cliente es obligatorio');
    }
    if (!motivo) {
      throw new BadRequestException('El motivo es obligatorio');
    }

    const result = await this.database.enTransaccion(async (client) => {
      const mesa = await client.query<{
        id: string;
        mesa_grupo_id: string | null;
      }>(
        `SELECT id, mesa_grupo_id FROM mesas
         WHERE id = $1 AND sucursal_id = $2 AND activa = true
         FOR UPDATE`,
        [mesaId, sucursalId],
      );
      if (!mesa.rows[0]) {
        throw new NotFoundException('Mesa no encontrada');
      }

      const mesaIds = await this.resolverIdsMesasGrupo(
        client,
        mesa.rows[0].id,
        mesa.rows[0].mesa_grupo_id,
      );

      const pedidos = await client.query<{
        id: string;
        numero_pedido: string;
        estado: string;
        tipo: string;
        total: string;
        monto_pagado: string;
        mesa_id: string;
      }>(
        `SELECT id, numero_pedido, estado, tipo, total,
                COALESCE(monto_pagado, 0) AS monto_pagado, mesa_id
         FROM pedidos
         WHERE mesa_id = ANY($1::uuid[])
           AND sucursal_id = $2
           AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
         FOR UPDATE`,
        [mesaIds, sucursalId],
      );
      if (!pedidos.rows.length) {
        throw new BadRequestException('No hay pedidos activos en la mesa');
      }

      const cuentas: { pedido_id: string; monto: number }[] = [];
      const pedidosCerrados: {
        id: string;
        numero_pedido: string;
        estado_anterior: string;
        saldo_cxc: number;
      }[] = [];

      for (const p of pedidos.rows) {
        const total = Number(p.total);
        const montoPagado = Number(p.monto_pagado);
        const saldo = Math.max(0, total - montoPagado);
        const estadoAnterior = p.estado;

        if (saldo > 0.01) {
          await client.query(
            `INSERT INTO cuentas_por_cobrar (
               sucursal_id, pedido_id, cliente_nombre, cliente_telefono, monto, usuario_id
             ) VALUES ($1,$2,$3,$4,$5,$6)`,
            [
              sucursalId,
              p.id,
              clienteNombre,
              dto.cliente_telefono?.trim() ?? null,
              saldo,
              usuarioId,
            ],
          );
          cuentas.push({ pedido_id: p.id, monto: saldo });
        }

        const montoFinal = saldo > 0.01 ? montoPagado : total;
        const motivoEstado =
          saldo > 0.01
            ? `Salió sin pagar (CxC $${saldo.toFixed(2)}): ${motivo}`
            : `Cierre mesa sin saldo pendiente: ${motivo}`;

        // PED-BYPASS-01: montos fuera del command; estado vía puerta única.
        await client.query(
          `UPDATE pedidos
           SET monto_pagado = $2,
               metodo_pago = COALESCE(NULLIF(metodo_pago, ''), 'pendiente')
           WHERE id = $1`,
          [p.id, montoFinal],
        );
        await this.estadoPedido.aplicarEstadoEnTransaccion(client, {
          pedidoId: p.id,
          sucursalId,
          nuevoEstado: 'pagado',
          origen: 'cobro',
          usuarioId,
          estadoAnterior: estadoAnterior,
          tipo: p.tipo,
          motivo: motivoEstado,
          rol: rolUsuario,
        });

        pedidosCerrados.push({
          id: p.id,
          numero_pedido: p.numero_pedido,
          estado_anterior: estadoAnterior,
          saldo_cxc: saldo > 0.01 ? saldo : 0,
        });
      }

      for (const idMesa of mesaIds) {
        await this.cuentaMesa.liberarMesaSiSinPedidosActivos(
          client,
          idMesa,
          sucursalId,
        );
      }

      await this.alertasRiesgo.registrarEnTransaccion(client, {
        sucursalId,
        tipo: 'salio_sin_pagar',
        nivel: 'alto',
        descripcion: `Mesa sin pago: ${motivo}`,
        referenciaId: mesaId,
        referenciaTipo: 'mesa',
        deduplicar: false,
      });

      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId,
        accion: 'SALIO_SIN_PAGAR',
        tablaAfectada: 'mesas',
        registroId: mesaId,
        usuarioId,
        datosDespues: {
          motivo,
          cliente_nombre: clienteNombre,
          cuentas,
          pedidos_cerrados: pedidosCerrados,
          mesas_grupo: mesaIds,
        },
      });

      return {
        mesa_id: mesaId,
        mesas_liberadas: mesaIds,
        cuentas_creadas: cuentas,
        pedidos_cerrados: pedidosCerrados,
      };
    });

    for (const p of result.pedidos_cerrados) {
      void this.realtime.pedidoActualizado({
        pedido_id: p.id,
        sucursal_id: sucursalId,
        estado: 'pagado',
        numero_pedido: p.numero_pedido,
      });
    }
    void this.realtime.mesasActualizadas(sucursalId);
    return result;
  }

  async transferir(dto: TransferirMesaDto, usuarioId: string) {
    if (dto.mesa_origen_id === dto.mesa_destino_id) {
      throw new BadRequestException({
        error: 'MISMA_MESA',
        message: 'La mesa destino debe ser distinta a la origen',
      });
    }

    await this.obtenerMesa(dto.mesa_origen_id, dto.sucursal_id);
    await this.obtenerMesa(dto.mesa_destino_id, dto.sucursal_id);

    const result = await this.database.enTransaccion(async (client) => {
      await client.query(
        `SELECT id FROM mesas WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [dto.mesa_origen_id, dto.sucursal_id],
      );
      await client.query(
        `SELECT id FROM mesas WHERE id = $1 AND sucursal_id = $2 FOR UPDATE`,
        [dto.mesa_destino_id, dto.sucursal_id],
      );

      const pedido = await client.query<{
        id: string;
        mesa_id: string | null;
        tipo: string;
        estado: string;
        numero_pedido: string;
      }>(
        `SELECT id, mesa_id, tipo, estado, numero_pedido
         FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`,
        [dto.pedido_id, dto.sucursal_id],
      );

      const fila = pedido.rows[0];
      if (!fila) {
        throw new NotFoundException('Pedido no encontrado');
      }
      if (fila.tipo !== 'mesa') {
        throw new BadRequestException({
          error: 'NO_ES_PEDIDO_MESA',
          message: 'Solo se pueden transferir pedidos de mesa',
        });
      }
      if (fila.mesa_id !== dto.mesa_origen_id) {
        throw new BadRequestException({
          error: 'PEDIDO_NO_EN_MESA_ORIGEN',
          message: 'El pedido no está en la mesa origen indicada',
        });
      }
      if ((ESTADOS_PEDIDO_CERRADO as readonly string[]).includes(fila.estado)) {
        throw new BadRequestException({
          error: 'PEDIDO_CERRADO',
          message: 'No se puede transferir un pedido cerrado',
        });
      }

      const destinoOcupada = await client.query<{ id: string }>(
        `SELECT id FROM pedidos
         WHERE mesa_id = $1
           AND id <> $2
           AND estado NOT IN ('entregado', 'cancelado', 'rechazado', 'pagado')
         LIMIT 1`,
        [dto.mesa_destino_id, dto.pedido_id],
      );
      if (destinoOcupada.rows[0]) {
        throw new BadRequestException({
          error: 'MESA_DESTINO_OCUPADA',
          message: 'La mesa destino tiene otro pedido activo',
        });
      }

      await client.query(
        `UPDATE pedidos SET mesa_id = $2 WHERE id = $1`,
        [dto.pedido_id, dto.mesa_destino_id],
      );

      await client.query(
        `UPDATE mesas d
         SET estado_operativo = 'ocupada',
             mesera_asignada_id = COALESCE(d.mesera_asignada_id, o.mesera_asignada_id),
             mesera_asignada_at = COALESCE(d.mesera_asignada_at, o.mesera_asignada_at)
         FROM mesas o
         WHERE d.id = $1 AND d.sucursal_id = $2
           AND o.id = $3 AND o.sucursal_id = $2`,
        [dto.mesa_destino_id, dto.sucursal_id, dto.mesa_origen_id],
      );

      await client.query(
        `UPDATE pedidos p
         SET mesera_id = COALESCE(p.mesera_id, m.mesera_asignada_id)
         FROM mesas m
         WHERE p.id = $1 AND m.id = $2`,
        [dto.pedido_id, dto.mesa_destino_id],
      );

      const activoOrigen = await client.query<{ n: number }>(
        `SELECT COUNT(*)::int AS n FROM pedidos
         WHERE mesa_id = $1 AND sucursal_id = $2
           AND (${SQL_WHERE_PEDIDO_BLOQUEA_MESA})`,
        [dto.mesa_origen_id, dto.sucursal_id],
      );
      if ((activoOrigen.rows[0]?.n ?? 0) === 0) {
        await client.query(
          `UPDATE mesas
           SET mesera_asignada_id = NULL, mesera_asignada_at = NULL,
               estado_operativo = 'libre', mesa_grupo_id = NULL
           WHERE id = $1 AND sucursal_id = $2`,
          [dto.mesa_origen_id, dto.sucursal_id],
        );
      }

      const transferencia = await client.query<{ id: string }>(
        `INSERT INTO transferencias_mesa
           (pedido_id, mesa_origen_id, mesa_destino_id, usuario_id, motivo)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id`,
        [
          dto.pedido_id,
          dto.mesa_origen_id,
          dto.mesa_destino_id,
          usuarioId,
          dto.motivo?.trim() || null,
        ],
      );

      const previas = await client.query<{ total: string }>(
        `SELECT COUNT(*)::text AS total FROM transferencias_mesa WHERE pedido_id = $1`,
        [dto.pedido_id],
      );
      const totalTransferencias = Number(previas.rows[0]?.total ?? 0);

      await this.auditoria.registrarEnTransaccion(client, {
        sucursalId: dto.sucursal_id,
        accion: 'TRANSFERIR_MESA',
        tablaAfectada: 'mesas',
        registroId: dto.pedido_id,
        usuarioId,
        datosDespues: {
          pedido_id: dto.pedido_id,
          numero_pedido: fila.numero_pedido,
          mesa_origen_id: dto.mesa_origen_id,
          mesa_destino_id: dto.mesa_destino_id,
          motivo: dto.motivo?.trim() || null,
        },
      });

      if (totalTransferencias > UMBRALES_ALERTA.transferenciasMesa) {
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
        alerta_transferencias_multiples:
          totalTransferencias > UMBRALES_ALERTA.transferenciasMesa,
      };
    });
    void this.realtime.mesasActualizadas(dto.sucursal_id);
    void this.realtime.pedidoActualizado({
      pedido_id: dto.pedido_id,
      sucursal_id: dto.sucursal_id,
    });
    return result;
  }

  private normalizarOrigenWeb(baseUrl?: string): string {
    const raw = (baseUrl ?? process.env.CLIENT_WEB_URL ?? 'http://localhost')
      .trim()
      .replace(/\/$/, '');
    try {
      const conProtocolo = raw.includes('://') ? raw : `http://${raw}`;
      const u = new URL(conProtocolo);
      return `${u.protocol}//${u.host}`;
    } catch {
      return raw.split('/').slice(0, 3).join('/') || 'http://localhost';
    }
  }

  async obtenerQr(mesaId: string, sucursalId: string, baseUrl?: string) {
    const mesa = await this.obtenerMesa(mesaId, sucursalId);
    const origen = this.normalizarOrigenWeb(baseUrl);
    const url = `${origen}/mesa/${mesa.qr_token}`;
    const html = this.generarHtmlQr(mesa.nombre as string, url, mesa.qr_token as string);

    return { mesa, url, html };
  }

  private async resolverIdsMesasGrupo(
    client: PoolClient,
    mesaId: string,
    mesaGrupoId: string | null,
  ): Promise<string[]> {
    const grupoId = mesaGrupoId ?? mesaId;
    const filas = await client.query<{ id: string }>(
      `SELECT id FROM mesas
       WHERE sucursal_id = (
         SELECT sucursal_id FROM mesas WHERE id = $1 LIMIT 1
       )
         AND (id = $2 OR mesa_grupo_id = $2)`,
      [mesaId, grupoId],
    );
    const ids = filas.rows.map((f) => f.id);
    return ids.length ? ids : [mesaId];
  }

  private async obtenerMesa(mesaId: string, sucursalId: string) {
    const mesa = await this.database.consultarUno<{
      id: string;
      nombre: string;
      qr_token: string;
      activa: boolean;
      sucursal_id: string;
    }>(
      `SELECT id, nombre, qr_token, activa, sucursal_id
       FROM mesas WHERE id = $1 AND sucursal_id = $2`,
      [mesaId, sucursalId],
    );
    if (!mesa) throw new NotFoundException('Mesa no encontrada');
    return mesa;
  }

  private generarQrToken(_nombre: string): string {
    return randomBytes(16).toString('hex');
  }

  private generarHtmlQr(nombre: string, url: string, token: string): string {
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
}
