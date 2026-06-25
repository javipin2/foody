import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
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
import { CambiarEstadoItemDto } from './dto/cocina.dto';

@Controller('cocina')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('cocina')
export class CocinaTicketsController {
  constructor(private readonly cocinas: CocinasService) {}

  @Get('cocinas')
  @Permisos('ver_cocina')
  listarCocinas(@UsuarioActual() usuario: JwtPayload) {
    return this.cocinas.listarCocinas(usuario.sucursal_id!);
  }

  @Get('tickets/:cocina_id')
  @Permisos('ver_cocina')
  tickets(
    @Param('cocina_id') cocinaId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.cocinas.listarTickets(cocinaId, usuario.sucursal_id!);
  }

  @Patch('items/:item_id/estado')
  @Permisos('ver_cocina')
  cambiarEstadoItem(
    @Param('item_id') itemId: string,
    @Body() dto: CambiarEstadoItemDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.cocinas.cambiarEstadoItem(
      itemId,
      usuario.sucursal_id!,
      dto.estado_cocina,
      usuario.sub ?? null,
      dto.motivo,
    );
  }

  @Patch('items/:item_id/observaciones')
  @Permisos('ver_cocina')
  actualizarObservaciones(
    @Param('item_id') itemId: string,
    @Body() body: { observaciones: string },
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.cocinas.actualizarObservacionesItem(
      itemId,
      usuario.sucursal_id!,
      body.observaciones ?? '',
    );
  }

  @Patch('items/:item_id/prioridad')
  @Permisos('ver_cocina')
  prioridad(
    @Param('item_id') itemId: string,
    @Body() body: { urgente: boolean },
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.cocinas.marcarPrioridadItem(
      itemId,
      usuario.sucursal_id!,
      body.urgente === true,
    );
  }
}
