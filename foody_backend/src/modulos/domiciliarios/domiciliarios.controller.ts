import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { DomiciliarioIndependienteGuard } from '../../core/auth/guards/domiciliario-independiente.guard';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { DispatchService } from './dispatch.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import { DomiciliariosService } from './domiciliarios.service';
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import {
  IniciarSesionDto,
  ResponderOfertaDto,
  UbicacionDto,
} from './dto/independiente.dto';

@Controller('domiciliarios-planta')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('domiciliarios')
export class DomiciliariosPlantaController {
  constructor(
    private readonly domiciliariosService: DomiciliariosService,
    private readonly dispatchService: DispatchService,
  ) {}

  @Get('disponibles/:sucursal_id')
  @Permisos('gestionar_domiciliarios', 'ver_pedidos')
  listarDisponibles(@Param('sucursal_id') sucursalId: string) {
    return this.domiciliariosService.listarPlantaDisponibles(sucursalId);
  }

  @Post('asignar')
  @Permisos('gestionar_domiciliarios', 'ver_pedidos')
  asignar(
    @Body() dto: AsignarDomiciliarioDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.domiciliariosService.asignarPlanta(dto, usuario.sub);
  }

  @Post('dispatch-independiente/:pedido_id')
  @Permisos('gestionar_domiciliarios', 'ver_pedidos')
  dispatchIndependiente(
    @Param('pedido_id') pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = sucursalId ?? usuario.sucursal_id!;
    return this.dispatchService.iniciarBusquedaIndependientes(pedidoId, sid);
  }
}

@Controller('domiciliario')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('domiciliarios')
export class DomiciliarioPlantaController {
  constructor(private readonly domiciliariosService: DomiciliariosService) {}

  @Get('pedidos-asignados')
  @Permisos('ver_pedidos')
  pedidosAsignados(@UsuarioActual() usuario: JwtPayload) {
    return this.domiciliariosService.pedidosAsignados(usuario.sub);
  }

  @Patch('pedidos/:id/en-camino')
  @Permisos('ver_pedidos')
  enCamino(
    @Param('id') pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.domiciliariosService.marcarEnCamino(pedidoId, usuario.sub);
  }

  @Patch('pedidos/:id/confirmar-entrega')
  @Permisos('ver_pedidos')
  confirmarEntrega(
    @Param('id') pedidoId: string,
    @Body() dto: ConfirmarEntregaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.domiciliariosService.confirmarEntrega(pedidoId, usuario.sub, dto);
  }

  @Get('historial')
  @Permisos('ver_pedidos')
  historial(@UsuarioActual() usuario: JwtPayload) {
    return this.domiciliariosService.historialEntregas(usuario.sub);
  }

  @Get('estadisticas')
  @Permisos('ver_pedidos')
  estadisticas(@UsuarioActual() usuario: JwtPayload) {
    return this.domiciliariosService.estadisticasPlanta(usuario.sub);
  }
}

@Controller('domiciliarios')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, DomiciliarioIndependienteGuard, RolGuard)
export class DomiciliariosIndependientesController {
  constructor(
    private readonly independientesService: DomiciliariosIndependientesService,
  ) {}

  @Post('sesion/iniciar')
  @Permisos('domiciliario_independiente')
  iniciarSesion(
    @Body() dto: IniciarSesionDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.iniciarSesion(usuario.sub, dto);
  }

  @Post('sesion/ubicacion')
  @Permisos('domiciliario_independiente')
  ubicacion(
    @Body() dto: UbicacionDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.actualizarUbicacion(usuario.sub, dto);
  }

  @Post('sesion/cerrar')
  @Permisos('domiciliario_independiente')
  cerrarSesion(@UsuarioActual() usuario: JwtPayload) {
    return this.independientesService.cerrarSesion(usuario.sub);
  }

  @Get('ofertas-activas')
  @Permisos('domiciliario_independiente')
  ofertasActivas(@UsuarioActual() usuario: JwtPayload) {
    return this.independientesService.ofertasActivas(usuario.sub);
  }

  @Post('ofertas/:id/responder')
  @Permisos('domiciliario_independiente')
  responderOferta(
    @Param('id') ofertaId: string,
    @Body() dto: ResponderOfertaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.responderOferta(
      ofertaId,
      usuario.sub,
      dto,
    );
  }

  @Get('pedidos-activos')
  @Permisos('domiciliario_independiente')
  pedidosActivos(@UsuarioActual() usuario: JwtPayload) {
    return this.independientesService.pedidosActivos(usuario.sub);
  }

  @Patch('pedidos/:id/en-camino')
  @Permisos('domiciliario_independiente')
  enCamino(
    @Param('id') pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.marcarEnCamino(pedidoId, usuario.sub);
  }

  @Patch('pedidos/:id/confirmar-entrega')
  @Permisos('domiciliario_independiente')
  confirmarEntrega(
    @Param('id') pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.confirmarEntrega(pedidoId, usuario.sub);
  }

  @Get('ganancias')
  @Permisos('domiciliario_independiente')
  ganancias(@UsuarioActual() usuario: JwtPayload) {
    return this.independientesService.ganancias(usuario.sub);
  }
}
