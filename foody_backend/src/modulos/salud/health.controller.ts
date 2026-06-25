import { Controller, Get } from '@nestjs/common';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';

@Controller('health')
export class HealthController {
  constructor(private readonly realtimeService: RealtimeBroadcastService) {}

  @Get('realtime')
  async verificarRealtime() {
    return this.realtimeService.verificarConexion();
  }
}
