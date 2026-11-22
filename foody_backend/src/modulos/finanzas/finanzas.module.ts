import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { FinanzasController } from './finanzas.controller';
import { FinanzasService } from './finanzas.service';

@Module({
  imports: [AuthModule],
  controllers: [FinanzasController],
  providers: [FinanzasService],
  exports: [FinanzasService],
})
export class FinanzasModule {}
