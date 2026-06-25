import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuperAdminGuard } from '../../core/auth/guards/super-admin.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import {
  ActualizarCiudadDto,
  ActualizarConfiguracionDto,
  ActualizarDomiciliarioEstadoDto,
  ActualizarRestauranteDto,
  ActualizarSuscripcionDto,
  ActualizarUsuarioSuperDto,
  AprobarDocumentoDto,
  CambiarContrasenaSuperDto,
  CambiarEstadoUsuarioSuperDto,
  CrearCiudadDto,
  CrearRestauranteDto,
  CrearUsuarioSuperDto,
  RechazarDocumentoDto,
} from './dto/super-admin.dto';
import { SuperAdminService } from './super-admin.service';

@Controller('super')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuperAdminGuard)
export class SuperAdminController {
  constructor(private readonly superAdminService: SuperAdminService) {}

  @Get('resumen')
  resumen() {
    return this.superAdminService.resumenGlobal();
  }

  @Get('estadisticas')
  estadisticas() {
    return this.superAdminService.estadisticas();
  }

  @Get('ciudades')
  ciudades() {
    return this.superAdminService.listarCiudades();
  }

  @Post('ciudades')
  crearCiudad(@Body() dto: CrearCiudadDto) {
    return this.superAdminService.crearCiudad(dto);
  }

  @Patch('ciudades/:id')
  actualizarCiudad(@Param('id') id: string, @Body() dto: ActualizarCiudadDto) {
    return this.superAdminService.actualizarCiudad(id, dto);
  }

  @Get('restaurantes')
  restaurantes() {
    return this.superAdminService.listarRestaurantes();
  }

  @Post('restaurantes')
  crearRestaurante(@Body() dto: CrearRestauranteDto) {
    return this.superAdminService.crearRestaurante(dto);
  }

  @Patch('restaurantes/:id')
  actualizarRestaurante(
    @Param('id') id: string,
    @Body() dto: ActualizarRestauranteDto,
  ) {
    return this.superAdminService.actualizarRestaurante(id, dto);
  }

  @Get('restaurantes/:restauranteId/sucursales')
  sucursalesRestaurante(@Param('restauranteId') restauranteId: string) {
    return this.superAdminService.listarSucursalesRestaurante(restauranteId);
  }

  @Get('suscripciones')
  suscripciones() {
    return this.superAdminService.listarSuscripciones();
  }

  @Patch('suscripciones/:id')
  actualizarSuscripcion(
    @Param('id') id: string,
    @Body() dto: ActualizarSuscripcionDto,
  ) {
    return this.superAdminService.actualizarSuscripcion(id, dto);
  }

  @Get('usuarios')
  usuarios() {
    return this.superAdminService.listarUsuarios();
  }

  @Post('usuarios')
  crearUsuario(@Body() dto: CrearUsuarioSuperDto) {
    return this.superAdminService.crearUsuario(dto);
  }

  @Patch('usuarios/:id')
  actualizarUsuario(
    @Param('id') id: string,
    @Body() dto: ActualizarUsuarioSuperDto,
  ) {
    return this.superAdminService.actualizarUsuario(id, dto);
  }

  @Post('usuarios/:id/cambiar-contrasena')
  cambiarContrasena(
    @Param('id') id: string,
    @Body() dto: CambiarContrasenaSuperDto,
  ) {
    return this.superAdminService.cambiarContrasenaUsuario(id, dto);
  }

  @Patch('usuarios/:id/estado')
  usuarioEstado(
    @Param('id') id: string,
    @Body() dto: CambiarEstadoUsuarioSuperDto,
  ) {
    return this.superAdminService.cambiarEstadoUsuario(id, dto);
  }

  @Get('domiciliarios')
  domiciliarios() {
    return this.superAdminService.listarDomiciliarios();
  }

  @Patch('domiciliarios/:id/estado')
  domiciliarioEstado(
    @Param('id') id: string,
    @Body() dto: ActualizarDomiciliarioEstadoDto,
  ) {
    return this.superAdminService.actualizarEstadoDomiciliario(id, dto);
  }

  @Get('domiciliarios/documentos-pendientes')
  documentosPendientes() {
    return this.superAdminService.listarDocumentosPendientes();
  }

  @Post('domiciliarios/:id/aprobar-documento')
  aprobarDocumento(
    @Param('id') id: string,
    @Body() dto: AprobarDocumentoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.superAdminService.aprobarDocumento(id, dto, usuario.sub);
  }

  @Post('domiciliarios/:id/rechazar-documento')
  rechazarDocumento(
    @Param('id') id: string,
    @Body() dto: RechazarDocumentoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.superAdminService.rechazarDocumento(id, dto, usuario.sub);
  }

  @Get('configuracion')
  configuracion() {
    return this.superAdminService.listarConfiguracion();
  }

  @Patch('configuracion/:clave')
  actualizarConfiguracion(
    @Param('clave') clave: string,
    @Body() dto: ActualizarConfiguracionDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.superAdminService.actualizarConfiguracion(
      clave,
      dto,
      usuario.sub,
    );
  }
}
