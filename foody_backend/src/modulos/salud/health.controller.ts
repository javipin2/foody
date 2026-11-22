import { Controller, Get } from '@nestjs/common';
import { ImpresionService } from '../../core/impresion/impresion.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { SaludService } from './salud.service';

/**
 * Healthcheck profundo (BD + realtime + impresión). Ligero: GET /salud.
 * Alias: GET /salud/completo. BN-MOD-03: paths duales intencionales.
 */
@Controller('health')
export class HealthController {
  constructor(
    private readonly saludService: SaludService,
    private readonly realtimeService: RealtimeBroadcastService,
    private readonly impresion: ImpresionService,
  ) {}

  /** Consolidado para monitoreo (UptimeRobot, load balancer, scripts). */
  @Get()
  verificarCompleto() {
    return this.saludService.verificarCompleto();
  }

  @Get('realtime')
  async verificarRealtime() {
    return this.realtimeService.verificarConexion();
  }

  @Get('impresion')
  async verificarImpresion() {
    const agente = await this.impresion.verificarAgente();
    const cola = await this.impresion.estadisticasCola();
    return {
      ...agente,
      cola,
      modo_sin_hardware:
        'Sin IP en impresora -> tickets en foody_python_printer/tickets/',
    };
  }
}
