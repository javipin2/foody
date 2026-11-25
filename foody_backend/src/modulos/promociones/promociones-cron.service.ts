import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { PromocionesService } from './promociones.service';
import { esQaSinEfectosExternos } from '../../core/config/qa-safety';

/** STOR-01: limpia estados expirados + Storage cada 6 h. */
@Injectable()
export class PromocionesCronService implements OnModuleInit {
  private readonly logger = new Logger(PromocionesCronService.name);
  private readonly LOCK_PROMOCIONES_CRON = 9200004;

  constructor(
    private readonly promociones: PromocionesService,
    private readonly database: DatabaseService,
  ) {}

  onModuleInit() {
    if (esQaSinEfectosExternos()) {
      this.logger.warn('Cron de promociones pausado por FOODY_QA_SIN_EFECTOS');
      return;
    }
    // Primera pasada a los 2 min (dejar arrancar Storage); luego cada 6 h.
    setTimeout(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_PROMOCIONES_CRON,
          () => this.ejecutar(),
        ),
      120_000,
    );
    setInterval(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_PROMOCIONES_CRON,
          () => this.ejecutar(),
        ),
      6 * 60 * 60 * 1000,
    );
  }

  async ejecutar() {
    try {
      const res = await this.promociones.limpiarExpiradas(7);
      if (res.filas > 0) {
        this.logger.log(
          `Cron estados: ${res.filas} filas, ${res.objetos_storage} objetos`,
        );
      }
    } catch (e) {
      this.logger.warn(
        `Cron estados falló: ${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }
}
