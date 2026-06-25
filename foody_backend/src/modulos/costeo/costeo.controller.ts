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
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { CosteoService } from './costeo.service';
import { ActualizarSubrecetaDto } from './dto/actualizar-subreceta.dto';
import { CrearSubrecetaDto } from './dto/crear-subreceta.dto';

@Controller('costeo')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('costeo')
export class CosteoController {
  constructor(private readonly costeo: CosteoService) {}

  @Get('resumen/:sucursal_id')
  @Permisos('ver_inventario')
  resumen(@Param('sucursal_id') sucursalId: string) {
    return this.costeo.resumenSucursal(sucursalId);
  }

  @Get('subrecetas/detalle/:id')
  @Permisos('ver_inventario')
  subrecetaDetalle(
    @Param('id') recetaId: string,
    @Query('sucursal_id') sucursalId: string,
  ) {
    return this.costeo.obtenerSubrecetaDetalle(recetaId, sucursalId);
  }

  @Get('subrecetas/:sucursal_id')
  @Permisos('ver_inventario')
  subrecetas(@Param('sucursal_id') sucursalId: string) {
    return this.costeo.listarSubrecetas(sucursalId);
  }

  @Get('combos/:sucursal_id')
  @Permisos('ver_inventario')
  combos(@Param('sucursal_id') sucursalId: string) {
    return this.costeo.listarCombos(sucursalId);
  }

  @Post('recalcular/:sucursal_id')
  @Permisos('editar_inventario')
  recalcular(@Param('sucursal_id') sucursalId: string) {
    return this.costeo.recalcularSucursal(sucursalId);
  }

  @Get('productos/:id/impacto-stock')
  @Permisos('ver_inventario')
  impactoStock(
    @Param('id') productoId: string,
    @Query('sucursal_id') sucursalId: string,
    @Query('cantidad') cantidad?: string,
  ) {
    const cant = cantidad != null ? Math.max(1, Number(cantidad) || 1) : 1;
    return this.costeo.impactoStockProducto(productoId, sucursalId, cant);
  }

  @Post('productos/:id/recalcular')
  @Permisos('editar_inventario')
  recalcularProducto(
    @Param('id') productoId: string,
    @Query('sucursal_id') sucursalId: string,
  ) {
    return this.costeo.recalcularProductoPorId(productoId, sucursalId);
  }

  @Post('combos/:id/recalcular')
  @Permisos('editar_inventario')
  recalcularCombo(
    @Param('id') comboId: string,
    @Query('sucursal_id') sucursalId: string,
  ) {
    return this.costeo.recalcularComboPorId(comboId, sucursalId);
  }

  @Post('subrecetas')
  @Permisos('editar_inventario')
  crearSubreceta(@Body() dto: CrearSubrecetaDto) {
    return this.costeo.crearSubreceta(dto);
  }

  @Patch('subrecetas/:id')
  @Permisos('editar_inventario')
  actualizarSubreceta(
    @Param('id') recetaId: string,
    @Body() dto: ActualizarSubrecetaDto,
  ) {
    return this.costeo.actualizarSubreceta(recetaId, dto);
  }

  @Post('subrecetas/:id/recalcular')
  @Permisos('editar_inventario')
  recalcularSubreceta(
    @Param('id') recetaId: string,
    @Query('sucursal_id') sucursalId: string,
  ) {
    return this.costeo.recalcularSubrecetaPorId(recetaId, sucursalId);
  }
}
