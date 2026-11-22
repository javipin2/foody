import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Put,
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
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';
import { CatalogoService } from './catalogo.service';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';
import { ConfigurarItemsIncluidosDto } from './dto/configurar-items-incluidos.dto';
import {
  CambiarDisponibilidadDto,
  ConfigurarToppingsDto,
  VincularBebidaDto,
  VincularToppingDto,
} from './dto/extras-mutacion.dto';

@Controller('productos')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class ProductosController {
  constructor(
    private readonly catalogo: CatalogoService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('sucursal/:sucursal_id')
  @Permisos('editar_productos')
  async listar(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query() pag: PaginacionQueryDto,
  ) {
    await this.sucursalScope.validarLecturaOperativa(usuario, sucursalId);
    return this.catalogo.listarProductos(sucursalId, pag);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @Permisos('editar_productos')
  async crear(@Body() dto: CrearProductoDto, @UsuarioActual() usuario: JwtPayload) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.catalogo.crearProducto(dto, usuario.restaurante_id ?? undefined);
  }

  @Patch(':id/disponibilidad')
  @Permisos('editar_productos')
  async disponibilidad(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: CambiarDisponibilidadDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.cambiarDisponibilidad(id, sid, body.disponible);
  }

  @Post(':id/toppings')
  @Permisos('editar_productos')
  async vincularTopping(
    @Param('id', ParseUUIDPipe) productoId: string,
    @Body() body: VincularToppingDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.vincularToppingProducto(
      productoId,
      body.topping_id,
      sid,
    );
  }

  @Get(':id/toppings')
  @Permisos('editar_productos')
  async listarToppings(
    @Param('id', ParseUUIDPipe) productoId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.listarToppingsProducto(productoId, sid);
  }

  @Put(':id/toppings')
  @Permisos('editar_productos')
  async configurarToppings(
    @Param('id', ParseUUIDPipe) productoId: string,
    @Body() body: ConfigurarToppingsDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.configurarToppingsProducto(
      productoId,
      sid,
      body.topping_ids ?? [],
    );
  }

  @Post(':id/bebidas')
  @Permisos('editar_productos')
  async vincularBebida(
    @Param('id', ParseUUIDPipe) productoId: string,
    @Body() body: VincularBebidaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.vincularBebidaProducto(
      productoId,
      body.bebida_id,
      sid,
    );
  }

  @Get(':id/items-incluidos')
  @Permisos('editar_productos')
  async listarItemsIncluidos(
    @Param('id', ParseUUIDPipe) id: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.listarItemsIncluidos(id, sid);
  }

  @Put(':id/items-incluidos')
  @Permisos('editar_productos')
  async configurarItemsIncluidos(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ConfigurarItemsIncluidosDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.configurarItemsIncluidos(id, sid, dto);
  }

  @Patch(':id')
  @Permisos('editar_productos')
  async actualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarProductoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(usuario);
    return this.catalogo.actualizarProducto(id, sid, dto);
  }
}
