import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
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
import { RetiroCajaDto } from './dto/retiro-caja.dto';
import { DevolucionCajaDto } from './dto/devolucion-caja.dto';

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
    @Param('sucursal_id') sucursalId: string,
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
  @Permisos('abrir_caja')
  async abrir(
    @Body() dto: AbrirCajaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
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
    await this.sucursalScope.resolverEscritura(usuario, usuario.sucursal_id);
    return this.cajaService.cerrar(dto, usuario.sub);
  }

  @Get('cuentas-por-cobrar/:sucursal_id')
  @Permisos('ver_caja')
  async listarFiados(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.cajaService.listarCuentasPorCobrar(id);
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
    @Param('id') id: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.cajaService.pagarCuentaPorCobrar(id, sucursalId, usuario.sub);
  }

  @Get(':caja_id/movimientos')
  @Permisos('ver_caja')
  async movimientos(
    @Param('caja_id') cajaId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      usuario.sucursal_id,
    );
    return this.cajaService.listarMovimientos(cajaId, sucursalId);
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
  async gasto(
    @Body() dto: GastoCajaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.cajaService.registrarGasto(dto, usuario.sub, sucursalId);
  }
}
