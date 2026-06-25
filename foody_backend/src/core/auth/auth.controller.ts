import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { LoginGoogleDto } from './dto/login-google.dto';
import { RegistroDomiciliarioDto } from './dto/registro-domiciliario.dto';
import { RegistroRestauranteDto } from './dto/registro-restaurante.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { UsuarioActivoGuard } from './guards/usuario-activo.guard';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from './jwt-payload';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto.email, dto.contrasena);
  }

  @Post('login-domiciliario')
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

  @Post('login-google')
  @RateLimitPublico(20, 60_000)
  loginGoogle(@Body() dto: LoginGoogleDto) {
    return this.authService.loginGoogle(dto.access_token);
  }

  @Get('perfil')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  perfil(@UsuarioActual() usuario: JwtPayload) {
    return this.authService.perfil(usuario);
  }

  @Post('registrar-fcm')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  registrarFcm(
    @UsuarioActual() usuario: JwtPayload,
    @Body() body: { fcm_token: string; plataforma?: string },
  ) {
    return this.authService.registrarFcm(
      usuario,
      body.fcm_token,
      body.plataforma,
    );
  }

  @Post('desactivar-fcm')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  desactivarFcm(
    @UsuarioActual() usuario: JwtPayload,
    @Body() body: { fcm_token?: string },
  ) {
    return this.authService.desactivarFcm(usuario, body.fcm_token);
  }
}
