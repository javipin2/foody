import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AlmacenamientoController } from './almacenamiento.controller';
import { AlmacenamientoService } from './almacenamiento.service';

@Module({
  imports: [AuthModule],
  controllers: [AlmacenamientoController],
  providers: [AlmacenamientoService],
  exports: [AlmacenamientoService],
})
export class AlmacenamientoModule {}
