import { Controller, Get } from '@nestjs/common';
import { SaludService } from './salud.service';

/**
 * Healthcheck ligero (BD). Monitoreo profundo: GET /health o GET /salud/completo.
 * BN-MOD-03: dos profundidades a propósito — no fusionar en un solo payload.
 */
@Controller('salud')
export class SaludController {
  constructor(private readonly saludService: SaludService) {}

  @Get()
  verificar() {
    return this.saludService.verificar();
  }

  /** Alias canónico bajo /salud del check profundo (mismo que GET /health). */
  @Get('completo')
  verificarCompleto() {
    return this.saludService.verificarCompleto();
  }
}
