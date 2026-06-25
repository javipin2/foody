import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { FiltroReporteDto } from './dto/filtro-reporte.dto';
import { ReportesService } from './reportes.service';

@Controller('reportes')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('reportes')
export class ReportesController {
  constructor(private readonly reportesService: ReportesService) {}

  @Get('financiero')
  @Permisos('ver_reportes')
  financiero(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroReporteDto,
  ) {
    const id = query.sucursal_id ?? usuario.sucursal_id!;
    const rango = this.reportesService.resolverRango(query.desde, query.hasta);
    return this.reportesService.financiero(id, rango);
  }

  @Get('productos')
  @Permisos('ver_reportes')
  productos(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroReporteDto,
  ) {
    const id = query.sucursal_id ?? usuario.sucursal_id!;
    const rango = this.reportesService.resolverRango(query.desde, query.hasta);
    return this.reportesService.productos(id, rango);
  }

  @Get('pedidos')
  @Permisos('ver_reportes')
  pedidos(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroReporteDto,
  ) {
    const id = query.sucursal_id ?? usuario.sucursal_id!;
    const rango = this.reportesService.resolverRango(query.desde, query.hasta);
    return this.reportesService.pedidos(id, rango);
  }
}
