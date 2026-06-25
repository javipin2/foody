import { Controller, Get } from '@nestjs/common';
import { SaludService } from './salud.service';

@Controller('salud')
export class SaludController {
  constructor(private readonly saludService: SaludService) {}

  @Get()
  verificar() {
    return this.saludService.verificar();
  }
}
