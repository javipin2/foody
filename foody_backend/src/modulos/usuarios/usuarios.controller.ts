import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import {
  CambiarEstadoUsuarioDto,
  CrearUsuarioDto,
} from './dto/crear-usuario.dto';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { UsuariosService } from './usuarios.service';

@Controller('usuarios')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class UsuariosController {
  constructor(
    private readonly usuariosService: UsuariosService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get()
  @Permisos('gestionar_usuarios')
  async listar(
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
    await this.sucursalScope.validarLecturaOperativa(usuario, id);
    return this.usuariosService.listarPorSucursal(id);
  }

  @Post()
  @Permisos('gestionar_usuarios')
  async crear(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CrearUsuarioDto,
  ) {
    await this.sucursalScope.assertPerteneceRestaurante(
      dto.sucursal_id,
      usuario.restaurante_id!,
    );
    if (
      !this.sucursalScope.esCorporativo(usuario) &&
      dto.sucursal_id !== usuario.sucursal_id
    ) {
      throw new ForbiddenException(
        'Solo puedes crear usuarios en tu sucursal asignada',
      );
    }
    return this.usuariosService.crear(dto);
  }

  @Patch(':id/estado')
  @Permisos('gestionar_usuarios')
  async cambiarEstado(
    @Param('id') usuarioId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CambiarEstadoUsuarioDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
    await this.sucursalScope.validarEscritura(usuario, id);
    return this.usuariosService.cambiarEstado(usuarioId, id, dto);
  }
}
