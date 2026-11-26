import {
  ForbiddenException,
  Body,
  Controller,
  Delete,
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
import { CambiarEstadoPedidoDto } from './dto/cambiar-estado-pedido.dto';
import { AplicarDescuentoDto } from './dto/aplicar-descuento.dto';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { AgregarItemsPedidoDto } from './dto/agregar-items-pedido.dto';
import { ReemplazarItemPedidoDto } from './dto/reemplazar-item-pedido.dto';
import {
  EliminarItemPedidoDto,
  RechazarPedidoMesaDto,
} from './dto/motivo-pedido.dto';
import { ActualizarItemPedidoDto } from './dto/actualizar-item-pedido.dto';
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { ActualizarComensalDto } from './dto/actualizar-comensal.dto';
import { AprobarPedidoMesaDto } from './dto/aprobar-pedido-mesa.dto';
import {
  ListarCerradosHoyQueryDto,
  ListarPedidosQueryDto,
} from './dto/listar-pedidos-query.dto';
import { PedidosService } from './pedidos.service';
import { CotizarReemplazoComboDto } from './dto/cotizar-reemplazo-combo.dto';
import { ResponderDecisionComboDto } from './dto/responder-decision-combo.dto';

@Controller('pedidos')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class PedidosController {
  constructor(
    private readonly pedidosService: PedidosService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get()
  @Permisos('ver_pedidos')
  async listar(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: ListarPedidosQueryDto,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      query.sucursal_id,
    );
    const paginar = query.page != null;
    return this.pedidosService.listarPorSucursal(id, {
      soloActivos: query.solo_activos !== false,
      paginar,
      page: paginar ? query.page : undefined,
      limite: query.limit,
      meseraId: query.mesera_id,
      busqueda: query.q,
    });
  }

  @Get('cerrados-hoy')
  @Permisos('ver_pedidos')
  async listarCerradosHoy(
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: ListarCerradosHoyQueryDto,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      query.sucursal_id,
    );
    const paginar = query.page != null;
    return this.pedidosService.listarCerradosHoy(id, {
      meseraId: query.mesera_id,
      paginar,
      page: paginar ? query.page : undefined,
      limite: query.limit,
    });
  }

  @Get(':id/detalle')
  @Permisos('ver_pedidos')
  async detalle(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.pedidosService.obtenerDetalleAdmin(pedidoId, id);
  }

  @Get(':id/combo-decisiones-pendientes')
  @Permisos('ver_pedidos')
  async listarDecisionesComboPendientes(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.pedidosService.listarDecisionesComboPendientes(pedidoId, id);
  }

  @Post(':id/combo-decisiones/:decisionId/cotizacion')
  @Permisos('crear_pedido')
  async cotizarReemplazoCombo(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Param('decisionId', ParseUUIDPipe) decisionId: string,
    @Body() dto: CotizarReemplazoComboDto,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.cotizarReemplazoCombo(
      pedidoId,
      decisionId,
      id,
      dto.reemplazo_id,
      usuario.sub,
    );
  }

  @Patch(':id/combo-decisiones/:decisionId/respuesta')
  @Permisos('crear_pedido')
  async responderDecisionCombo(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Param('decisionId', ParseUUIDPipe) decisionId: string,
    @Body() dto: ResponderDecisionComboDto,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.responderDecisionCombo(
      pedidoId,
      decisionId,
      id,
      usuario.sub,
      dto,
    );
  }

  @Get('mesa/:mesaId')
  @Permisos('ver_pedidos')
  async listarPorMesa(
    @Param('mesaId', ParseUUIDPipe) mesaId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.pedidosService.listarActivosPorMesa(id, mesaId);
  }

  @Post('mesa/:mesaId/cobrar')
  @Permisos('cobrar_pedido')
  async cobrarMesa(
    @Param('mesaId', ParseUUIDPipe) mesaId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CobrarMesaDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.cobrarCuentaMesa(
      id,
      mesaId,
      usuario.sub,
      dto,
      usuario.rol,
    );
  }

  @Post('staff')
  @HttpCode(HttpStatus.CREATED)
  @Permisos('crear_pedido')
  async crearStaff(
    @Body() dto: CrearPedidoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    if (dto.pagos?.length && !usuario.permisos.includes('cobrar_pedido')) {
      throw new ForbiddenException('No tienes permiso para cobrar pedidos');
    }
    return this.pedidosService.crearStaff(usuario, dto);
  }

  @Post(':id/items')
  @Permisos('crear_pedido')
  async agregarItems(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Body() dto: AgregarItemsPedidoDto,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.agregarItems(pedidoId, id, dto, {
      creadoPorStaff: true,
      usuarioId: usuario.sub,
      rol: usuario.rol,
    });
  }

  @Post(':id/items/:itemId/reemplazar')
  @Permisos('crear_pedido')
  async reemplazarItem(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: ReemplazarItemPedidoDto,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.reemplazarItemPedido(
      pedidoId,
      itemId,
      id,
      usuario.sub,
      dto,
      { creadoPorStaff: true, usuarioId: usuario.sub, rol: usuario.rol },
    );
  }

  @Patch(':id/items/:itemId')
  @Permisos('crear_pedido')
  async actualizarItem(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: ActualizarItemPedidoDto,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.actualizarItemPedido(
      pedidoId,
      itemId,
      id,
      usuario.sub,
      dto,
    );
  }

  @Delete(':id/items/:itemId')
  @Permisos('crear_pedido')
  async eliminarItem(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() body: EliminarItemPedidoDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.eliminarItemPedido(
      pedidoId,
      itemId,
      id,
      usuario.sub,
      body.motivo,
    );
  }

  @Patch(':id/estado')
  @Permisos('crear_pedido')
  async cambiarEstado(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CambiarEstadoPedidoDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.cambiarEstado(
      pedidoId,
      id,
      usuario.sub,
      dto.estado,
      dto.motivo,
      { rol: usuario.rol, permisos: usuario.permisos ?? [] },
    );
  }

  @Post(':id/descuento')
  @Permisos('aplicar_descuento')
  async aplicarDescuento(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: AplicarDescuentoDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.aplicarDescuento(
      pedidoId,
      id,
      usuario.sub,
      dto,
      { rol: usuario.rol, permisos: usuario.permisos ?? [] },
    );
  }

  @Post(':id/cobrar')
  @Permisos('cobrar_pedido')
  async cobrarPedido(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CobrarMesaDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.cobrarPedidoCaja(
      pedidoId,
      id,
      usuario.sub,
      dto,
      usuario.rol,
    );
  }

  @Patch(':id/items/:itemId/comensal')
  @Permisos('crear_pedido', 'ver_pedidos')
  async actualizarComensal(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: ActualizarComensalDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.actualizarComensalItem(
      pedidoId,
      itemId,
      id,
      dto.comensal_etiqueta ?? null,
    );
  }

  @Patch(':id/aprobar')
  @Permisos('aprobar_pedido_mesa')
  async aprobar(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() body: AprobarPedidoMesaDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.aprobarMesa(pedidoId, id, usuario.sub, {
      meseraId: body?.mesera_id,
      rolLlamador: usuario.rol,
    });
  }

  @Patch(':id/rechazar')
  @Permisos('aprobar_pedido_mesa')
  async rechazar(
    @Param('id', ParseUUIDPipe) pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() body: RechazarPedidoMesaDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.rechazarMesa(
      pedidoId,
      id,
      usuario.sub,
      body.motivo ?? 'Rechazado por mesero',
    );
  }
}
