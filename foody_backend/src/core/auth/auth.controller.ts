import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { OmitirSuscripcionActiva } from '../../compartido/decoradores/omitir-suscripcion-activa.decorator';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { AuthService } from './auth.service';
import { DesactivarFcmDto, RegistrarFcmDto } from './dto/fcm.dto';
import { LoginDto } from './dto/login.dto';
import { LoginGoogleDto } from './dto/login-google.dto';
import { RegistroDomiciliarioDto } from './dto/registro-domiciliario.dto';
import { RegistroRestauranteDto } from './dto/registro-restaurante.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { SuscripcionActivaGuard } from './guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from './guards/usuario-activo.guard';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from './jwt-payload';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @RateLimitPublico(15, 60_000)
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto.email, dto.contrasena);
  }

  @Post('login-domiciliario')
  @RateLimitPublico(15, 60_000)
  loginDomiciliario(@Body() dto: LoginDto) {
    return this.authService.loginDomiciliarioIndependiente(
      dto.email,
      dto.contrasena,
    );
  }

  @Post('registro-domiciliario')
  @RateLimitPublico(10, 60_000)
  registroDomiciliario(@Body() dto: RegistroDomiciliarioDto) {
    return this.authService.registrarDomiciliarioIndependiente(dto);
  }

  @Post('registro-restaurante')
  @RateLimitPublico(5, 60_000)
  registroRestaurante(@Body() dto: RegistroRestauranteDto) {
    return this.authService.registrarRestaurante(dto);
  }

  /** Público — flag/cupo antispike (VIRAL). UI waitlist. */
  @Get('registro-estado')
  @RateLimitPublico(60, 60_000)
  registroEstado() {
    return this.authService.estadoRegistroRestaurante();
  }

  @Post('login-google')
  @RateLimitPublico(20, 60_000)
  loginGoogle(@Body() dto: LoginGoogleDto) {
    return this.authService.loginGoogle(dto.access_token);
  }

  /** Renueva JWT (mismo tv). Requiere sesión aún válida. */
  @Post('refresh')
  @OmitirSuscripcionActiva()
  @RateLimitPublico(30, 60_000)
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  refresh(@UsuarioActual() usuario: JwtPayload) {
    return this.authService.refresh(usuario);
  }

  /** Cierra sesión server-side (bump token_version). */
  @Post('logout')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard)
  logout(@UsuarioActual() usuario: JwtPayload) {
    return this.authService.logout(usuario);
  }

  @Get('perfil')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  perfil(@UsuarioActual() usuario: JwtPayload) {
    return this.authService.perfil(usuario);
  }

  /** Topics Realtime staff (HMAC). Opcional: ?sucursal_id= al cambiar sede. */
  @Get('realtime-canales')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  realtimeCanales(
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    return this.authService.realtimeCanales(usuario, sucursalId);
  }

  @Post('registrar-fcm')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  registrarFcm(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: RegistrarFcmDto,
  ) {
    return this.authService.registrarFcm(
      usuario,
      dto.fcm_token,
      dto.plataforma,
    );
  }

  @Post('desactivar-fcm')
  @OmitirSuscripcionActiva()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard)
  desactivarFcm(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: DesactivarFcmDto,
  ) {
    return this.authService.desactivarFcm(usuario, dto.fcm_token);
  }
}
