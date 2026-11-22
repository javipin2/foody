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
} from '@nestjs/common';
import {
  RateLimitPublico,
} from '../../compartido/guards/rate-limit.guard';
import { SupabaseAuthService } from '../../core/auth/supabase-auth.service';
import { CancelarPedidoClienteDto } from './dto/cancelar-pedido-cliente.dto';
import { CalificarDomicilioClienteDto } from './dto/calificar-domicilio-cliente.dto';
import { LlamarMeseraClienteDto } from './dto/llamar-mesera-cliente.dto';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosService } from './pedidos.service';

@Controller('pedidos')
export class PedidosPublicController {
  constructor(
    private readonly pedidosService: PedidosService,
    private readonly supabaseAuth: SupabaseAuthService,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @RateLimitPublico(40, 60_000)
  crear(@Body() dto: CrearPedidoDto) {
    return this.pedidosService.crear(dto);
  }

  /** Totales autoritativos (sin crear pedido). AQ-SOLID-06 / F4. */
  @Post('estimar')
  @RateLimitPublico(60, 60_000)
  estimar(@Body() dto: CrearPedidoDto) {
    return this.pedidosService.estimar(dto);
  }

  @Get('mios')
  @RateLimitPublico(60, 60_000)
  async listarMios(
    @Query('device_id') deviceId?: string,
    @Headers('authorization') authorization?: string,
  ) {
    if (!deviceId?.trim()) {
      throw new BadRequestException('device_id es obligatorio');
    }
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
  cancelar(@Param('id', ParseUUIDPipe) id: string, @Body() dto: CancelarPedidoClienteDto) {
    return this.pedidosService.cancelarPorCliente(
      id,
      dto.device_id.trim(),
      dto.motivo.trim(),
    );
  }

  @Post(':id/llamar-mesera')
  @RateLimitPublico(15, 60_000)
  llamarMesera(@Param('id', ParseUUIDPipe) id: string, @Body() dto: LlamarMeseraClienteDto) {
    return this.pedidosService.llamarMesera(
      id,
      dto.device_id.trim(),
      dto.mensaje?.trim(),
    );
  }

  @Post(':id/calificar')
  @RateLimitPublico(20, 60_000)
  calificar(@Param('id', ParseUUIDPipe) id: string, @Body() dto: CalificarDomicilioClienteDto) {
    return this.pedidosService.calificarDomicilio(
      id,
      dto.device_id.trim(),
      dto.calificacion,
      dto.comentario?.trim(),
    );
  }

  @Get(':id/estado')
  @RateLimitPublico(120, 60_000)
  estado(
    @Param('id', ParseUUIDPipe) id: string,
    @Query('device_id') deviceId?: string,
    @Query('token') seguimientoToken?: string,
  ) {
    return this.pedidosService.obtenerEstadoPublico(id, {
      deviceId,
      seguimientoToken,
    });
  }
}
