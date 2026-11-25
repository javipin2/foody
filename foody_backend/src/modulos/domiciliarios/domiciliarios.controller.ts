import {
  Body,
  Controller,
  Get,
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
import { DomiciliarioIndependienteGuard } from '../../core/auth/guards/domiciliario-independiente.guard';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { PlanFeaturesGuard } from '../../core/auth/guards/plan-features.guard';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { DispatchService } from './dispatch.service';
import { DomiciliariosIndependientesService } from './domiciliarios-independientes.service';
import { DomiciliariosService } from './domiciliarios.service';
import { AsignarDomiciliarioDto } from './dto/asignar-domiciliario.dto';
import { ConfirmarEntregaDto } from './dto/confirmar-entrega.dto';
import {
  ConfigDomicilioCajaDto,
  ConfigFiadoDomiciliarioDto,
} from './dto/config-domicilio.dto';
import {
  IniciarSesionDto,
  ResponderOfertaDto,
  UbicacionEntregaDto,
} from './dto/independiente.dto';

@Controller('domiciliarios-planta')
@UseGuards(
  JwtAuthGuard,
  UsuarioActivoGuard,
  SuscripcionActivaGuard,
  PlanFeaturesGuard,
  RolGuard,
)
@RequiereModulo('domiciliarios')
export class DomiciliariosPlantaController {
  constructor(
    private readonly domiciliariosService: DomiciliariosService,
    private readonly dispatchService: DispatchService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('disponibles/:sucursal_id')
  @Permisos('gestionar_domiciliarios')
  async listarDisponibles(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.domiciliariosService.listarPlantaDisponibles(id);
  }

  @Get('comisiones-independientes/:sucursal_id')
  @Permisos('gestionar_domiciliarios')
  async resumenComisiones(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.domiciliariosService.resumenComisionesIndependientes(id);
  }

  @Get('liquidacion/:sucursal_id')
  @Permisos('gestionar_domiciliarios', 'ver_caja')
  async resumenLiquidacion(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.domiciliariosService.resumenLiquidacion(id);
  }

  @Post('liquidar/:domiciliario_planta_id')
  @Permisos('gestionar_domiciliarios', 'gestionar_caja')
  async liquidar(
    @Param('domiciliario_planta_id', ParseUUIDPipe)
    domiciliarioPlantaId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.domiciliariosService.liquidarDomiciliario(
      sid,
      domiciliarioPlantaId,
      usuario.sub,
    );
  }

  @Patch('config-fiado/:sucursal_id')
  @Permisos('gestionar_domiciliarios')
  async configurarFiado(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Body() body: ConfigFiadoDomiciliarioDto,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.domiciliariosService.configurarFiadoDomiciliario(
      id,
      body.permitir === true,
    );
  }

  @Get('domicilios/:sucursal_id')
  @Permisos('gestionar_domiciliarios', 'ver_caja')
  async resumenDomicilios(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Query('desde') desde?: string,
    @Query('hasta') hasta?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.domiciliariosService.resumenDomicilios(id, desde, hasta);
  }

  @Patch('config-domicilio-caja/:sucursal_id')
  @Permisos('gestionar_domiciliarios')
  async configurarDomicilioCaja(
    @UsuarioActual() usuario: JwtPayload,
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Body() body: ConfigDomicilioCajaDto,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.domiciliariosService.configurarDomicilioEnCaja(
      id,
      body.ingresa === true,
    );
  }

  @Post('asignar')
  @Permisos('gestionar_domiciliarios')
  async asignar(
    @Body() dto: AsignarDomiciliarioDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.domiciliariosService.asignarPlanta(dto, usuario.sub);
  }

  @Post('reasignar')
  @Permisos('gestionar_domiciliarios')
  async reasignar(
    @Body() dto: AsignarDomiciliarioDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.domiciliariosService.reasignarPlanta(dto, usuario.sub);
  }

  @Post('dispatch-independiente/:pedido_id')
  @Permisos('gestionar_domiciliarios')
  async dispatchIndependiente(
    @Param('pedido_id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.dispatchService.iniciarBusquedaIndependientes(pedidoId, sid);
  }
}

@Controller('domiciliario')
@UseGuards(
  JwtAuthGuard,
  UsuarioActivoGuard,
  SuscripcionActivaGuard,
  PlanFeaturesGuard,
  RolGuard,
)
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
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.domiciliariosService.marcarEnCamino(pedidoId, usuario.sub);
  }

  @Patch('pedidos/:id/confirmar-entrega')
  @Permisos('ver_pedidos')
  confirmarEntrega(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Body() dto: ConfirmarEntregaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.domiciliariosService.confirmarEntrega(
      pedidoId,
      usuario.sub,
      dto,
    );
  }

  @Post('ubicacion')
  @Permisos('ver_pedidos')
  ubicacion(
    @Body() dto: UbicacionEntregaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.domiciliariosService.registrarUbicacionEntrega(
      usuario.sub,
      dto,
    );
  }

  @Get('historial')
  @Permisos('ver_pedidos')
  historial(
    @UsuarioActual() usuario: JwtPayload,
    @Query('desde') desde?: string,
    @Query('hasta') hasta?: string,
  ) {
    return this.domiciliariosService.historialEntregas(usuario.sub, {
      desde,
      hasta,
    });
  }

  @Get('estadisticas')
  @Permisos('ver_pedidos')
  estadisticas(
    @UsuarioActual() usuario: JwtPayload,
    @Query('desde') desde?: string,
    @Query('hasta') hasta?: string,
  ) {
    return this.domiciliariosService.estadisticasPlanta(usuario.sub, {
      desde,
      hasta,
    });
  }
}

@Controller('domiciliarios')
@UseGuards(
  JwtAuthGuard,
  UsuarioActivoGuard,
  DomiciliarioIndependienteGuard,
  RolGuard,
)
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
    @Body() dto: UbicacionEntregaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.actualizarUbicacion(usuario.sub, dto);
  }

  @Post('sesion/cerrar')
  @Permisos('domiciliario_independiente')
  cerrarSesion(@UsuarioActual() usuario: JwtPayload) {
    return this.independientesService.cerrarSesion(usuario.sub);
  }

  @Get('sesion/estado')
  @Permisos('domiciliario_independiente')
  estadoSesion(@UsuarioActual() usuario: JwtPayload) {
    return this.independientesService.estadoSesion(usuario.sub);
  }

  @Get('ofertas-activas')
  @Permisos('domiciliario_independiente')
  ofertasActivas(@UsuarioActual() usuario: JwtPayload) {
    return this.independientesService.ofertasActivas(usuario.sub);
  }

  @Post('ofertas/:id/responder')
  @Permisos('domiciliario_independiente')
  responderOferta(
    @Param('id', ParseUUIDPipe) ofertaId: string,
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
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.marcarEnCamino(pedidoId, usuario.sub);
  }

  @Patch('pedidos/:id/confirmar-entrega')
  @Permisos('domiciliario_independiente')
  confirmarEntrega(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Body() dto: ConfirmarEntregaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    return this.independientesService.confirmarEntrega(
      pedidoId,
      usuario.sub,
      dto,
    );
  }

  @Get('ganancias')
  @Permisos('domiciliario_independiente')
  ganancias(
    @UsuarioActual() usuario: JwtPayload,
    @Query('desde') desde?: string,
    @Query('hasta') hasta?: string,
  ) {
    return this.independientesService.ganancias(usuario.sub, { desde, hasta });
  }
}
