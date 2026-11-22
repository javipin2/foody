import { Controller, Get, Query, Res, UseGuards } from '@nestjs/common';
import type { Response } from 'express';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { AnaliticaService } from './analitica.service';
import { FiltroAnaliticaDto } from './dto/filtro-analitica.dto';

@Controller('analitica')
@UseGuards(
  JwtAuthGuard,
  UsuarioActivoGuard,
  SuscripcionActivaGuard,
  PlanFeaturesGuard,
  RolGuard,
)
@RequiereModulo('analitica')
export class AnaliticaController {
  constructor(private readonly analiticaService: AnaliticaService) {}

  @Get('resumen')
  @Permisos('ver_analitica', 'ver_reportes')
  async resumen(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.resumen(sucursalId, periodo, anterior, filtros);
  }

  @Get('ventas')
  @Permisos('ver_analitica', 'ver_reportes')
  async ventas(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.ventas(
      sucursalId,
      periodo,
      filtros,
      anterior,
    );
  }

  @Get('productos')
  @Permisos('ver_analitica', 'ver_reportes')
  async productos(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.productos(
      sucursalId,
      periodo,
      filtros,
      anterior,
    );
  }

  @Get('cocinas')
  @Permisos('ver_analitica', 'ver_reportes')
  async cocinas(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.cocinas(
      sucursalId,
      periodo,
      filtros,
      anterior,
    );
  }

  @Get('inventario')
  @Permisos('ver_analitica', 'ver_reportes')
  async inventario(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.inventario(
      sucursalId,
      periodo,
      filtros,
      anterior,
    );
  }

  @Get('domiciliarios')
  @Permisos('ver_analitica', 'ver_reportes')
  async domiciliarios(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.domiciliarios(
      sucursalId,
      periodo,
      filtros,
      anterior,
    );
  }

  @Get('caja')
  @Permisos('ver_analitica', 'ver_reportes')
  async caja(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.caja(sucursalId, periodo, filtros, anterior);
  }

  @Get('rentabilidad')
  @Permisos('ver_finanzas')
  async rentabilidad(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.rentabilidad(
      sucursalId,
      periodo,
      filtros,
      anterior,
    );
  }

  @Get('riesgo')
  @Permisos('ver_analitica', 'ver_reportes')
  async riesgo(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    return this.analiticaService.riesgo(sucursalId, periodo, filtros, anterior);
  }

  @Get('pedidos-recientes')
  @Permisos('ver_analitica', 'ver_reportes')
  async pedidosRecientes(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    const { sucursalId, periodo, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    const limite = Math.min(Math.max(query.limite ?? 15, 1), 50);
    return this.analiticaService.pedidosRecientes(
      sucursalId,
      periodo,
      filtros,
      limite,
    );
  }

  @Get('export')
  @Permisos('ver_analitica', 'ver_reportes')
  async export(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
    @Res({ passthrough: false }) res: Response,
  ) {
    const { sucursalId, periodo, anterior, filtros } =
      await this.analiticaService.resolverContexto(usuario, query);
    const archivo = await this.analiticaService.exportarCsv(
      sucursalId,
      periodo,
      anterior,
      filtros,
    );
    res.setHeader('Content-Type', archivo.mime);
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${archivo.filename}"`,
    );
    res.end(archivo.buffer);
  }

  @Get('comparativa-sedes')
  @Permisos('ver_analitica', 'ver_reportes')
  async comparativaSedes(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: FiltroAnaliticaDto,
  ) {
    return this.analiticaService.comparativaSedesParaUsuario(usuario, query);
  }
}
