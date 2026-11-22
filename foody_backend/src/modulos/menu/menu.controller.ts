import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { RateLimitPublico } from '../../compartido/guards/rate-limit.guard';
import { MenuService } from './menu.service';

@Controller('menu')
export class MenuController {
  constructor(private readonly menuService: MenuService) {}

  /** Público — menú + mesa identificada por QR */
  @Get('mesa/:qr_token')
  @RateLimitPublico(90, 60_000)
  obtenerPorMesaQr(@Param('qr_token') qrToken: string) {
    return this.menuService.obtenerPorMesaQr(qrToken);
  }

  /** Público — menú completo de una sucursal */
  @Get(':sucursal_id')
  @RateLimitPublico(90, 60_000)
  obtenerMenu(@Param('sucursal_id', ParseUUIDPipe) sucursalId: string) {
    return this.menuService.obtenerPorSucursal(sucursalId);
  }
}
