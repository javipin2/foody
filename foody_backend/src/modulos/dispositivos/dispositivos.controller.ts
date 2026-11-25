import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Headers,
  Param,
  Post,
  Query,
} from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { DispositivosService } from './dispositivos.service';
import {
  AnonimizarDispositivoDto,
  RegistrarDispositivoDto,
  VincularAuthDispositivoDto,
} from './dto/dispositivos.dto';

@Controller('dispositivos')
export class DispositivosController {
  constructor(private readonly dispositivosService: DispositivosService) {}

  @Post('registrar')
  @RateLimitPublico(30, 60_000)
  registrar(
    @Body() body: RegistrarDispositivoDto,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    if (!capability) {
      throw new ForbiddenException({
        error: 'DISPOSITIVO_NO_AUTORIZADO',
        message: 'No se pudo comprobar la posesión de este dispositivo.',
      });
    }
    return this.dispositivosService.registrar({
      ...body,
      device_capability: capability,
    });
  }

  /** Cliente Google: asocia auth_uid al device y reclama pedidos del device. */
  @Post('vincular-auth')
  @RateLimitPublico(20, 60_000)
  vincularAuth(
    @Body() body: VincularAuthDispositivoDto,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    if (!capability) {
      throw new ForbiddenException({
        error: 'DISPOSITIVO_NO_AUTORIZADO',
        message: 'No se pudo comprobar la posesión de este dispositivo.',
      });
    }
    return this.dispositivosService.vincularAuth(body, capability);
  }

  /**
   * GDPR anonimizar — RBAC-GUARD-01: exige posesión (FCM del device o session Supabase).
   * fcm_token por query/header (DELETE+body es frágil en clientes HTTP).
   */
  @Delete('anonimizar/:device_id')
  @RateLimitPublico(10, 60_000)
  async anonimizar(
    @Param('device_id') deviceId: string,
    @Query('fcm_token') fcmTokenQuery?: string,
    @Body() body: AnonimizarDispositivoDto = {},
    @Headers('authorization') authorization?: string,
    @Headers('x-foody-fcm-token') fcmHeader?: string,
  ) {
    const bearer =
      body.access_token?.trim() ||
      (authorization?.toLowerCase().startsWith('bearer ')
        ? authorization.slice(7).trim()
        : undefined);
    const fcm =
      fcmTokenQuery?.trim() || fcmHeader?.trim() || body.fcm_token?.trim();
    const ok = await this.dispositivosService.verificarPosesionParaAnonimizar(
      deviceId,
      { fcm_token: fcm, access_token: bearer },
    );
    if (!ok) {
      throw new ForbiddenException({
        error: 'DISPOSITIVO_NO_AUTORIZADO',
        message:
          'Debes probar posesión del dispositivo (fcm_token actual o sesión Google)',
      });
    }
    return this.dispositivosService.anonimizar(deviceId);
  }
}
