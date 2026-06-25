import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Headers,
  Post,
  UseGuards,
} from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { CheckoutPlanDto } from './dto/checkout-plan.dto';
import { SincronizarPagoDto } from './dto/sincronizar-pago.dto';
import { PagosService } from './pagos.service';

@Controller('pagos')
export class PagosController {
  constructor(private readonly pagosService: PagosService) {}

  @Post('checkout')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  checkout(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CheckoutPlanDto,
  ) {
    return this.pagosService.crearCheckout(usuario, dto);
  }

  @Get('estado')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  estado(@UsuarioActual() usuario: JwtPayload) {
    if (!usuario.restaurante_id) {
      return { suscripcion: null, ultimo_pago: null };
    }
    return this.pagosService.estadoRestaurante(usuario.restaurante_id);
  }

  @Post('sincronizar')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  sincronizar(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: SincronizarPagoDto,
  ) {
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Sin restaurante asociado');
    }
    return this.pagosService.sincronizarPago(usuario.restaurante_id, dto);
  }

  @Post('webhook-wompi')
  @RateLimitPublico(120, 60_000)
  webhookWompi(
    @Body() evento: Record<string, unknown>,
    @Headers('x-event-checksum') checksum?: string,
  ) {
    return this.pagosService.procesarWebhookWompi(evento, checksum);
  }
}
