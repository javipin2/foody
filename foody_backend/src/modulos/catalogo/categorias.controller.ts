import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
  Get,
  Param,
  Patch,
  Post,
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
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CatalogoService } from './catalogo.service';
import { ActualizarCategoriaDto } from './dto/actualizar-categoria.dto';
import { CrearCategoriaDto } from './dto/crear-categoria.dto';

@Controller('categorias')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class CategoriasController {
  constructor(
    private readonly catalogo: CatalogoService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get(':sucursal_id')
  @Permisos('editar_productos')
  async listar(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
    return this.catalogo.listarCategorias(sucursalId);
  }

  @Post()
  @Permisos('editar_productos')
  async crear(@Body() dto: CrearCategoriaDto, @UsuarioActual() usuario: JwtPayload) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.catalogo.crearCategoria(dto);
  }

  @Patch(':id')
  @Permisos('editar_productos')
  async actualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarCategoriaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.actualizarCategoria(id, sid, dto);
  }

  @Delete(':id')
  @Permisos('editar_productos')
  async eliminar(@Param('id', ParseUUIDPipe) id: string, @UsuarioActual() usuario: JwtPayload) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.eliminarCategoria(id, sid);
  }

  @Post('sucursal/:destino_id/copiar-desde/:origen_id')
  @Permisos('editar_productos', 'gestionar_sucursales')
  async copiarDesde(
    @Param('destino_id', ParseUUIDPipe) destinoId: string,
    @Param('origen_id', ParseUUIDPipe) origenId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, destinoId);
    if (!this.sucursalScope.puedeVerInventarioHermanas(usuario)) {
      throw new ForbiddenException({
        error: 'COPIAR_MENU_REQUIERE_MULTI_SUCURSAL',
        message:
          'Copiar menú entre sedes requiere permiso corporativo (gestionar sucursales).',
      });
    }
    return this.catalogo.copiarMenuDesde(
      usuario.restaurante_id!,
      destinoId,
      origenId,
      usuario.sub,
    );
  }
}
