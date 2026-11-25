import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { esQaSinEfectosExternos } from '../../core/config/qa-safety';

const MAX_ALERTAS_POR_CICLO = 200;
const LOCK_COCINA_DEMORAS_CRON = 9200009;
const INTERVALO_EVALUACION_MS = 5 * 60_000;

/** Evalúa retrasos de cocina fuera del GET operativo del KDS. */
@Injectable()
export class CocinasDemorasCronService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(CocinasDemorasCronService.name);
  private ejecutando = false;
  private intervalo?: NodeJS.Timeout;
  private inicio?: NodeJS.Timeout;

  constructor(
    private readonly database: DatabaseService,
    private readonly alertas: AlertasRiesgoService,
  ) {}

  onModuleInit(): void {
    if (esQaSinEfectosExternos()) {
      this.logger.warn('Cron de demoras de cocina pausado por FOODY_QA_SIN_EFECTOS');
      return;
    }
    this.intervalo = setInterval(
      () => this.iniciarCiclo(),
      INTERVALO_EVALUACION_MS,
    );
    this.inicio = setTimeout(() => this.iniciarCiclo(), 15_000);
    this.intervalo.unref?.();
    this.inicio.unref?.();
  }

  onModuleDestroy(): void {
    if (this.intervalo) clearInterval(this.intervalo);
    if (this.inicio) clearTimeout(this.inicio);
  }

  private iniciarCiclo(): void {
    void this.database
      .intentarAdvisoryLock(LOCK_COCINA_DEMORAS_CRON, () => this.ejecutar())
      .catch((error: unknown) => {
        const detalle = error instanceof Error ? error.message : String(error);
        this.logger.warn(`No se evaluaron demoras de cocina: ${detalle}`);
      });
  }

  async ejecutar(): Promise<number> {
    if (this.ejecutando) return 0;
    this.ejecutando = true;
    try {
      const filas = await this.database.consultar<{
        pedido_id: string;
        sucursal_id: string;
        numero_pedido: string;
      }>(
        `SELECT p.id AS pedido_id, p.sucursal_id, p.numero_pedido
         FROM pedidos p
         WHERE p.estado IN ('confirmado', 'en_cocina', 'pagando', 'pagado')
           AND EXISTS (
             SELECT 1
             FROM pedido_items pi
             WHERE pi.pedido_id = p.id
               AND pi.estado_cocina IN ('pendiente', 'preparando')
               AND pi.created_at < now() - interval '20 minutes'
           )
           AND NOT EXISTS (
             SELECT 1
             FROM alertas_riesgo ar
             WHERE ar.sucursal_id = p.sucursal_id
               AND ar.tipo = 'demora_cocina'
               AND ar.referencia_id = p.id
               AND ar.revisada = false
           )
         ORDER BY p.created_at ASC
         LIMIT $1`,
        [MAX_ALERTAS_POR_CICLO],
      );
      if (!filas.length) return 0;
      return this.alertas.registrarVariasEnTransaccion(
        filas.map((fila) => ({
          sucursalId: fila.sucursal_id,
          tipo: 'demora_cocina',
          nivel: 'medio' as const,
          descripcion: `Pedido ${fila.numero_pedido} con ítems >20 min en cocina`,
          referenciaId: fila.pedido_id,
          referenciaTipo: 'pedido',
          deduplicar: true,
        })),
      );
    } finally {
      this.ejecutando = false;
    }
  }
}
