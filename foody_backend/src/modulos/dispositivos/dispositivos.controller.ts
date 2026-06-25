import { Body, Controller, Delete, Param, Post } from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { DispositivosService } from './dispositivos.service';

@Controller('dispositivos')
export class DispositivosController {
  constructor(private readonly dispositivosService: DispositivosService) {}

  @Post('registrar')
  @RateLimitPublico(30, 60_000)
  registrar(
    @Body()
    body: {
      device_id: string;
      fcm_token?: string;
      ciudad_id?: string;
      plataforma?: string;
    },
  ) {
    return this.dispositivosService.registrar(body);
  }

  @Delete('anonimizar/:device_id')
  @RateLimitPublico(10, 60_000)
  anonimizar(@Param('device_id') deviceId: string) {
    return this.dispositivosService.anonimizar(deviceId);
  }
}
