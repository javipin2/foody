import { Controller, Get, Param } from '@nestjs/common';
import { MenuService } from './menu.service';

@Controller('menu')
export class MenuController {
  constructor(private readonly menuService: MenuService) {}

  /** Público — menú + mesa identificada por QR */
  @Get('mesa/:qr_token')
  obtenerPorMesaQr(@Param('qr_token') qrToken: string) {
    return this.menuService.obtenerPorMesaQr(qrToken);
  }

  /** Público — menú completo de una sucursal */
  @Get(':sucursal_id')
  obtenerMenu(@Param('sucursal_id') sucursalId: string) {
    return this.menuService.obtenerPorSucursal(sucursalId);
  }
}
