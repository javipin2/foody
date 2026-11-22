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
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AuditoriaService } from './auditoria.service';
import { TimelineAuditoriaDto } from './dto/timeline-auditoria.dto';

@Controller('auditoria')
@UseGuards(
  JwtAuthGuard,
  UsuarioActivoGuard,
  SuscripcionActivaGuard,
  PlanFeaturesGuard,
  RolGuard,
)
@RequiereModulo('reportes')
export class AuditoriaController {
  constructor(
    private readonly auditoria: AuditoriaService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('timeline')
  @Permisos('ver_reportes')
  async timeline(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: TimelineAuditoriaDto,
  ) {
    const hoy = new Date().toISOString().slice(0, 10);
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      query.sucursal_id,
    );
    return this.auditoria.timelineTurno({
      sucursal_id: id,
      desde: query.desde ?? hoy,
      hasta: query.hasta ?? hoy,
    });
  }
}
