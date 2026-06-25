import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { NotificacionesService } from './notificaciones.service';

/** Reintenta la cola FCM cada minuto si Firebase Admin no estaba listo. */
@Injectable()
export class NotificacionesCronService implements OnModuleInit {
  private readonly logger = new Logger(NotificacionesCronService.name);

  constructor(private readonly notificaciones: NotificacionesService) {}

  onModuleInit() {
    setInterval(() => void this.ejecutar(), 60_000);
  }

  async ejecutar() {
    const diag = await this.notificaciones.diagnostico();
    if (diag.pendientes === 0) return;
    const res = await this.notificaciones.procesarPendientes(30);
    if (res.procesadas > 0) {
      this.logger.debug(
        `Cola FCM: ${res.procesadas} procesadas, ${res.enviados} enviados (${res.modo})`,
      );
    }
  }
}
