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
import { AuditoriaService } from './auditoria.service';

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
  constructor(private readonly auditoria: AuditoriaService) {}

  @Get('timeline')
  @Permisos('ver_reportes')
  timeline(
    @UsuarioActual() usuario: JwtPayload,
    @Query('desde') desde: string,
    @Query('hasta') hasta: string,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const hoy = new Date().toISOString().slice(0, 10);
    return this.auditoria.timelineTurno({
      sucursal_id: sucursalId ?? usuario.sucursal_id!,
      desde: desde ?? hoy,
      hasta: hasta ?? hoy,
    });
  }
}
