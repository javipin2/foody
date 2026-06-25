import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { ImpresionService } from './impresion.service';

@Module({
  imports: [DatabaseModule],
  providers: [ImpresionService],
  exports: [ImpresionService],
})
export class ImpresionModule {}
