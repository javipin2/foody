import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';

export type NivelAlerta = 'bajo' | 'medio' | 'alto' | 'critico';

export interface RegistrarAlertaParams {
  sucursalId: string;
  tipo: string;
  nivel: NivelAlerta;
  descripcion: string;
  referenciaId?: string;
  referenciaTipo?: string;
  /** Si true, no inserta si ya hay una pendiente del mismo tipo y referencia. */
  deduplicar?: boolean;
}

/** Umbrales según INFRAESTRUCTURA/reglas_negocio_foody.md */
export const UMBRALES_ALERTA = {
  descuentoPorcentajeAlto: 30,
  cancelacionesPorDia: 3,
  transferenciasMesa: 2,
  cuadreCajaCOP: 5000,
  subidaCostoIngredientePct: 15,
  margenBajoPct: 20,
  margenDias: 7,
  caidaVentasPct: 40,
  intentosDomiciliario: 3,
  demoraEntregaMultiplo: 2,
} as const;

@Injectable()
export class AlertasRiesgoService {
  constructor(
    private readonly database: DatabaseService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  async registrarEnTransaccion(
    client: PoolClient,
    params: RegistrarAlertaParams,
  ): Promise<void> {
    if (params.deduplicar && params.referenciaId) {
      const existe = await client.query<{ id: string }>(
        `SELECT id FROM alertas_riesgo
         WHERE sucursal_id = $1 AND tipo = $2 AND referencia_id = $3
           AND revisada = false
         LIMIT 1`,
        [params.sucursalId, params.tipo, params.referenciaId],
      );
      if (existe.rows[0]) return;
    }

    await client.query(
      `INSERT INTO alertas_riesgo (
         sucursal_id, tipo, nivel, descripcion, referencia_id, referencia_tipo
       ) VALUES ($1,$2,$3,$4,$5,$6)`,
      [
        params.sucursalId,
        params.tipo,
        params.nivel,
        params.descripcion,
        params.referenciaId ?? null,
        params.referenciaTipo ?? null,
      ],
    );
  }

  async registrar(params: RegistrarAlertaParams): Promise<void> {
    await this.database.enTransaccion(async (client) => {
      await this.registrarEnTransaccion(client, params);
    });
    void this.realtime.alertaNueva(params.sucursalId, {
      tipo: params.tipo,
      nivel: params.nivel,
    });
  }

  async evaluarCancelacionesFrecuentes(
    client: PoolClient,
    sucursalId: string,
    usuarioId: string,
    pedidoId: string,
  ): Promise<void> {
    const fila = await client.query<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM estados_pedido_historial h
       INNER JOIN pedidos p ON p.id = h.pedido_id
       WHERE h.usuario_id = $1
         AND h.estado_nuevo = 'cancelado'
         AND p.sucursal_id = $2
         AND h.fecha >= date_trunc('day', now() AT TIME ZONE 'America/Bogota')`,
      [usuarioId, sucursalId],
    );
    const total = Number(fila.rows[0]?.total ?? 0);
    if (total >= UMBRALES_ALERTA.cancelacionesPorDia) {
      await this.registrarEnTransaccion(client, {
        sucursalId,
        tipo: 'cancelaciones_frecuentes',
        nivel: 'medio',
        descripcion: `Usuario con ${total} cancelaciones hoy en la sucursal`,
        referenciaId: usuarioId,
        referenciaTipo: 'usuario',
        deduplicar: true,
      });
    }
  }

  async evaluarDemoraEntrega(
    client: PoolClient,
    pedidoId: string,
    sucursalId: string,
  ): Promise<void> {
    const pedido = await client.query<{
      created_at: Date;
      tiempo_estimado_minutos: number | null;
      numero_pedido: string;
    }>(
      `SELECT created_at, tiempo_estimado_minutos, numero_pedido
       FROM pedidos WHERE id = $1 AND sucursal_id = $2`,
      [pedidoId, sucursalId],
    );
    const fila = pedido.rows[0];
    if (!fila) return;

    const estimado = fila.tiempo_estimado_minutos ?? 25;
    const minutosReal =
      (Date.now() - new Date(fila.created_at).getTime()) / 60000;
    if (minutosReal > estimado * UMBRALES_ALERTA.demoraEntregaMultiplo) {
      await this.registrarEnTransaccion(client, {
        sucursalId,
        tipo: 'demora_excesiva_entrega',
        nivel: 'medio',
        descripcion: `${fila.numero_pedido}: entrega en ${Math.round(minutosReal)} min (estimado ${estimado} min)`,
        referenciaId: pedidoId,
        referenciaTipo: 'pedido',
        deduplicar: true,
      });
    }
  }

  async evaluarSubidaCostoIngrediente(
    client: PoolClient,
    sucursalId: string,
    ingredienteId: string,
    nombreIngrediente: string,
    costoAnterior: number,
    costoNuevo: number,
  ): Promise<void> {
    if (costoAnterior <= 0 || costoNuevo <= costoAnterior) return;
    const pct = ((costoNuevo - costoAnterior) / costoAnterior) * 100;
    if (pct > UMBRALES_ALERTA.subidaCostoIngredientePct) {
      await this.registrarEnTransaccion(client, {
        sucursalId,
        tipo: 'costo_ingrediente_sube',
        nivel: 'bajo',
        descripcion: `${nombreIngrediente}: costo subió ${Math.round(pct)}% (${costoAnterior.toFixed(2)} → ${costoNuevo.toFixed(2)})`,
        referenciaId: ingredienteId,
        referenciaTipo: 'ingrediente',
        deduplicar: true,
      });
    }
  }

  /** Evalúa reglas que requieren ventana temporal (margen, caída ventas). */
  async evaluarAlertasProgramadas(sucursalId: string): Promise<{ generadas: number }> {
    let generadas = 0;

    await this.database.enTransaccion(async (client) => {
      const margenes = await client.query<{
        producto_id: string;
        nombre: string;
        margen_prom: string;
        ventas: string;
      }>(
        `SELECT p.id AS producto_id,
                p.nombre,
                AVG(m.margen_porcentaje)::float AS margen_prom,
                COUNT(*)::text AS ventas
         FROM margenes_venta m
         INNER JOIN pedido_items pi ON pi.id = m.pedido_item_id
         INNER JOIN productos p ON p.id = pi.producto_id
         INNER JOIN pedidos ped ON ped.id = m.pedido_id
         WHERE m.sucursal_id = $1
           AND ped.created_at >= now() - interval '${UMBRALES_ALERTA.margenDias} days'
           AND ped.estado NOT IN ('cancelado', 'rechazado')
         GROUP BY p.id, p.nombre
         HAVING AVG(m.margen_porcentaje) < $2 AND COUNT(*) >= 3`,
        [sucursalId, UMBRALES_ALERTA.margenBajoPct],
      );

      for (const row of margenes.rows) {
        await this.registrarEnTransaccion(client, {
          sucursalId,
          tipo: 'margen_bajo_prolongado',
          nivel: 'bajo',
          descripcion: `${row.nombre}: margen promedio ${Number(row.margen_prom).toFixed(1)}% en ${UMBRALES_ALERTA.margenDias} días (${row.ventas} ventas)`,
          referenciaId: row.producto_id,
          referenciaTipo: 'producto',
          deduplicar: true,
        });
        generadas++;
      }

      const caidas = await client.query<{
        producto_id: string;
        nombre: string;
        semana_actual: string;
        semana_anterior: string;
      }>(
        `WITH ventas AS (
           SELECT pi.producto_id,
                  p.nombre,
                  SUM(CASE WHEN ped.created_at >= date_trunc('week', now())
                    THEN pi.cantidad ELSE 0 END)::int AS semana_actual,
                  SUM(CASE WHEN ped.created_at >= date_trunc('week', now()) - interval '7 days'
                    AND ped.created_at < date_trunc('week', now())
                    THEN pi.cantidad ELSE 0 END)::int AS semana_anterior
           FROM pedido_items pi
           INNER JOIN pedidos ped ON ped.id = pi.pedido_id
           INNER JOIN productos p ON p.id = pi.producto_id
           WHERE ped.sucursal_id = $1
             AND ped.estado NOT IN ('cancelado', 'rechazado')
             AND ped.created_at >= date_trunc('week', now()) - interval '7 days'
           GROUP BY pi.producto_id, p.nombre
         )
         SELECT producto_id, nombre,
                semana_actual::text,
                semana_anterior::text
         FROM ventas
         WHERE semana_anterior >= 5
           AND semana_actual < semana_anterior * (100 - $2) / 100.0`,
        [sucursalId, UMBRALES_ALERTA.caidaVentasPct],
      );

      for (const row of caidas.rows) {
        await this.registrarEnTransaccion(client, {
          sucursalId,
          tipo: 'caida_ventas_producto',
          nivel: 'bajo',
          descripcion: `${row.nombre}: ventas ${row.semana_actual} vs ${row.semana_anterior} unidades (semana anterior)`,
          referenciaId: row.producto_id,
          referenciaTipo: 'producto',
          deduplicar: true,
        });
        generadas++;
      }
    });

    return { generadas };
  }
}
