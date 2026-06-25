import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
  BadRequestException,
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
import { CobrarMesaDto } from './dto/cobrar-mesa.dto';
import { ActualizarComensalDto } from './dto/actualizar-comensal.dto';
import { PedidosService } from './pedidos.service';

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
    @Query('sucursal_id') sucursalId?: string,
    @Query('solo_activos') soloActivos?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.pedidosService.listarPorSucursal(id, {
      soloActivos: soloActivos !== 'false',
    });
  }

  @Get('mesa/:mesaId')
  @Permisos('ver_pedidos')
  async listarPorMesa(
    @Param('mesaId') mesaId: string,
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
  @Permisos('ver_pedidos', 'crear_pedido')
  async cobrarMesa(
    @Param('mesaId') mesaId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: CobrarMesaDto,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.cobrarCuentaMesa(id, mesaId, usuario.sub, dto);
  }

  @Post('staff')
  @Permisos('crear_pedido')
  async crearStaff(
    @Body() dto: CrearPedidoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id ?? usuario.sucursal_id,
    );
    if (!sucursalId) {
      throw new BadRequestException('sucursal_id es obligatorio');
    }
    return this.pedidosService.crear(
      { ...dto, sucursal_id: sucursalId },
      { creadoPorStaff: true, usuarioId: usuario.sub, rol: usuario.rol },
    );
  }

  @Post(':id/items')
  @Permisos('crear_pedido')
  async agregarItems(
    @Param('id') pedidoId: string,
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

  @Delete(':id/items/:itemId')
  @Permisos('crear_pedido')
  async eliminarItem(
    @Param('id') pedidoId: string,
    @Param('itemId') itemId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() body: { motivo?: string },
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
  @Permisos('ver_pedidos')
  async cambiarEstado(
    @Param('id') pedidoId: string,
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
    @Param('id') pedidoId: string,
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
  @Permisos('crear_pedido', 'ver_pedidos')
  async cobrarPedido(
    @Param('id') pedidoId: string,
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
    );
  }

  @Patch(':id/items/:itemId/comensal')
  @Permisos('crear_pedido', 'ver_pedidos')
  async actualizarComensal(
    @Param('id') pedidoId: string,
    @Param('itemId') itemId: string,
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
    @Param('id') pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.pedidosService.aprobarMesa(pedidoId, id, usuario.sub);
  }

  @Patch(':id/rechazar')
  @Permisos('aprobar_pedido_mesa')
  async rechazar(
    @Param('id') pedidoId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Body() body: { motivo: string },
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
