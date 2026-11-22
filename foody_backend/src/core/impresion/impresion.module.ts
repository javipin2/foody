import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { AuthModule } from '../auth/auth.module';
import { ImpresionController } from './impresion.controller';
import { ImpresionService } from './impresion.service';

@Module({
  imports: [DatabaseModule, AuthModule],
  controllers: [ImpresionController],
  providers: [ImpresionService],
  exports: [ImpresionService],
})
export class ImpresionModule {}
