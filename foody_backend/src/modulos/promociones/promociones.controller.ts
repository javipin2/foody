import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import {
  ActualizarPromocionDto,
  CrearPromocionDto,
  RegistrarVistaPromocionDto,
} from './dto/promocion.dto';
import { PromocionesService } from './promociones.service';

@Controller('promociones')
export class PromocionesController {
  constructor(private readonly promociones: PromocionesService) {}

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
  validarCodigo(
    @Query('sucursal_id') sucursalId: string,
    @Query('codigo') codigo: string,
    @Query('subtotal') subtotal: string,
  ) {
    return this.promociones.previewCodigo(
      sucursalId,
      codigo,
      Number(subtotal) || 0,
    );
  }

  @Post(':id/vista')
  @RateLimitPublico(60, 60_000)
  registrarVista(
    @Param('id') id: string,
    @Body() dto: RegistrarVistaPromocionDto,
  ) {
    return this.promociones.registrarVista(id, dto.device_id);
  }

  @Get('admin/:sucursal_id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  listarAdmin(@Param('sucursal_id') sucursalId: string) {
    return this.promociones.listarAdmin(sucursalId);
  }

  @Post()
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  crear(@Body() dto: CrearPromocionDto) {
    return this.promociones.crear(dto);
  }

  @Patch(':id')
  @UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
  @Permisos('editar_productos')
  actualizar(
    @Param('id') id: string,
    @Body() dto: ActualizarPromocionDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.promociones.actualizar(id, usuario.sucursal_id!, dto);
  }
}
