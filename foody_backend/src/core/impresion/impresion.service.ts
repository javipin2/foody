import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import WebSocket from 'ws';
import { DatabaseService } from '../database/database.service';
import { esQaSinEfectosExternos } from '../config/qa-safety';

const MAX_INTENTOS_JOB = 10;
const INTERVALO_COLA_MS = 5000;

type ResultadoImpresion = {
  exito: boolean;
  simulado?: boolean;
  mensaje?: string;
  error?: string;
};

@Injectable()
export class ImpresionService implements OnModuleInit {
  private readonly logger = new Logger(ImpresionService.name);
  private procesando = false;
  private readonly LOCK_IMPRESION_COLA = 9200003;

  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  onModuleInit() {
    if (esQaSinEfectosExternos()) {
      this.logger.warn('Cola de impresión pausada por FOODY_QA_SIN_EFECTOS');
      return;
    }
    setInterval(
      () =>
        void this.database.intentarAdvisoryLock(this.LOCK_IMPRESION_COLA, () =>
          this.procesarCola(),
        ),
      INTERVALO_COLA_MS,
    );
  }

  /** COC-REIMP-01: reencola comanda (incrementa `comanda_copia`). */
  async reimprimirPedido(
    pedidoId: string,
    sucursalId: string,
    cocinaId?: string,
  ): Promise<{ pedido_id: string; encolado: boolean }> {
    const pedido = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM pedidos WHERE id = $1 AND sucursal_id = $2`,
      [pedidoId, sucursalId],
    );
    if (!pedido) {
      throw new NotFoundException({
        error: 'PEDIDO_NO_ENCONTRADO',
        message: 'Pedido no encontrado en esta sucursal',
      });
    }
    const cocinas = await this.listarCocinasPedido(
      pedidoId,
      sucursalId,
      cocinaId,
    );
    if (!cocinas.length) {
      throw new BadRequestException({
        error: 'IMPRESION_SIN_COCINA',
        message: 'No hay tareas activas de este pedido para esa cocina',
      });
    }
    await this.encolarPorPedidoInterno(pedidoId, sucursalId, cocinaId);
    return { pedido_id: pedidoId, encolado: true };
  }

  async encolarPorPedido(pedidoId: string, sucursalId: string): Promise<void> {
    try {
      await this.encolarPorPedidoInterno(pedidoId, sucursalId);
    } catch (err) {
      const mensaje = err instanceof Error ? err.message : String(err);
      // BN-EXC-18: no tumbar pedido; dejar job en error auditable.
      this.logger.error(`Cola impresión pedido ${pedidoId}: ${mensaje}`);
      try {
        await this.database.consultar(
          `INSERT INTO impresion_cocina_jobs
             (sucursal_id, cocina_id, pedido_id, payload, estado, ultimo_error)
           VALUES ($1, NULL, $2, $3::jsonb, 'error', $4)`,
          [
            sucursalId,
            pedidoId,
            JSON.stringify({
              error_encolado: true,
              pedido_id: pedidoId,
            }),
            mensaje.slice(0, 500),
          ],
        );
      } catch (e2) {
        this.logger.error(
          `No se pudo registrar job error impresión: ${e2 instanceof Error ? e2.message : e2}`,
        );
      }
    }
  }

  async listarJobs(sucursalId: string, limit = 20) {
    return this.database.consultar(
      `SELECT j.id, j.pedido_id, j.cocina_id, j.estado, j.intentos,
              j.ultimo_error, j.simulado, j.created_at, j.procesado_at,
              c.nombre AS cocina_nombre
       FROM impresion_cocina_jobs j
       LEFT JOIN cocinas c ON c.id = j.cocina_id
       WHERE j.sucursal_id = $1
       ORDER BY j.created_at DESC
       LIMIT $2`,
      [sucursalId, limit],
    );
  }

  async procesarColaManual(): Promise<void> {
    await this.procesarCola();
  }

  async estadisticasCola(): Promise<{
    pendientes: number;
    error: number;
    enviados_24h: number;
  }> {
    const fila = await this.database.consultarUno<{
      pendientes: number;
      error: number;
      enviados_24h: number;
    }>(
      `SELECT
         COUNT(*) FILTER (WHERE estado = 'pendiente')::int AS pendientes,
         COUNT(*) FILTER (WHERE estado = 'error')::int AS error,
         COUNT(*) FILTER (
           WHERE estado = 'enviado'
             AND procesado_at > NOW() - INTERVAL '24 hours'
         )::int AS enviados_24h
       FROM impresion_cocina_jobs`,
    );
    return {
      pendientes: fila?.pendientes ?? 0,
      error: fila?.error ?? 0,
      enviados_24h: fila?.enviados_24h ?? 0,
    };
  }

  async verificarAgente(): Promise<{
    conectado: boolean;
    url: string;
    mensaje: string;
  }> {
    const url =
      this.config.get<string>('FOODY_PRINTER_WS') ?? 'ws://127.0.0.1:8765';
    if (esQaSinEfectosExternos()) {
      return {
        conectado: false,
        url,
        mensaje: 'Agente de impresión desactivado en QA aislada',
      };
    }
    try {
      const r = await this.enviarWs({ accion: 'ping' }, 3000);
      if (r.exito) {
        return {
          conectado: true,
          url,
          mensaje: 'Agente Python de impresión conectado',
        };
      }
      return {
        conectado: false,
        url,
        mensaje: r.error ?? 'Agente respondió con error',
      };
    } catch (err) {
      return {
        conectado: false,
        url,
        mensaje:
          err instanceof Error
            ? err.message
            : 'Agente no disponible - inicia foody_python_printer',
      };
    }
  }

  private async encolarPorPedidoInterno(
    pedidoId: string,
    sucursalId: string,
    cocinaId?: string,
  ): Promise<void> {
    const cocinas = await this.listarCocinasPedido(
      pedidoId,
      sucursalId,
      cocinaId,
    );
    if (!cocinas.length) return;

    const copiaRow = await this.database.consultarUno<{
      comanda_copia: number;
    }>(
      `UPDATE pedidos
       SET comanda_copia = comanda_copia + 1
       WHERE id = $1 AND sucursal_id = $2
       RETURNING comanda_copia`,
      [pedidoId, sucursalId],
    );
    const nCopia = copiaRow?.comanda_copia ?? 1;

    const pedido = await this.database.consultarUno<{
      numero_pedido: number;
      tipo: string;
      mesa_nombre: string | null;
      created_at: Date;
    }>(
      `SELECT p.numero_pedido, p.tipo, p.created_at, m.nombre AS mesa_nombre
       FROM pedidos p
       LEFT JOIN mesas m ON m.id = p.mesa_id
       WHERE p.id = $1`,
      [pedidoId],
    );

    const fecha = pedido?.created_at
      ? new Date(pedido.created_at).toLocaleString('es-CO', {
          timeZone: 'America/Bogota',
          dateStyle: 'short',
          timeStyle: 'short',
        })
      : '—';

    for (const coc of cocinas) {
      const items = await this.database.consultar<{
        nombre: string;
        cantidad: number;
        observaciones: string | null;
        producto_id: string;
        componentes_snapshot: unknown;
      }>(
        `SELECT pr.nombre, pi.cantidad, pi.observaciones, pi.producto_id,
                pcs.componentes_snapshot
         FROM pedido_items pi
         INNER JOIN productos pr ON pr.id = pi.producto_id
         LEFT JOIN pedido_combo_selecciones pcs ON pcs.pedido_item_id = pi.id
         WHERE pi.pedido_id = $1 AND pi.cocina_id = $2
           AND NOT EXISTS (
             SELECT 1 FROM pedido_combo_tareas_cocina t
             WHERE t.pedido_item_id = pi.id
           )
         ORDER BY pi.created_at ASC`,
        [pedidoId, coc.cocina_id],
      );

      const tareasCombo = await this.database.consultar<{
        nombre_combo: string | null;
        nombre_snapshot: string;
        cantidad: number;
        cantidad_combo: number;
        tipo_item: string;
        producto_padre_nombre_snapshot: string | null;
        componente_indice: number;
      }>(
        `SELECT pcs.nombre_combo, t.nombre_snapshot, t.cantidad,
                pi.cantidad AS cantidad_combo, t.tipo_item,
                t.producto_padre_nombre_snapshot, t.componente_indice
         FROM pedido_combo_tareas_cocina t
         INNER JOIN pedido_items pi ON pi.id = t.pedido_item_id
         LEFT JOIN pedido_combo_selecciones pcs ON pcs.pedido_item_id = pi.id
         WHERE t.pedido_id = $1 AND t.sucursal_id = $2 AND t.cocina_id = $3
           AND t.estado NOT IN ('no_disponible', 'pausada_decision_cliente', 'cancelada')
         ORDER BY pi.created_at ASC, t.componente_indice ASC`,
        [pedidoId, sucursalId, coc.cocina_id],
      );

      const lineas = items.map((i) => {
        const nota = i.observaciones?.trim();
        const componentes = Array.isArray(i.componentes_snapshot)
          ? (
              i.componentes_snapshot as {
                tipo_item: string;
                item_id: string;
                nombre: string;
                cantidad: number;
              }[]
            )
              .filter((c) => c.item_id !== i.producto_id)
              .map((c) => `${Number(c.cantidad) * i.cantidad}x ${c.nombre}`)
          : [];
        const detalle = componentes.length
          ? ` [Incluye: ${componentes.join(', ')}]`
          : '';
        return `${i.cantidad}x ${i.nombre}${detalle}${nota ? ` (${nota})` : ''}`;
      });
      const lineasCombo = tareasCombo.map((t) => {
        const cantidad = Number(t.cantidad) * Number(t.cantidad_combo);
        const parent =
          t.tipo_item === 'topping' && t.producto_padre_nombre_snapshot
            ? ` · Para ${t.producto_padre_nombre_snapshot}`
            : '';
        const combo = t.nombre_combo?.trim() || 'Combo';
        return `[PREPARACIÓN COMBO: ${combo}] ${cantidad}x ${t.nombre_snapshot}${parent}`;
      });

      const encabezado = [
        `=== ${coc.cocina_nombre ?? 'Cocina'} ===`,
        `Pedido #${pedido?.numero_pedido ?? '?'}`,
        pedido?.mesa_nombre ? `Mesa: ${pedido.mesa_nombre}` : null,
        `Tipo: ${pedido?.tipo ?? '—'}`,
        `Fecha: ${fecha}`,
        '------------------------',
        ...lineas,
        ...lineasCombo,
        '------------------------',
        `Copia ${nCopia}`,
        'Foody',
      ]
        .filter((l): l is string => l != null)
        .join('\n');

