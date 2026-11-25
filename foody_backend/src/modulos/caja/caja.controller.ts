import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { CajaService } from './caja.service';
import { AbrirCajaDto } from './dto/abrir-caja.dto';
import { CerrarCajaDto } from './dto/cerrar-caja.dto';
import { GastoCajaDto } from './dto/gasto-caja.dto';
import { CrearCuentaPorCobrarDto } from './dto/crear-cuenta-por-cobrar.dto';
import { PagarCuentaPorCobrarDto } from './dto/pagar-cuenta-por-cobrar.dto';
import { RetiroCajaDto } from './dto/retiro-caja.dto';
import { DevolucionCajaDto } from './dto/devolucion-caja.dto';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';

@Controller('caja')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class CajaController {
  constructor(
    private readonly cajaService: CajaService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('activa/:sucursal_id')
  @Permisos('ver_caja')
  async activa(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.cajaService.obtenerActiva(id, {
      ocultarSaldo: usuario.rol === 'cajero',
    });
  }

  @Post('abrir')
  @HttpCode(HttpStatus.CREATED)
  @Permisos('abrir_caja')
  async abrir(@Body() dto: AbrirCajaDto, @UsuarioActual() usuario: JwtPayload) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.cajaService.abrir({ ...dto, sucursal_id: id }, usuario.sub);
  }

  @Post('cerrar')
  @Permisos('cerrar_caja')
  async cerrar(
    @Body() dto: CerrarCajaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    // Scope real: sucursal de la caja (CajaService.cerrar → RBAC-TENANT-01)
    return this.cajaService.cerrar(dto, usuario);
  }

  @Get('cuentas-por-cobrar/:sucursal_id/resumen')
  @Permisos('ver_caja')
  async resumenFiados(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.cajaService.resumenCuentasPorCobrar(id);
  }

  @Get('cuentas-por-cobrar/:sucursal_id')
  @Permisos('ver_caja')
  async listarFiados(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Query('incluir_pagadas') incluirPagadas: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.cajaService.listarCuentasPorCobrar(
      id,
      incluirPagadas === 'true' || incluirPagadas === '1',
    );
  }

  @Post('cuentas-por-cobrar')
  @Permisos('ver_caja')
  async crearFiado(
    @Body() dto: CrearCuentaPorCobrarDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.cajaService.crearCuentaPorCobrar(
      { ...dto, sucursal_id: id },
      usuario.sub,
    );
  }

  @Patch('cuentas-por-cobrar/:id/pagar')
  @Permisos('ver_caja')
  async pagarFiado(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PagarCuentaPorCobrarDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.cajaService.pagarCuentaPorCobrar(
      id,
      sucursalId,
      usuario.sub,
      dto.metodo_pago ?? 'efectivo',
    );
  }

  @Get(':caja_id/movimientos')
  @Permisos('ver_caja')
  async movimientos(
    @Param('caja_id', ParseUUIDPipe) cajaId: string,
    @Query() query: PaginacionQueryDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      usuario.sucursal_id,
    );
    return this.cajaService.listarMovimientos(
      cajaId,
      sucursalId,
      query.page,
      query.limit,
    );
  }

  @Get('pedidos/:pedido_id/movimientos')
  @Permisos('ver_caja')
  async movimientosPedido(
    @Param('pedido_id', ParseUUIDPipe) pedidoId: string,
    @Query() query: PaginacionQueryDto,
    @Query('sucursal_id', new ParseUUIDPipe({ optional: true }))
    sucursalSolicitada: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalSolicitada ?? usuario.sucursal_id,
    );
    return this.cajaService.listarMovimientosPedido(
      pedidoId,
      sucursalId,
      query.page,
      query.limit,
    );
  }

  @Post('retiro-parcial')
  @Permisos('hacer_retiro_parcial')
  async retiro(
    @Body() dto: RetiroCajaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.cajaService.retiroParcial(dto, usuario.sub, sucursalId);
  }

  @Post('devolucion')
  @Permisos('ver_caja')
  async devolucion(
    @Body() dto: DevolucionCajaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.cajaService.registrarDevolucion(
      { ...dto, sucursal_id: sucursalId },
      usuario.sub,
    );
  }

  @Post('gastos')
  @Permisos('ver_caja')
  async gasto(@Body() dto: GastoCajaDto, @UsuarioActual() usuario: JwtPayload) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.cajaService.registrarGasto(dto, usuario.sub, sucursalId);
  }
}
