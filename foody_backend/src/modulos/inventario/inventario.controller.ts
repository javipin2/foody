import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
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
import { ActualizarIngredienteDto } from './dto/actualizar-ingrediente.dto';
import { ConfigurarRecetaProductoDto } from './dto/configurar-receta-producto.dto';
import { CrearIngredienteDto } from './dto/crear-ingrediente.dto';
import { CerrarConteoDto } from './dto/cerrar-conteo.dto';
import { RegistrarCompraDto } from './dto/registrar-compra.dto';
import { CrearTrasladoDto } from './dto/crear-traslado.dto';
import { InventarioService } from './inventario.service';
import { PaginacionQueryDto } from '../../compartido/dto/paginacion.dto';

@Controller('inventario')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, PlanFeaturesGuard, RolGuard)
@RequiereModulo('inventario')
export class InventarioController {
  constructor(
    private readonly inventario: InventarioService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('traslados')
  @Permisos('ver_inventario')
  async traslados(
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId?: string,
  ) {
    const sid = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.inventario.listarTraslados(usuario.restaurante_id!, sid);
  }

  @Post('traslados')
  @Permisos('editar_inventario')
  async crearTraslado(
    @Body() dto: CrearTrasladoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.resolverEscritura(usuario, dto.sucursal_origen_id);
    return this.inventario.crearTraslado(usuario, dto);
  }

  @Post('traslados/:id/recibir')
  @Permisos('editar_inventario')
  async recibirTraslado(
    @Param('id', ParseUUIDPipe) id: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.inventario.recibirTraslado(
      id,
      usuario.restaurante_id!,
      sucursalId,
      usuario.sub,
    );
  }

  @Post('traslados/:id/cancelar')
  @Permisos('editar_inventario')
  async cancelarTraslado(
    @Param('id', ParseUUIDPipe) id: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.inventario.cancelarTraslado(id, usuario, sucursalId);
  }

  @Get('hermanas/resumen')
  @Permisos('ver_inventario')
  async resumenHermanas(@UsuarioActual() usuario: JwtPayload) {
    return this.inventario.resumenInventarioHermanas(usuario);
  }

  @Post('conteos/iniciar/:sucursal_id')
  @Permisos('editar_inventario')
  async iniciarConteo(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.inventario.iniciarConteo(id, usuario.sub);
  }

  @Post('conteos/:conteo_id/cerrar')
  @Permisos('editar_inventario')
  async cerrarConteo(
    @Param('conteo_id', ParseUUIDPipe) conteoId: string,
    @Body() dto: CerrarConteoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.inventario.cerrarConteo(conteoId, id, usuario.sub, dto);
  }

  @Get('movimientos/:sucursal_id')
  @Permisos('ver_inventario')
  async movimientos(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    const paginar = page != null && page !== '';
    return this.inventario.listarMovimientos(id, {
      paginar,
      page: paginar ? Number(page) : undefined,
      limite: limit != null ? Number(limit) : undefined,
    });
  }

  @Get('costos/:sucursal_id')
  @Permisos('ver_inventario')
  async costos(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.inventario.listarCostosProductos(id);
  }

  @Get('producto-ingredientes/:producto_id')
  @Permisos('ver_inventario', 'editar_inventario')
  async recetaProducto(
    @Param('producto_id') productoId: string,
    @Query('tipo_entidad') tipoEntidad: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      usuario.sucursal_id,
    );
    const tipo =
      tipoEntidad === 'bebida' || tipoEntidad === 'topping'
        ? tipoEntidad
        : 'producto';
    return this.inventario.recetaDeProducto(productoId, id, tipo);
  }

  @Post('producto-ingredientes')
  @Permisos('editar_inventario')
  async configurarReceta(
    @Body() dto: ConfigurarRecetaProductoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.inventario.configurarRecetaProducto(dto, id);
  }

  @Post('compras')
  @Permisos('editar_inventario')
  async compras(
    @Body() dto: RegistrarCompraDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.inventario.registrarCompra({ ...dto, sucursal_id: id }, usuario.sub);
  }

  @Get(':sucursal_id')
  @Permisos('ver_inventario')
  async listar(
    @Param('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
    @Query() pag: PaginacionQueryDto,
  ) {
    const id = await this.sucursalScope.resolverLecturaInventario(
      usuario,
      sucursalId,
    );
    return this.inventario.listarIngredientes(id, pag);
  }

  @Post()
  @Permisos('editar_inventario')
  async crear(
    @Body() dto: CrearIngredienteDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.inventario.crearIngrediente({ ...dto, sucursal_id: id }, usuario.restaurante_id ?? undefined);
  }

  @Patch(':id')
  @Permisos('editar_inventario')
  async actualizar(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarIngredienteDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      usuario.sucursal_id,
    );
    return this.inventario.actualizarIngrediente(
      id,
      sucursalId,
      usuario.sub,
      dto,
    );
  }
}
