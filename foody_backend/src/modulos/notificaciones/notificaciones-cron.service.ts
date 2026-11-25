import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { NotificacionesService } from './notificaciones.service';
import { esQaSinEfectosExternos } from '../../core/config/qa-safety';

/** Reintenta la cola FCM cada minuto si Firebase Admin no estaba listo. */
@Injectable()
export class NotificacionesCronService implements OnModuleInit {
  private readonly logger = new Logger(NotificacionesCronService.name);
  private readonly LOCK_NOTIFICACIONES_CRON = 9200007;
  private readonly LOCK_PURGA_CRECIMIENTO = 9200008;
  private _ticks = 0;

  constructor(
    private readonly notificaciones: NotificacionesService,
    private readonly database: DatabaseService,
  ) {}

  onModuleInit() {
    if (esQaSinEfectosExternos()) {
      this.logger.warn('Cron de notificaciones pausado por FOODY_QA_SIN_EFECTOS');
      return;
    }
    setInterval(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_NOTIFICACIONES_CRON,
          () => this.ejecutar(),
        ),
      60_000,
    );
  }

  async ejecutar() {
    const diag = await this.notificaciones.diagnostico();
    if (diag.pendientes > 0) {
      const res = await this.notificaciones.procesarPendientes(30);
      if (res.procesadas > 0) {
        this.logger.debug(
          `Cola FCM: ${res.procesadas} procesadas, ${res.enviados} enviados (${res.modo})`,
        );
      }
    }

    // CAP-GROW: purga ~cada hora (60 ticks de 1 min).
    this._ticks += 1;
    if (this._ticks % 60 !== 0) return;
    await this.database.intentarAdvisoryLock(
      this.LOCK_PURGA_CRECIMIENTO,
      async () => {
        const r = await this.notificaciones.purgarHistorialCrecimiento();
        if (r.cola > 0 || r.auditoria > 0) {
          this.logger.log(
            `Purga crecimiento: cola=${r.cola} auditoria=${r.auditoria}`,
          );
        }
      },
    );
  }
}
