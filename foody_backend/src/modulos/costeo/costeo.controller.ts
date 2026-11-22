import {
  Body,
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
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CosteoService } from './costeo.service';
import { ActualizarSubrecetaDto } from './dto/actualizar-subreceta.dto';
import { CrearSubrecetaDto } from './dto/crear-subreceta.dto';
import { RegistrarProduccionDto } from './dto/registrar-produccion.dto';
import { FiltroPopularidadQueryDto } from './dto/filtro-popularidad.dto';
import { ImpactoStockQueryDto } from './dto/impacto-stock-query.dto';

@Controller('costeo')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('costeo')
export class CosteoController {
  constructor(
    private readonly costeo: CosteoService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('resumen/:sucursal_id')
  @Permisos('ver_inventario')
  async resumen(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.costeo.resumenSucursal(id);
  }

  @Get('subrecetas/detalle/:id')
  @Permisos('ver_inventario')
  async subrecetaDetalle(
    @UsuarioActual() usuario: JwtPayload,
    @Param('id', ParseUUIDPipe) recetaId: string,
    @Query('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.costeo.obtenerSubrecetaDetalle(recetaId, id);
  }

  @Get('subrecetas/:sucursal_id')
  @Permisos('ver_inventario')
  async subrecetas(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.costeo.listarSubrecetas(id);
  }

  @Get('combos/:sucursal_id')
  @Permisos('ver_inventario')
  async combos(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.costeo.listarCombos(id);
  }

  @Post('recalcular/:sucursal_id')
  @Permisos('editar_inventario')
  async recalcular(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.costeo.recalcularSucursal(id);
  }

  @Get('productos/:id/impacto-stock')
  @Permisos('ver_inventario')
  async impactoStock(
    @UsuarioActual() usuario: JwtPayload,
    @Param('id', ParseUUIDPipe) productoId: string,
    @Query() query: ImpactoStockQueryDto,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      query.sucursal_id,
    );
    const cant = query.cantidad ?? 1;
    const tipo = query.tipo_entidad ?? 'producto';
    return this.costeo.impactoStockProducto(productoId, id, cant, tipo);
  }

  @Post('productos/:id/recalcular')
  @Permisos('editar_inventario')
  async recalcularProducto(
    @UsuarioActual() usuario: JwtPayload,
    @Param('id', ParseUUIDPipe) productoId: string,
    @Query('sucursal_id') sucursalId: string,
    @Query('tipo_entidad') tipoEntidad?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    if (tipoEntidad === 'bebida' || tipoEntidad === 'topping') {
      return this.costeo.recalcularExtraPorId(tipoEntidad, productoId, id);
    }
    return this.costeo.recalcularProductoPorId(productoId, id);
  }

  @Post('combos/:id/recalcular')
  @Permisos('editar_inventario')
  async recalcularCombo(
    @UsuarioActual() usuario: JwtPayload,
    @Param('id', ParseUUIDPipe) comboId: string,
    @Query('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.costeo.recalcularComboPorId(comboId, id);
  }

  @Post('subrecetas')
  @Permisos('editar_inventario')
  async crearSubreceta(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CrearSubrecetaDto,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.costeo.crearSubreceta(dto);
  }

  @Patch('subrecetas/:id')
  @Permisos('editar_inventario')
  async actualizarSubreceta(
    @UsuarioActual() usuario: JwtPayload,
    @Param('id', ParseUUIDPipe) recetaId: string,
    @Body() dto: ActualizarSubrecetaDto,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.costeo.actualizarSubreceta(recetaId, dto);
  }

  @Post('subrecetas/:id/recalcular')
  @Permisos('editar_inventario')
  async recalcularSubreceta(
    @UsuarioActual() usuario: JwtPayload,
    @Param('id', ParseUUIDPipe) recetaId: string,
    @Query('sucursal_id') sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.costeo.recalcularSubrecetaPorId(recetaId, id);
  }

  @Get('popularidad/:sucursal_id')
  @Permisos('ver_inventario')
  async simuladorPopularidad(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
    @Query() query: FiltroPopularidadQueryDto,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.costeo.simuladorPopularidad(
      id,
      query.preset,
      query.desde,
      query.hasta,
    );
  }

  @Get('producciones/:sucursal_id')
  @Permisos('ver_inventario')
  async listarProducciones(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id') sucursalId: string,
    @Query('receta_id') recetaId?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.costeo.listarProducciones(id, recetaId);
  }

  @Post('producciones')
  @Permisos('editar_inventario')
  async registrarProduccion(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: RegistrarProduccionDto,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.costeo.registrarProduccion(dto, usuario.sub);
  }
}
