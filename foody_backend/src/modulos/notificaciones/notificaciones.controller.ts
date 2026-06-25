import { Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { NotificacionesService } from './notificaciones.service';

@Controller('notificaciones')
export class NotificacionesController {
  constructor(private readonly notificaciones: NotificacionesService) {}

  @Get('diagnostico')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, RolGuard)
  @Permisos('ver_dashboard')
  diagnostico() {
    return this.notificaciones.diagnostico();
  }

  @Post('procesar-cola')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, RolGuard)
  @Permisos('ver_dashboard')
  procesarCola() {
    return this.notificaciones.procesarPendientes(100);
  }

  /** Push de prueba — cualquier usuario autenticado (staff o domiciliario). */
  @Post('prueba')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  prueba(@UsuarioActual() usuario: JwtPayload) {
    const base = {
      tipo: 'prueba_foody',
      titulo: 'Foody — prueba FCM',
      cuerpo: 'Si ves esto, push operativo ✅',
    };
    if (usuario.rol === 'domiciliario_independiente') {
      return this.notificaciones.enviar({
        ...base,
        destinatario_domiciliario_id: usuario.sub,
        datos: { ruta: '/domiciliario/independiente' },
      });
    }
    return this.notificaciones.enviar({
      ...base,
      destinatario_usuario_id: usuario.sub,
      datos: { ruta: '/admin/panel' },
    });
  }

  /** Push de prueba a navegadores con token web (Chrome). */
  @Post('prueba-web')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard)
  pruebaWeb(@UsuarioActual() usuario: JwtPayload) {
    return this.notificaciones.enviarPruebaWeb({
      usuario_id: usuario.sub,
      rol: usuario.rol,
      todos_web: true,
    });
  }
}
