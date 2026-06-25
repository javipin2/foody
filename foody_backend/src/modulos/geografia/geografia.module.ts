import { Module } from '@nestjs/common';
import { GeografiaController } from './geografia.controller';
import { GeografiaService } from './geografia.service';

@Module({
  controllers: [GeografiaController],
  providers: [GeografiaService],
  exports: [GeografiaService],
})
export class GeografiaModule {}
