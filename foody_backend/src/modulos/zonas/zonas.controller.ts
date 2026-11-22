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
import {
  ActualizarZonaDto,
  CotizarDomicilioDto,
  CrearZonaDto,
  UbicacionSucursalDto,
} from './dto/zona.dto';
import { ZonasService } from './zonas.service';

@Controller('zonas')
export class ZonasController {
  constructor(
    private readonly zonas: ZonasService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  /** Público: cotizar domicilio antes del checkout. */
  @Get('cotizar-domicilio')
  cotizar(@Query() dto: CotizarDomicilioDto) {
    return this.zonas.cotizarDomicilio(dto.sucursal_id, dto.lat, dto.lng);
  }

  @Get('sucursal/:sucursal_id/configuracion-mapa')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
  @RequiereModulo('zonas_domicilio')
  @Permisos('gestionar_sucursales', 'editar_productos')
  async configuracionMapa(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
    return this.zonas.configuracionMapa(sucursalId);
  }

  @Patch('sucursal/:sucursal_id/ubicacion')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
  @RequiereModulo('zonas_domicilio')
  @Permisos('gestionar_sucursales')
  async ubicacionSucursal(
    @Param('sucursal_id') sucursalId: string,
    @Body() dto: UbicacionSucursalDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.zonas.actualizarUbicacionSucursal(sid, dto.lat, dto.lng);
  }

  @Get(':sucursal_id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
  @RequiereModulo('zonas_domicilio')
  @Permisos('gestionar_sucursales', 'editar_productos')
  async listar(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
    return this.zonas.listar(sucursalId);
  }

  @Post()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
  @RequiereModulo('zonas_domicilio')
  @Permisos('gestionar_sucursales')
  async crear(@Body() dto: CrearZonaDto, @UsuarioActual() usuario: JwtPayload) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.zonas.crear(dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
  @RequiereModulo('zonas_domicilio')
  @Permisos('gestionar_sucursales')
  async actualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarZonaDto,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalIdQuery?: string,
  ) {
    const sid = sucursalIdQuery ?? (await this.zonas.obtenerSucursalIdDeZona(id));
    const sucursalId = await this.sucursalScope.resolverEscritura(usuario, sid);
    return this.zonas.actualizar(id, sucursalId, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
  @RequiereModulo('zonas_domicilio')
  @Permisos('gestionar_sucursales')
  async desactivar(
    @Param('id', ParseUUIDPipe) id: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalIdQuery?: string,
  ) {
    const sid = sucursalIdQuery ?? (await this.zonas.obtenerSucursalIdDeZona(id));
    const sucursalId = await this.sucursalScope.resolverEscritura(usuario, sid);
    return this.zonas.desactivar(id, sucursalId);
  }
}
