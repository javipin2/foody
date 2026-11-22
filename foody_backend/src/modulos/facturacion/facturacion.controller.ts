import {
  Body,
  Controller,
  Get,
  Param,
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
import { GuardarConfigFiscalDto } from './dto/guardar-config-fiscal.dto';
import { AnularFacturaDto } from './dto/anular-factura.dto';
import { FacturacionService } from './facturacion.service';

@Controller('facturacion')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('facturacion')
export class FacturacionController {
  constructor(
    private readonly facturacionService: FacturacionService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('config/:sucursal_id')
  @Permisos('ver_facturacion', 'gestionar_facturacion')
  async obtenerConfig(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
    return this.facturacionService.obtenerConfig(sucursalId);
  }

  @Post('config')
  @Permisos('gestionar_facturacion')
  async guardarConfig(
    @Body() dto: GuardarConfigFiscalDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.facturacionService.guardarConfig(dto);
  }

  @Get('facturas/:id/pdf')
  @Permisos('ver_facturacion', 'gestionar_facturacion')
  async pdf(
    @Param('id', ParseUUIDPipe) facturaId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.facturacionService.obtenerPdf(facturaId, sid);
  }

  @Get('facturas/:sucursal_id')
  @Permisos('ver_facturacion', 'gestionar_facturacion')
  async listarFacturas(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Query('estado') estado: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
    return this.facturacionService.listarFacturas(sucursalId, estado);
  }

  @Post('emitir/:pedido_id')
  @Permisos('gestionar_facturacion')
  async emitir(
    @Param('pedido_id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.facturacionService.emitir(pedidoId, sid);
  }

  @Post('anular/:factura_id')
  @Permisos('gestionar_facturacion')
  async anular(
    @Param('factura_id', ParseUUIDPipe) facturaId: string,
    @Body() body: AnularFacturaDto,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.facturacionService.anular(
      facturaId,
      sid,
      usuario.sub,
      body.motivo,
    );
  }
}
