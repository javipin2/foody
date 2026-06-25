import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
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
import { CrearComboDto } from './dto/crear-combo.dto';

@Controller('combos')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class CombosController {
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
    return this.catalogo.listarCombos(sucursalId);
  }

  @Post()
  @Permisos('editar_productos')
  async crear(@Body() dto: CrearComboDto, @UsuarioActual() usuario: JwtPayload) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.catalogo.crearCombo(dto);
  }

  @Patch(':id/disponibilidad')
  @Permisos('editar_productos')
  async disponibilidad(
    @Param('id') id: string,
    @Body() body: { disponible: boolean },
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.cambiarDisponibilidadCombo(id, sid, body.disponible);
  }
}
