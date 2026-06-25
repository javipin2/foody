import {
  Body,
  Controller,
  Delete,
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
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { CocinasService } from './cocinas.service';
import { ActualizarCocinaDto, CrearCocinaDto } from './dto/cocina.dto';

@Controller('cocinas')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('cocina')
export class CocinasController {
  constructor(private readonly cocinas: CocinasService) {}

  @Get(':sucursal_id')
  @Permisos('editar_productos')
  listar(@Param('sucursal_id') sucursalId: string) {
    return this.cocinas.listarCocinas(sucursalId);
  }

  @Post()
  @Permisos('editar_productos')
  crear(@Body() dto: CrearCocinaDto) {
    return this.cocinas.crearCocina(dto);
  }

  @Patch(':id')
  @Permisos('editar_productos')
  actualizar(
    @Param('id') id: string,
    @Body() dto: ActualizarCocinaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.cocinas.actualizarCocina(id, usuario.sucursal_id!, dto);
  }

  @Delete(':id')
  @Permisos('editar_productos')
  eliminar(@Param('id') id: string, @UsuarioActual() usuario: JwtPayload) {
    return this.cocinas.eliminarCocina(id, usuario.sucursal_id!);
  }
}
