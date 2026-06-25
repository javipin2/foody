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
import { ActualizarImpresoraDto, CrearImpresoraDto } from './dto/cocina.dto';

@Controller('impresoras')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('cocina')
export class ImpresorasController {
  constructor(private readonly cocinas: CocinasService) {}

  @Get(':sucursal_id')
  @Permisos('editar_productos')
  listar(
    @Param('sucursal_id') sucursalId: string,
    @Query('cocina_id') cocinaId?: string,
  ) {
    return this.cocinas.listarImpresoras(sucursalId, cocinaId);
  }

  @Post()
  @Permisos('editar_productos')
  crear(@Body() dto: CrearImpresoraDto) {
    return this.cocinas.crearImpresora(dto);
  }

  @Patch(':id')
  @Permisos('editar_productos')
  actualizar(
    @Param('id') id: string,
    @Body() dto: ActualizarImpresoraDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.cocinas.actualizarImpresora(id, usuario.sucursal_id!, dto);
  }

  @Delete(':id')
  @Permisos('editar_productos')
  eliminar(@Param('id') id: string, @UsuarioActual() usuario: JwtPayload) {
    return this.cocinas.eliminarImpresora(id, usuario.sucursal_id!);
  }
}
