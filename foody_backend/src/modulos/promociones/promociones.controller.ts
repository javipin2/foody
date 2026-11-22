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
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import {
  ActualizarPromocionDto,
  CrearPromocionDto,
  RegistrarVistaPromocionDto,
  ValidarCodigoPromocionDto,
} from './dto/promocion.dto';
import { PromocionesService } from './promociones.service';

@Controller('promociones')
export class PromocionesController {
  constructor(
    private readonly promociones: PromocionesService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  /** Cliente: historias activas de la sucursal. */
  @Get()
  @RateLimitPublico(120, 60_000)
  listarActivas(@Query('sucursal_id') sucursalId: string) {
    return this.promociones.listarActivas(sucursalId);
  }

  /** Cliente: historias por restaurante en una ciudad (P02). */
  @Get('ciudad/:slug/stories')
  @RateLimitPublico(120, 60_000)
  storiesCiudad(@Param('slug') slug: string) {
    return this.promociones.listarStoriesPorCiudad(slug);
  }

  /** Cliente: validar código promocional antes del checkout. */
  @Get('validar-codigo')
  @RateLimitPublico(60, 60_000)
  validarCodigo(@Query() dto: ValidarCodigoPromocionDto) {
    return this.promociones.previewCodigo(
      dto.sucursal_id,
      dto.codigo,
      dto.subtotal,
    );
  }

  @Post(':id/vista')
  @RateLimitPublico(60, 60_000)
  registrarVista(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RegistrarVistaPromocionDto,
  ) {
    return this.promociones.registrarVista(id, dto.device_id);
  }

  @Post()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  async crear(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CrearPromocionDto,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.promociones.crear(dto);
  }

  /** STOR-01: fuerza limpieza de estados expirados (+ Storage). Admin. */
  @Post('admin/limpiar-expiradas')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  limpiarExpiradas() {
    return this.promociones.limpiarExpiradas(7);
  }

  @Get('admin/:sucursal_id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  async listarAdmin(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.promociones.listarAdmin(id);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  actualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarPromocionDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.promociones.actualizar(id, usuario.sucursal_id!, dto);
  }

  @Delete(':id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  eliminar(
    @Param('id', ParseUUIDPipe) id: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.promociones.eliminar(id, usuario.sucursal_id!);
  }
}
