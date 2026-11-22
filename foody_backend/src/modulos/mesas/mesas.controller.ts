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
  ParseUUIDPipe,
} from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { ActualizarMesaDto, CrearMesaDto } from './dto/crear-mesa.dto';
import { TransferirMesaDto } from './dto/transferir-mesa.dto';
import {
  ReservarMesaDto,
  SalioSinPagarDto,
  UnirMesasDto,
} from './dto/mesa-ops.dto';
import { AsignarTurnoMesasDto } from './dto/asignar-turno-mesas.dto';
import { MesasService } from './mesas.service';

@Controller('mesas')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class MesasController {
  constructor(
    private readonly mesasService: MesasService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Post('asignar-turno')
  @Permisos('gestionar_mesas')
  async asignarTurno(
    @Body() dto: AsignarTurnoMesasDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.mesasService.asignarTurno(dto);
  }

  @Post('transferir')
  @Permisos('gestionar_mesas', 'cobrar_pedido')
  async transferir(
    @Body() dto: TransferirMesaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.mesasService.transferir(dto, usuario.sub);
  }

  @Post(':id/reservar')
  @Permisos('gestionar_mesas')
  async reservar(
    @Param('id', ParseUUIDPipe) mesaId: string,
    @Body() dto: ReservarMesaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.mesasService.reservar(mesaId, dto.sucursal_id, dto);
  }

  @Post(':id/cancelar-reserva')
  @Permisos('gestionar_mesas')
  async cancelarReserva(
    @Param('id', ParseUUIDPipe) mesaId: string,
    @Query('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.mesasService.cancelarReserva(mesaId, id);
  }

  @Post('unir')
  @Permisos('gestionar_mesas')
  async unir(
    @Body() dto: UnirMesasDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.mesasService.unirMesas(
      dto.sucursal_id,
      dto.mesa_principal_id,
      dto.mesas_secundarias,
      usuario.sub,
    );
  }

  @Post(':id/salio-sin-pagar')
  @Permisos('gestionar_mesas', 'ver_caja')
  async salioSinPagar(
    @Param('id', ParseUUIDPipe) mesaId: string,
    @Body() dto: SalioSinPagarDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.mesasService.registrarSalidaSinPagar(
      mesaId,
      dto.sucursal_id,
      usuario.sub,
      dto,
      usuario.rol,
    );
  }

  @Get(':id/qr')
  @Permisos('gestionar_mesas')
  async qr(
    @Param('id', ParseUUIDPipe) mesaId: string,
    @Query('sucursal_id') sucursalId: string,
    @Query('base_url') baseUrl: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.mesasService.obtenerQr(mesaId, id, baseUrl);
  }

  @Get(':sucursal_id')
  @Permisos('gestionar_mesas', 'ver_mesas', 'ver_pedidos', 'crear_pedido')
  async listar(
    @Param('sucursal_id', ParseUUIDPipe) sucursalId: string,
    @Query('incluir_inactivas') incluirInactivas: string | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    return this.mesasService.listarConEstado(id, incluirInactivas === 'true');
  }

  @Post()
  @Permisos('gestionar_mesas')
  async crear(
    @Body() dto: CrearMesaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    await this.sucursalScope.validarEscritura(usuario, dto.sucursal_id);
    return this.mesasService.crear(dto, usuario.restaurante_id ?? undefined);
  }

  @Patch(':id')
  @Permisos('gestionar_mesas')
  async actualizar(
    @Param('id', ParseUUIDPipe) mesaId: string,
    @Query('sucursal_id') sucursalId: string,
    @Body() dto: ActualizarMesaDto,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.mesasService.actualizar(mesaId, id, dto);
  }

  @Delete(':id')
  @Permisos('gestionar_mesas')
  async desactivar(
    @Param('id', ParseUUIDPipe) mesaId: string,
    @Query('sucursal_id') sucursalId: string,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    const id = await this.sucursalScope.resolverEscritura(usuario, sucursalId);
    return this.mesasService.desactivar(mesaId, id);
  }
}
