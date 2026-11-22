import {
  Body,
  Controller,
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
import { CrearExtraDto } from './dto/crear-extra.dto';
import { ActualizarExtraDto } from './dto/extras-mutacion.dto';

@Controller('toppings')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class ToppingsController {
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
    return this.catalogo.listarToppings(sucursalId);
  }

  @Post()
  @Permisos('editar_productos')
  async crear(@Body() dto: CrearExtraDto, @UsuarioActual() usuario: JwtPayload) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.catalogo.crearTopping(dto);
  }

  @Patch(':id')
  @Permisos('editar_productos')
  async actualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: ActualizarExtraDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.actualizarTopping(id, sid, body);
  }
}
