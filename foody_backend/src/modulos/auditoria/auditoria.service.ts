import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';

export interface FiltroTimeline {
  sucursal_id: string;
  desde: string;
  hasta: string;
}

export interface RegistroAuditoria {
  sucursalId: string;
  accion: string;
  tablaAfectada: string;
  registroId: string;
  usuarioId?: string | null;
  datosAntes?: Record<string, unknown> | null;
  datosDespues?: Record<string, unknown> | null;
}

@Injectable()
export class AuditoriaService {
  constructor(private readonly database: DatabaseService) {}

  /** INSERT centralizado en `auditoria_logs` (A-03). */
  async registrarEnTransaccion(
    client: PoolClient,
    registro: RegistroAuditoria,
  ): Promise<void> {
    await client.query(
      `INSERT INTO auditoria_logs (
         sucursal_id, usuario_id, accion, tabla_afectada, registro_id, datos_antes, datos_despues
       ) VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7::jsonb)`,
      [
        registro.sucursalId,
        registro.usuarioId ?? null,
        registro.accion,
        registro.tablaAfectada,
        registro.registroId,
        registro.datosAntes
          ? JSON.stringify(registro.datosAntes)
          : null,
        registro.datosDespues
          ? JSON.stringify(registro.datosDespues)
          : null,
      ],
    );
  }

  async registrar(registro: RegistroAuditoria): Promise<void> {
    await this.database.enTransaccion((client) =>
      this.registrarEnTransaccion(client, registro),
    );
  }

  /** Timeline unificado turno: auditoría + alertas + movimientos caja (X-010). */
  async timelineTurno(filtro: FiltroTimeline) {
    const { sucursal_id, desde, hasta } = filtro;
    const hastaExclusive = `${hasta}T23:59:59.999Z`;

    const auditoria = await this.database.consultar(
      `SELECT a.id, a.created_at AS ocurrido_at, 'auditoria' AS fuente,
              a.accion AS tipo, a.tabla_afectada, a.registro_id,
              a.datos_despues AS detalle,
              u.nombre AS usuario_nombre
       FROM auditoria_logs a
       LEFT JOIN usuarios u ON u.id = a.usuario_id
       WHERE a.sucursal_id = $1
         AND a.created_at >= $2::timestamptz
         AND a.created_at <= $3::timestamptz
       ORDER BY a.created_at ASC
       LIMIT 500`,
      [sucursal_id, desde, hastaExclusive],
    );

    const alertas = await this.database.consultar(
      `SELECT ar.id, ar.created_at AS ocurrido_at, 'alerta' AS fuente,
              ar.tipo, ar.nivel, ar.descripcion AS detalle,
              ar.referencia_id, ar.referencia_tipo, ar.revisada
       FROM alertas_riesgo ar
       WHERE ar.sucursal_id = $1
         AND ar.created_at >= $2::timestamptz
         AND ar.created_at <= $3::timestamptz
       ORDER BY ar.created_at ASC
       LIMIT 500`,
      [sucursal_id, desde, hastaExclusive],
    );

    const caja = await this.database.consultar(
      `SELECT m.id, m.created_at AS ocurrido_at, 'caja' AS fuente,
              m.tipo, m.monto, m.metodo_pago, m.descripcion AS detalle,
              m.pedido_id, u.nombre AS usuario_nombre
       FROM movimientos_caja m
       LEFT JOIN usuarios u ON u.id = m.usuario_id
       WHERE m.sucursal_id = $1
         AND m.created_at >= $2::timestamptz
         AND m.created_at <= $3::timestamptz
       ORDER BY m.created_at ASC
       LIMIT 500`,
      [sucursal_id, desde, hastaExclusive],
    );

    const pedidos = await this.database.consultar(
      `SELECT p.id, p.created_at AS ocurrido_at, 'pedido' AS fuente,
              p.estado AS tipo, p.numero_pedido, p.total, p.tipo AS canal
       FROM pedidos p
       WHERE p.sucursal_id = $1
         AND p.created_at >= $2::timestamptz
         AND p.created_at <= $3::timestamptz
       ORDER BY p.created_at ASC
       LIMIT 500`,
      [sucursal_id, desde, hastaExclusive],
    );

    const eventos = [
      ...auditoria.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
      ...alertas.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
      ...caja.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
      ...pedidos.map((e) => ({ ...e, ocurrido_at: String(e.ocurrido_at) })),
    ].sort(
      (a, b) =>
        new Date(String(a.ocurrido_at)).getTime() -
        new Date(String(b.ocurrido_at)).getTime(),
    );

    return {
      sucursal_id,
      desde,
      hasta,
      total_eventos: eventos.length,
      resumen: {
        auditoria: auditoria.length,
        alertas: alertas.length,
        caja: caja.length,
        pedidos: pedidos.length,
      },
      eventos,
    };
  }
}
