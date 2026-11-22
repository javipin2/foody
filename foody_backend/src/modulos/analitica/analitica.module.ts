import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { AnaliticaController } from './analitica.controller';
import { AnaliticaService } from './analitica.service';

@Module({
  imports: [AuthModule],
  controllers: [AnaliticaController],
  providers: [AnaliticaService],
  exports: [AnaliticaService],
})
export class AnaliticaModule {}
