import {
  Body,
  Controller,
  Get,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { RequiereModulo } from '../../compartido/decoradores/requiere-modulo.decorator';
import { JwtPayload } from '../auth/jwt-payload';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolGuard } from '../auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../auth/guards/suscripcion-activa.guard';
import { PlanFeaturesGuard } from '../auth/guards/plan-features.guard';
import { UsuarioActivoGuard } from '../auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../auth/sucursal-scope.service';
import { ImpresionService } from './impresion.service';
import { ReimprimirComandaDto } from './dto/reimprimir.dto';

@Controller('impresion')
@UseGuards(
  JwtAuthGuard,
  UsuarioActivoGuard,
  SuscripcionActivaGuard,
  PlanFeaturesGuard,
  RolGuard,
)
@RequiereModulo('cocina')
export class ImpresionController {
  constructor(
    private readonly impresion: ImpresionService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Get('jobs')
  @Permisos('ver_cocina')
  async listarJobs(
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalId: string,
    @Query('limit') limit?: string,
  ) {
    const sid = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      sucursalId,
    );
    const datos = await this.impresion.listarJobs(
      sid,
      Math.min(Number(limit) || 20, 50),
    );
    return datos;
  }

  @Post('reimprimir')
  @Permisos('ver_cocina')
  async reimprimir(
    @UsuarioActual() usuario: JwtPayload,
    @Body() dto: ReimprimirComandaDto,
  ) {
    const sid = await this.sucursalScope.resolverLecturaOperativa(
      usuario,
      dto.sucursal_id,
    );
    return this.impresion.reimprimirPedido(dto.pedido_id, sid);
  }

  @Post('procesar-cola')
  @Permisos('ver_cocina')
  async procesarColaManual() {
    await this.impresion.procesarColaManual();
    return { procesado: true };
  }
}
