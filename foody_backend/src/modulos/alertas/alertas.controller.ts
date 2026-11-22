import {
  Controller,
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
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AlertasRiesgoService } from './alertas-riesgo.service';
import { AlertasService } from './alertas.service';

@Controller('alertas')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class AlertasController {
  constructor(
    private readonly alertasService: AlertasService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Post('evaluar/:sucursal_id')
  @Permisos('ver_alertas')
  async evaluar(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.alertasRiesgo.evaluarAlertasProgramadas(sid);
  }

  @Get(':sucursal_id')
  @Permisos('ver_alertas')
  async listar(
    @Param('sucursal_id') sucursalId: string,
    @Query('solo_pendientes') soloPendientes: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
    return this.alertasService.listar(
      sucursalId,
      soloPendientes !== 'false',
    );
  }

  @Patch(':id/revisar')
  @Permisos('ver_alertas')
  async revisar(
    @Param('id', ParseUUIDPipe) alertaId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(
      usuario,
      sucursalId,
    );
    return this.alertasService.revisar(alertaId, sid, usuario.sub);
  }
}