      await this.database.consultar(
        `INSERT INTO impresion_cocina_jobs (sucursal_id, cocina_id, pedido_id, payload)
         VALUES ($1, $2, $3, $4::jsonb)`,
        [
          sucursalId,
          coc.cocina_id,
          pedidoId,
          JSON.stringify({
            ticket: encabezado,
            pedido_id: pedidoId,
            copia: nCopia,
          }),
        ],
      );
    }

    void this.procesarCola();
  }

  private listarCocinasPedido(
    pedidoId: string,
    sucursalId: string,
    cocinaId?: string,
  ) {
    return this.database.consultar<{
      cocina_id: string;
      cocina_nombre: string | null;
    }>(
      `SELECT DISTINCT origen.cocina_id, origen.cocina_nombre
       FROM (
         SELECT pi.cocina_id, c.nombre AS cocina_nombre
         FROM pedido_items pi
         INNER JOIN pedidos p ON p.id = pi.pedido_id
         LEFT JOIN cocinas c ON c.id = pi.cocina_id
         WHERE pi.pedido_id = $1 AND p.sucursal_id = $2
           AND pi.cocina_id IS NOT NULL
           AND NOT EXISTS (
             SELECT 1 FROM pedido_combo_tareas_cocina t
             WHERE t.pedido_item_id = pi.id
           )
         UNION ALL
         SELECT t.cocina_id, c.nombre AS cocina_nombre
         FROM pedido_combo_tareas_cocina t
         INNER JOIN pedidos p ON p.id = t.pedido_id
         LEFT JOIN cocinas c ON c.id = t.cocina_id
         WHERE t.pedido_id = $1 AND t.sucursal_id = $2
           AND t.estado NOT IN ('no_disponible', 'pausada_decision_cliente', 'cancelada')
       ) origen
       WHERE $3::uuid IS NULL OR origen.cocina_id = $3::uuid
       ORDER BY origen.cocina_id`,
      [pedidoId, sucursalId, cocinaId ?? null],
    );
  }

  private async procesarCola(): Promise<void> {
    if (esQaSinEfectosExternos()) {
      this.logger.warn('Procesamiento de impresión bloqueado en QA aislada');
      return;
    }
    if (this.procesando) return;
    this.procesando = true;
    try {
      const jobs = await this.database.consultar<{
        id: string;
        payload: { ticket?: string };
        cocina_id: string | null;
        intentos: number;
        impresora_nombre: string | null;
        impresora_ip: string | null;
        impresora_tipo: string | null;
      }>(
        `SELECT j.id, j.payload, j.cocina_id, j.intentos,
                i.nombre AS impresora_nombre,
                i.ip_local AS impresora_ip,
                i.tipo AS impresora_tipo
         FROM impresion_cocina_jobs j
         LEFT JOIN impresoras i
           ON i.cocina_id = j.cocina_id
          AND i.sucursal_id = j.sucursal_id
          AND i.activa = true
         WHERE j.estado = 'pendiente'
           AND j.intentos < $1
         ORDER BY j.created_at ASC
         LIMIT 5`,
        [MAX_INTENTOS_JOB],
      );

      for (const job of jobs) {
        await this.procesarJob(job);
      }
    } finally {
      this.procesando = false;
    }
  }

  private async procesarJob(job: {
    id: string;
    payload: { ticket?: string };
    cocina_id: string | null;
    intentos: number;
    impresora_nombre: string | null;
    impresora_ip: string | null;
    impresora_tipo: string | null;
  }): Promise<void> {
    const ticket = job.payload?.ticket ?? '';
    try {
      const resultado = await this.enviarTicket(ticket, {
        cocina_id: job.cocina_id,
        impresora: job.impresora_ip
          ? {
              nombre: job.impresora_nombre,
              ip_local: job.impresora_ip,
              tipo: job.impresora_tipo,
            }
          : null,
      });

      if (resultado.exito) {
        await this.database.consultar(
          `UPDATE impresion_cocina_jobs
           SET estado = 'enviado',
               simulado = $2,
               ultimo_error = NULL,
               procesado_at = now()
           WHERE id = $1`,
          [job.id, resultado.simulado === true],
        );
        if (resultado.simulado) {
          this.logger.log(
            `Job ${job.id}: ticket simulado (sin impresora física)`,
          );
        }
        return;
      }

      await this.registrarFalloJob(
        job.id,
        job.intentos,
        resultado.error ?? 'Impresión rechazada por el agente',
      );
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      await this.registrarFalloJob(job.id, job.intentos, msg);
    }
  }

  private async registrarFalloJob(
    jobId: string,
    intentosActuales: number,
    error: string,
  ): Promise<void> {
    const nuevosIntentos = intentosActuales + 1;
    const estado = nuevosIntentos >= MAX_INTENTOS_JOB ? 'error' : 'pendiente';
    await this.database.consultar(
      `UPDATE impresion_cocina_jobs
       SET intentos = $2,
           ultimo_error = $3,
           estado = $4
       WHERE id = $1`,
      [jobId, nuevosIntentos, error.slice(0, 500), estado],
    );
    if (estado === 'error') {
      this.logger.warn(`Job impresión ${jobId} agotó reintentos: ${error}`);
    } else {
      this.logger.debug(
        `Job impresión ${jobId} reintento ${nuevosIntentos}/${MAX_INTENTOS_JOB}: ${error}`,
      );
    }
  }

  private enviarTicket(
    ticket: string,
    meta?: {
      cocina_id: string | null;
      impresora: {
        nombre: string | null;
        ip_local: string;
        tipo: string | null;
      } | null;
    },
  ): Promise<ResultadoImpresion> {
    return this.enviarWs({
      ticket,
      cuerpo: ticket,
      cocina_id: meta?.cocina_id ?? null,
      impresora: meta?.impresora ?? null,
    });
  }

  private enviarWs(
    payload: Record<string, unknown>,
    timeoutMs = 8000,
  ): Promise<ResultadoImpresion> {
    const url =
      this.config.get<string>('FOODY_PRINTER_WS') ?? 'ws://127.0.0.1:8765';

    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url);
      let resuelto = false;

      const finalizar = (fn: () => void) => {
        if (resuelto) return;
        resuelto = true;
        clearTimeout(timeout);
        try {
          ws.close();
        } catch {
          /* noop */
        }
        fn();
      };

      const timeout = setTimeout(() => {
        ws.terminate();
        reject(new Error('Timeout agente impresión'));
      }, timeoutMs);

      ws.on('open', () => {
        ws.send(JSON.stringify(payload));
      });

      ws.on('message', (raw) => {
        try {
          const texto = raw.toString();
          const data = JSON.parse(texto) as ResultadoImpresion & {
            pong?: boolean;
          };
          if (data.pong) {
            finalizar(() => resolve({ exito: true, mensaje: 'pong' }));
            return;
          }
          finalizar(() => {
            if (data.exito) {
              resolve(data);
            } else {
              resolve({
                exito: false,
                error: data.error ?? data.mensaje ?? 'Error desconocido',
              });
            }
          });
        } catch {
          finalizar(() =>
            reject(new Error('Respuesta inválida del agente de impresión')),
          );
        }
      });

      ws.on('error', (err) => {
        finalizar(() => reject(err));
      });
    });
  }
}
