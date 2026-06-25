import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { ActualizarHorarioDto } from './dto/actualizar-horario.dto';
import { CrearSucursalDto } from './dto/crear-sucursal.dto';
import { RestaurantesService } from './restaurantes.service';

@Controller('sucursales')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class SucursalesStaffController {
  constructor(private readonly restaurantes: RestaurantesService) {}

  @Get('mi-restaurante')
  @Permisos('gestionar_sucursales', 'ver_dashboard')
  listarMiRestaurante(@UsuarioActual() usuario: JwtPayload) {
    return this.restaurantes.listarSucursalesStaff(
      usuario.restaurante_id!,
      usuario.restaurante_id!,
    );
  }

  @Post()
  @Permisos('gestionar_sucursales')
  crear(@UsuarioActual() usuario: JwtPayload, @Body() dto: CrearSucursalDto) {
    return this.restaurantes.crearSucursal(
      usuario.restaurante_id!,
      usuario.restaurante_id!,
      dto,
    );
  }

  @Get(':sucursalId/horarios')
  @Permisos('gestionar_sucursales')
  listarHorarios(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursalId') sucursalId: string,
  ) {
    return this.restaurantes.listarHorarios(
      sucursalId,
      usuario.restaurante_id!,
    );
  }

  @Patch('horarios/:horarioId')
  @Permisos('gestionar_sucursales')
  actualizarHorario(
    @UsuarioActual() usuario: JwtPayload,
    @Param('horarioId') horarioId: string,
    @Body() dto: ActualizarHorarioDto,
  ) {
    return this.restaurantes.actualizarHorario(
      horarioId,
      usuario.restaurante_id!,
      dto,
    );
  }
}
