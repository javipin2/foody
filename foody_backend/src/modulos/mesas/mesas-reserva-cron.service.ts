import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';

/** MES-016: libera mesas cuando expira `reserva_hasta`. */
@Injectable()
export class MesasReservaCronService implements OnModuleInit {
  private readonly logger = new Logger(MesasReservaCronService.name);
  private ejecutando = false;
  private readonly LOCK_MESAS_RESERVA_CRON = 9200006;

  constructor(
    private readonly database: DatabaseService,
    private readonly realtime: RealtimeBroadcastService,
  ) {}

  onModuleInit() {
    setInterval(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_MESAS_RESERVA_CRON,
          () => this.expirarReservas(),
        ),
      5 * 60_000,
    );
    setTimeout(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_MESAS_RESERVA_CRON,
          () => this.expirarReservas(),
        ),
      20_000,
    );
  }

  async expirarReservas(): Promise<number> {
    if (this.ejecutando) return 0;
    this.ejecutando = true;
    try {
      const filas = await this.database.consultar<{
        id: string;
        sucursal_id: string;
      }>(
        `UPDATE mesas
         SET estado_operativo = 'libre',
             reserva_cliente_nombre = NULL,
             reserva_cliente_telefono = NULL,
             reserva_hasta = NULL
         WHERE estado_operativo = 'reservada'
           AND reserva_hasta IS NOT NULL
           AND reserva_hasta < now()
           AND NOT EXISTS (
             SELECT 1 FROM pedidos p
             WHERE p.mesa_id = mesas.id
               AND p.estado NOT IN ('pagado', 'cancelado', 'rechazado')
           )
         RETURNING id, sucursal_id`,
      );

      const sucursales = new Set(filas.map((f) => f.sucursal_id));
      for (const sid of sucursales) {
        void this.realtime.mesasActualizadas(sid);
      }
      if (filas.length > 0) {
        this.logger.debug(`Reservas expiradas: ${filas.length} mesa(s)`);
      }
      return filas.length;
    } finally {
      this.ejecutando = false;
    }
  }
}
