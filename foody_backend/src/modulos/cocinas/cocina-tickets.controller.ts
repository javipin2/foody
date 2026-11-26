import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
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
import {
  CambiarEstadoItemDto,
  FalloPreparacionDto,
  NoDisponibleTareaComboDto,
} from './dto/cocina.dto';
import {
  ActualizarObservacionesItemDto,
  PrioridadItemCocinaDto,
} from './dto/item-kds-mutacion.dto';

@Controller('cocina')
@UseGuards(
  JwtAuthGuard,
  UsuarioActivoGuard,
  SuscripcionActivaGuard,
  PlanFeaturesGuard,
  RolGuard,
)
@RequiereModulo('cocina')
export class CocinaTicketsController {
  constructor(private readonly cocinas: CocinasService) {}

  @Get('cocinas')
  @Permisos('ver_cocina')
  listarCocinas(@UsuarioActual() usuario: JwtPayload) {
    return this.cocinas.listarCocinasParaKds(usuario);
  }

  @Get('tickets/:cocina_id')
  @Permisos('ver_cocina')
  async tickets(
    @Param('cocina_id', ParseUUIDPipe) cocinaId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.cocinas.exigirAccesoCocinaKds(usuario, cocinaId);
    return this.cocinas.listarTickets(cocinaId, usuario.sucursal_id!);
  }

  @Patch('items/:item_id/estado')
  @Permisos('ver_cocina')
  async cambiarEstadoItem(
    @Param('item_id', ParseUUIDPipe) itemId: string,
    @Body() dto: CambiarEstadoItemDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.cocinas.exigirAccesoItemKds(usuario, itemId);
    return this.cocinas.cambiarEstadoItem(
      itemId,
      usuario.sucursal_id!,
      dto.estado_cocina,
      usuario.sub ?? null,
      dto.motivo,
    );
  }

  @Patch('combo-tareas/:tarea_id/estado')
  @Permisos('ver_cocina')
  async cambiarEstadoTareaCombo(
    @Param('tarea_id', ParseUUIDPipe) tareaId: string,
    @Body() dto: CambiarEstadoItemDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.cocinas.exigirAccesoTareaComboKds(usuario, tareaId);
    return this.cocinas.cambiarEstadoTareaCombo(
      tareaId,
      usuario.sucursal_id!,
      dto.estado_cocina,
      usuario.sub ?? null,
    );
  }

  @Patch('combo-tareas/:tarea_id/no-disponible')
  @Permisos('ver_cocina')
  async marcarTareaComboNoDisponible(
    @Param('tarea_id', ParseUUIDPipe) tareaId: string,
    @Body() dto: NoDisponibleTareaComboDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.cocinas.exigirAccesoTareaComboKds(usuario, tareaId);
    return this.cocinas.marcarTareaComboNoDisponible(
      tareaId,
      usuario.sucursal_id!,
      usuario.sub ?? null,
      dto.motivo,
    );
  }

  /** VIE-09 C: fallo de preparación (N/D + merma + alerta). */
  @Post('items/:item_id/fallo-preparacion')
  @Permisos('ver_cocina')
  async falloPreparacion(
    @Param('item_id', ParseUUIDPipe) itemId: string,
    @Body() dto: FalloPreparacionDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.cocinas.exigirAccesoItemKds(usuario, itemId);
    return this.cocinas.falloPreparacion(
      itemId,
      usuario.sucursal_id!,
      usuario.sub ?? null,
      dto.motivo,
    );
  }

  @Patch('items/:item_id/observaciones')
  @Permisos('ver_cocina')
  async actualizarObservaciones(
    @Param('item_id', ParseUUIDPipe) itemId: string,
    @Body() body: ActualizarObservacionesItemDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.cocinas.exigirAccesoItemKds(usuario, itemId);
    return this.cocinas.actualizarObservacionesItem(
      itemId,
      usuario.sucursal_id!,
      body.observaciones ?? '',
    );
  }

  @Patch('items/:item_id/prioridad')
  @Permisos('ver_cocina')
  async prioridad(
    @Param('item_id', ParseUUIDPipe) itemId: string,
    @Body() body: PrioridadItemCocinaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.cocinas.exigirAccesoItemKds(usuario, itemId);
    return this.cocinas.marcarPrioridadItem(
      itemId,
      usuario.sucursal_id!,
      body.urgente === true,
    );
  }
}
