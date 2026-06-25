import { Module } from '@nestjs/common';
import { AuthModule } from '../../core/auth/auth.module';
import { ReportesController } from './reportes.controller';
import { ReportesService } from './reportes.service';

@Module({
  imports: [AuthModule],
  controllers: [ReportesController],
  providers: [ReportesService],
})
export class ReportesModule {}
