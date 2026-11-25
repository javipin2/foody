import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { SupabaseAuthService } from '../../core/auth/supabase-auth.service';
import { CancelarPedidoClienteDto } from './dto/cancelar-pedido-cliente.dto';
import { CalificarDomicilioClienteDto } from './dto/calificar-domicilio-cliente.dto';
import { LlamarMeseraClienteDto } from './dto/llamar-mesera-cliente.dto';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosService } from './pedidos.service';
import { DispositivosService } from '../dispositivos/dispositivos.service';

@Controller('pedidos')
export class PedidosPublicController {
  constructor(
    private readonly pedidosService: PedidosService,
    private readonly supabaseAuth: SupabaseAuthService,
    private readonly dispositivos: DispositivosService,
  ) {}

  private async verificarDevice(deviceId: string, capability?: string) {
    await this.dispositivos.exigirCapability(deviceId, capability);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @RateLimitPublico(40, 60_000)
  async crear(
    @Body() dto: CrearPedidoDto,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    await this.verificarDevice(dto.device_id, capability);
    return this.pedidosService.crear(dto);
  }

  /** Totales autoritativos (sin crear pedido). AQ-SOLID-06 / F4. */
  @Post('estimar')
  @RateLimitPublico(60, 60_000)
  async estimar(
    @Body() dto: CrearPedidoDto,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    await this.verificarDevice(dto.device_id, capability);
    return this.pedidosService.estimar(dto);
  }

  @Get('mios')
  @RateLimitPublico(60, 60_000)
  async listarMios(
    @Query('device_id') deviceId?: string,
    @Headers('authorization') authorization?: string,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    if (!deviceId?.trim()) {
      throw new BadRequestException('device_id es obligatorio');
    }
    await this.verificarDevice(deviceId.trim(), capability);
    let authUid: string | null = null;
    const bearer = authorization?.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
    if (bearer && this.supabaseAuth.estaConfigurado()) {
      try {
        const user = await this.supabaseAuth.usuarioDesdeAccessToken(bearer);
        authUid = user.id;
      } catch {
        // Token inválido: seguir solo por device_id (anónimo).
      }
    }
    return this.pedidosService.listarPorDevice(deviceId.trim(), authUid);
  }

  @Post(':id/cancelar')
  @RateLimitPublico(20, 60_000)
  async cancelar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelarPedidoClienteDto,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    await this.verificarDevice(dto.device_id.trim(), capability);
    return this.pedidosService.cancelarPorCliente(
      id,
      dto.device_id.trim(),
      dto.motivo.trim(),
    );
  }

  @Post(':id/llamar-mesera')
  @RateLimitPublico(15, 60_000)
  async llamarMesera(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: LlamarMeseraClienteDto,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    await this.verificarDevice(dto.device_id.trim(), capability);
    return this.pedidosService.llamarMesera(
      id,
      dto.device_id.trim(),
      dto.mensaje?.trim(),
    );
  }

  @Post(':id/calificar')
  @RateLimitPublico(20, 60_000)
  async calificar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CalificarDomicilioClienteDto,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    await this.verificarDevice(dto.device_id.trim(), capability);
    return this.pedidosService.calificarDomicilio(
      id,
      dto.device_id.trim(),
      dto.calificacion,
      dto.comentario?.trim(),
    );
  }

  @Get(':id/estado')
  @RateLimitPublico(120, 60_000)
  async estado(
    @Param('id', ParseUUIDPipe) id: string,
    @Query('device_id') deviceId?: string,
    @Query('token') seguimientoToken?: string,
    @Headers('x-foody-device-capability') capability?: string,
  ) {
    const capabilityValida =
      !!deviceId?.trim() &&
      !!capability &&
      (await this.dispositivos.verificarCapability(
        deviceId.trim(),
        capability,
      ));
    if (!capabilityValida && !seguimientoToken?.trim()) {
      throw new ForbiddenException({
        error: 'SEGUIMIENTO_NO_AUTORIZADO',
        message:
          'Se requiere una capability de dispositivo o token de seguimiento.',
      });
    }
    return this.pedidosService.obtenerEstadoPublico(id, {
      deviceId,
      seguimientoToken,
    });
  }
}
