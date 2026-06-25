import { Body, Controller, Get, Param, Post, Query, BadRequestException } from '@nestjs/common';
import {
  RateLimitPublico,
} from '../../compartido/guards/rate-limit.guard';
import { CrearPedidoDto } from './dto/crear-pedido.dto';
import { PedidosService } from './pedidos.service';

@Controller('pedidos')
export class PedidosPublicController {
  constructor(private readonly pedidosService: PedidosService) {}

  @Post()
  @RateLimitPublico(40, 60_000)
  crear(@Body() dto: CrearPedidoDto) {
    return this.pedidosService.crear(dto);
  }

  @Get('mios')
  @RateLimitPublico(60, 60_000)
  listarMios(@Query('device_id') deviceId?: string) {
    if (!deviceId?.trim()) {
      throw new BadRequestException('device_id es obligatorio');
    }
    return this.pedidosService.listarPorDevice(deviceId.trim());
  }

  @Get(':id/estado')
  @RateLimitPublico(120, 60_000)
  estado(@Param('id') id: string) {
    return this.pedidosService.obtenerEstadoPublico(id);
  }
}
