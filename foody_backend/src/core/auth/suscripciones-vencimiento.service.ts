import { Injectable, Logger } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

/**
 * Marca suscripciones vencidas cuando fecha_vencimiento < hoy.
 * Se invoca de forma perezosa desde SuscripcionActivaGuard (sin cron externo).
 */
@Injectable()
export class SuscripcionesVencimientoService {
  private readonly logger = new Logger(SuscripcionesVencimientoService.name);

  constructor(private readonly database: DatabaseService) {}

  async asegurarEstadoVigente(restauranteId: string): Promise<string> {
    const fila = await this.database.consultarUno<{
      estado: string;
      plan: string;
      fecha_vencimiento: Date | null;
    }>(
      `SELECT estado, plan, fecha_vencimiento FROM suscripciones_restaurante
       WHERE restaurante_id = $1
       LIMIT 1`,
      [restauranteId],
    );

    if (!fila) return 'inactiva';
    if (fila.plan === 'gratis') return fila.estado;

    const vencidaPorFecha =
      fila.fecha_vencimiento != null &&
      new Date(fila.fecha_vencimiento).getTime() < Date.now();

    if (
      vencidaPorFecha &&
      ['activa', 'prueba'].includes(fila.estado)
    ) {
      await this.database.consultar(
        `UPDATE suscripciones_restaurante
         SET estado = 'vencida', updated_at = now()
         WHERE restaurante_id = $1`,
        [restauranteId],
      );
      this.logger.log(
        `Suscripción ${restauranteId} pasó a vencida por fecha_vencimiento`,
      );
      return 'vencida';
    }

    return fila.estado;
  }
}
