import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
  ParseUUIDPipe,
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
  ActualizarUsuarioDto,
} from './dto/crear-usuario.dto';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { UsuariosService } from './usuarios.service';
import { ListarUsuariosQueryDto } from './dto/listar-usuarios-query.dto';

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
    @Query() query: ListarUsuariosQueryDto,
  ) {
    const id = this.sucursalScope.resolverSucursalId(usuario, query.sucursal_id);
    await this.sucursalScope.validarLecturaOperativa(usuario, id);
    return this.usuariosService.listarPorSucursal(id, query);
  }

  /** Meseros activos (picker de aprobación QR / asignación mesa). */
  @Get('meseros-activos')
  @Permisos('aprobar_pedido_mesa', 'ver_pedidos', 'gestionar_mesas')
  async meserosActivos(
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
    await this.sucursalScope.validarLecturaOperativa(usuario, id);
    return this.usuariosService.listarMeserosActivos(id);
  }

  @Get('catalogo-roles')
  @Permisos('gestionar_usuarios')
  catalogoRoles() {
    return this.usuariosService.catalogoRolesPermisos();
  }

  @Get(':id/permisos')
  @Permisos('gestionar_usuarios')
  async permisosUsuario(
    @Param('id', ParseUUIDPipe) usuarioId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
    await this.sucursalScope.validarLecturaOperativa(usuario, id);
    return this.usuariosService.permisosDeUsuario(usuarioId, id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @Permisos('gestionar_usuarios')
  async crear(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CrearUsuarioDto,
  ) {
    return this.usuariosService.crear(dto, usuario);
  }

  @Patch(':id/estado')
  @Permisos('gestionar_usuarios')
  async cambiarEstado(
    @Param('id', ParseUUIDPipe) usuarioId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CambiarEstadoUsuarioDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
    await this.sucursalScope.validarEscritura(usuario, id);
    return this.usuariosService.cambiarEstado(usuarioId, id, dto);
  }

  @Patch(':id')
  @Permisos('gestionar_usuarios')
  async actualizar(
    @Param('id', ParseUUIDPipe) usuarioId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: ActualizarUsuarioDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = this.sucursalScope.resolverSucursalId(usuario, sucursalId);
    await this.sucursalScope.validarEscritura(usuario, id);
    return this.usuariosService.actualizar(usuarioId, id, dto, usuario);
  }
}
