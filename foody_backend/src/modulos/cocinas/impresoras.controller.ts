import {
  Body,
  Controller,
  Delete,
  Get,
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
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CocinasService } from './cocinas.service';
import { ActualizarImpresoraDto, CrearImpresoraDto } from './dto/cocina.dto';

@Controller('impresoras')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('cocina')
export class ImpresorasController {
  constructor(
    private readonly cocinas: CocinasService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get(':sucursal_id')
  @Permisos('editar_productos')
  async listar(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
    @Query('cocina_id') cocinaId?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.cocinas.listarImpresoras(id, cocinaId);
  }

  @Post()
  @Permisos('editar_productos')
  async crear(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CrearImpresoraDto,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.cocinas.crearImpresora(dto);
  }

  @Patch(':id')
  @Permisos('editar_productos')
  async actualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarImpresoraDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.cocinas.actualizarImpresora(id, sid, dto);
  }

  @Delete(':id')
  @Permisos('editar_productos')
  async eliminar(
    @Param('id', ParseUUIDPipe) id: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.cocinas.eliminarImpresora(id, sid);
  }
}
