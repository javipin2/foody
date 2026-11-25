import { GUARDS_METADATA } from '@nestjs/common/constants';
import { PERMISOS_KEY } from '../../compartido/decoradores/permisos.decorator';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuperAdminGuard } from '../../core/auth/guards/super-admin.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { NotificacionesController } from './notificaciones.controller';

describe('NotificacionesController procesar-cola', () => {
  it('reserva la cola global al super administrador de plataforma', () => {
    const guards = Reflect.getMetadata(
      GUARDS_METADATA,
      NotificacionesController.prototype.procesarCola,
    );

    expect(guards).toEqual([
      JwtAuthGuard,
      UsuarioActivoGuard,
      SuperAdminGuard,
    ]);
    expect(
      Reflect.getMetadata(
        PERMISOS_KEY,
        NotificacionesController.prototype.procesarCola,
      ),
    ).toBeUndefined();
  });

  it('limita la prueba web a sus tokens y exige permiso de rol', async () => {
    const permisos = Reflect.getMetadata(
      PERMISOS_KEY,
      NotificacionesController.prototype.pruebaWeb,
    );
    const guards = Reflect.getMetadata(
      GUARDS_METADATA,
      NotificacionesController.prototype.pruebaWeb,
    );
    expect(permisos).toEqual(['ver_dashboard']);
    expect(guards).toContain(RolGuard);

    const enviarPruebaWeb = jest.fn();
    const controller = new NotificacionesController({
      enviarPruebaWeb,
    } as never);
    await controller.pruebaWeb({
      sub: 'usuario-a',
      rol: 'admin',
    } as never);
    expect(enviarPruebaWeb).toHaveBeenCalledWith({
      usuario_id: 'usuario-a',
      rol: 'admin',
      todos_web: false,
    });
  });
});
