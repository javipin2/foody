import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { CosteoModule } from '../costeo/costeo.module';
import { RealtimeModule } from '../../core/realtime/realtime.module';
import { CatalogoService } from './catalogo.service';
import { CatalogoDisponibilidadService } from './catalogo-disponibilidad.service';
import { BebidasController } from './bebidas.controller';
import { CombosController } from './combos.controller';
import { CategoriasController } from './categorias.controller';
import { ProductosController } from './productos.controller';
import { ToppingsController } from './toppings.controller';

@Module({
  imports: [AuthModule, CosteoModule, RealtimeModule],
  controllers: [
    CategoriasController,
    ProductosController,
    ToppingsController,
    BebidasController,
    CombosController,
  ],
  providers: [CatalogoService, CatalogoDisponibilidadService],
  exports: [CatalogoService, CatalogoDisponibilidadService],
})
export class CatalogoModule {}
