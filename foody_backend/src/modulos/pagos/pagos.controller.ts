import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Header,
  Headers,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { OmitirSuscripcionActiva } from '../../compartido/decoradores/omitir-suscripcion-activa.decorator';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { RetornoAppQueryDto } from './dto/retorno-app-query.dto';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { CheckoutPlanDto } from './dto/checkout-plan.dto';
import { SincronizarPagoDto } from './dto/sincronizar-pago.dto';
import { PagosService } from './pagos.service';

@Controller('pagos')
export class PagosController {
  constructor(private readonly pagosService: PagosService) {}

  @Post('checkout')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  checkout(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CheckoutPlanDto,
  ) {
    return this.pagosService.crearCheckout(usuario, dto);
  }

  @Get('estado')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  estado(@UsuarioActual() usuario: JwtPayload) {
    if (!usuario.restaurante_id) {
      return { suscripcion: null, ultimo_pago: null };
    }
    return this.pagosService.estadoRestaurante(usuario.restaurante_id);
  }

  @Post('sincronizar')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  sincronizar(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: SincronizarPagoDto,
  ) {
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Sin restaurante asociado');
    }
    return this.pagosService.sincronizarPago(usuario.restaurante_id, dto);
  }

  @Post('renovar')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  renovar(@UsuarioActual() usuario: JwtPayload) {
    return this.pagosService.renovar(usuario);
  }

  /**
   * Bridge HTTPS (Wompi exige https) → intenta abrir la app (`foody://plan`)
   * y cae al panel web si no hay APK instalado.
   * Público: solo redirige; la activación del plan es webhook/sync firmado.
   */
  @Get('retorno-app')
  @RateLimitPublico(60, 60_000)
  @Header('Cache-Control', 'no-store')
  retornoApp(
    @Query() query: RetornoAppQueryDto,
    @Res() res: Response,
  ) {
    const html = this.pagosService.htmlRetornoApp(query.pago_id);
    res.status(200).type('html').send(html);
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
