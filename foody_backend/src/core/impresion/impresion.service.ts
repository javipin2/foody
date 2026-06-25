import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import WebSocket from 'ws';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class ImpresionService implements OnModuleInit {
  private readonly logger = new Logger(ImpresionService.name);
  private procesando = false;

  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  onModuleInit() {
    setInterval(() => void this.procesarCola(), 5000);
  }

  async encolarPorPedido(pedidoId: string, sucursalId: string): Promise<void> {
    try {
      await this.encolarPorPedidoInterno(pedidoId, sucursalId);
    } catch (err) {
      this.logger.warn(
        `Cola impresión pedido ${pedidoId}: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  private async encolarPorPedidoInterno(
    pedidoId: string,
    sucursalId: string,
  ): Promise<void> {
    const cocinas = await this.database.consultar<{
      cocina_id: string;
      cocina_nombre: string | null;
    }>(
      `SELECT DISTINCT pi.cocina_id, c.nombre AS cocina_nombre
       FROM pedido_items pi
       INNER JOIN pedidos p ON p.id = pi.pedido_id
       LEFT JOIN cocinas c ON c.id = pi.cocina_id
       WHERE pi.pedido_id = $1 AND p.sucursal_id = $2 AND pi.cocina_id IS NOT NULL`,
      [pedidoId, sucursalId],
    );
    if (!cocinas.length) return;

    const pedido = await this.database.consultarUno<{
      numero_pedido: number;
      tipo: string;
    }>(
      `SELECT numero_pedido, tipo FROM pedidos WHERE id = $1`,
      [pedidoId],
    );

    for (const coc of cocinas) {
      const items = await this.database.consultar<{
        nombre: string;
        cantidad: number;
        observaciones: string | null;
      }>(
        `SELECT pr.nombre, pi.cantidad, pi.observaciones
         FROM pedido_items pi
         INNER JOIN productos pr ON pr.id = pi.producto_id
         WHERE pi.pedido_id = $1 AND pi.cocina_id = $2
         ORDER BY pi.created_at ASC`,
        [pedidoId, coc.cocina_id],
      );

      const lineas = items.map((i) => {
        const nota = i.observaciones?.trim();
        return `${i.cantidad}x ${i.nombre}${nota ? ` (${nota})` : ''}`;
      });

      const ticket = [
        `=== ${coc.cocina_nombre ?? 'Cocina'} ===`,
        `Pedido #${pedido?.numero_pedido ?? '?'}`,
        `Tipo: ${pedido?.tipo ?? '—'}`,
        ...lineas,
        '---',
      ].join('\n');

      await this.database.consultar(
        `INSERT INTO impresion_cocina_jobs (sucursal_id, cocina_id, pedido_id, payload)
         VALUES ($1, $2, $3, $4::jsonb)`,
        [
          sucursalId,
          coc.cocina_id,
          pedidoId,
          JSON.stringify({ ticket, pedido_id: pedidoId }),
        ],
      );
    }

    void this.procesarCola();
  }

  private async procesarCola(): Promise<void> {
    if (this.procesando) return;
    this.procesando = true;
    try {
      const jobs = await this.database.consultar<{
        id: string;
        payload: { ticket?: string };
      }>(
        `SELECT id, payload FROM impresion_cocina_jobs
         WHERE estado = 'pendiente'
         ORDER BY created_at ASC
         LIMIT 5`,
      );

      for (const job of jobs) {
        try {
          await this.enviarTicket(job.payload?.ticket ?? '');
          await this.database.consultar(
            `UPDATE impresion_cocina_jobs SET estado = 'enviado' WHERE id = $1`,
            [job.id],
          );
        } catch (err) {
          this.logger.warn(`Job impresión ${job.id}: ${String(err)}`);
          await this.database.consultar(
            `UPDATE impresion_cocina_jobs SET estado = 'error' WHERE id = $1`,
            [job.id],
          );
        }
      }
    } finally {
      this.procesando = false;
    }
  }

  private enviarTicket(ticket: string): Promise<void> {
    const url =
      this.config.get<string>('FOODY_PRINTER_WS') ?? 'ws://127.0.0.1:8765';

    return new Promise((resolve, reject) => {
      const ws = new WebSocket(url);
      const timeout = setTimeout(() => {
        ws.terminate();
        reject(new Error('Timeout impresora'));
      }, 4000);

      ws.on('open', () => {
        ws.send(JSON.stringify({ ticket, cuerpo: ticket }));
      });

      ws.on('message', () => {
        clearTimeout(timeout);
        ws.close();
        resolve();
      });

      ws.on('error', (err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });
  }
}
