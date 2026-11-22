import {
  Body,
  Controller,
  Delete,
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
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarCostoFijoDto } from './dto/actualizar-costo-fijo.dto';
import { ActualizarEmpleadoDto } from './dto/actualizar-empleado.dto';
import { CrearCostoFijoDto } from './dto/crear-costo-fijo.dto';
import { CrearEmpleadoDto } from './dto/crear-empleado.dto';
import { CrearGastoManualDto } from './dto/crear-gasto-manual.dto';
import { PagarCostoFijoDto } from './dto/pagar-costo-fijo.dto';
import { PagarEmpleadoDto } from './dto/pagar-empleado.dto';
import { FinanzasService } from './finanzas.service';

@Controller('finanzas')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class FinanzasController {
  constructor(
    private readonly finanzasService: FinanzasService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  // --- Costos fijos ---

  @Get('costos-fijos/:sucursal_id')
  @Permisos('ver_finanzas')
  async listarCostosFijos(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Query('incluir_inactivos') incluirInactivos: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.finanzasService.listarCostosFijos(
      id,
      incluirInactivos === 'true' || incluirInactivos === '1',
    );
  }

  @Post('costos-fijos')
  @Permisos('gestionar_finanzas')
  async crearCostoFijo(
    @Body() dto: CrearCostoFijoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.finanzasService.crearCostoFijo({ ...dto, sucursal_id: id });
  }

  @Patch('costos-fijos/:id')
  @Permisos('gestionar_finanzas')
  async actualizarCostoFijo(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarCostoFijoDto,
    @Query('sucursal_id') sucursalId: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(
      usuario,
      sucursalId ?? usuario.sucursal_id,
    );
    return this.finanzasService.actualizarCostoFijo(id, sid, dto);
  }

  @Delete('costos-fijos/:id')
  @Permisos('gestionar_finanzas')
  async eliminarCostoFijo(
    @Param('id', ParseUUIDPipe) id: string,
    @Query('sucursal_id') sucursalId: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(
      usuario,
      sucursalId ?? usuario.sucursal_id,
    );
    return this.finanzasService.eliminarCostoFijo(id, sid);
  }

  @Post('costos-fijos/:id/pagar')
  @Permisos('gestionar_finanzas')
  async pagarCostoFijo(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PagarCostoFijoDto,
    @Query('sucursal_id') sucursalId: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(
      usuario,
      sucursalId ?? usuario.sucursal_id,
    );
    return this.finanzasService.pagarCostoFijo(id, sid, usuario.sub, dto);
  }

  // --- Empleados ---

  @Get('empleados/:sucursal_id')
  @Permisos('ver_finanzas')
  async listarEmpleados(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Query('incluir_inactivos') incluirInactivos: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.finanzasService.listarEmpleados(
      id,
      incluirInactivos === 'true' || incluirInactivos === '1',
    );
  }

  @Post('empleados')
  @Permisos('gestionar_finanzas')
  async crearEmpleado(
    @Body() dto: CrearEmpleadoDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.finanzasService.crearEmpleado({ ...dto, sucursal_id: id });
  }

  @Patch('empleados/:id')
  @Permisos('gestionar_finanzas')
  async actualizarEmpleado(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ActualizarEmpleadoDto,
    @Query('sucursal_id') sucursalId: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(
      usuario,
      sucursalId ?? usuario.sucursal_id,
    );
    return this.finanzasService.actualizarEmpleado(id, sid, dto);
  }

  @Post('empleados/:id/pagar')
  @Permisos('gestionar_finanzas')
  async pagarEmpleado(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PagarEmpleadoDto,
    @Query('sucursal_id') sucursalId: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const sid = await this.sucursalScope.resolverEscritura(
      usuario,
      sucursalId ?? usuario.sucursal_id,
    );
    return this.finanzasService.pagarEmpleado(id, sid, usuario.sub, dto);
  }

  // --- Libro de egresos ---

  @Get('resumen/:sucursal_id')
  @Permisos('ver_finanzas')
  async resumen(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.finanzasService.resumen(id);
  }

  @Get('gastos/:sucursal_id')
  @Permisos('ver_finanzas')
  async listarGastos(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Query('desde') desde: string | undefined,
    @Query('hasta') hasta: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.finanzasService.listarGastos(id, desde, hasta);
  }

  @Post('gastos')
  @Permisos('gestionar_finanzas')
  async crearGastoManual(
    @Body() dto: CrearGastoManualDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(
      usuario,
      dto.sucursal_id,
    );
    return this.finanzasService.crearGastoManual(
      { ...dto, sucursal_id: id },
      usuario.sub,
    );
  }
}
