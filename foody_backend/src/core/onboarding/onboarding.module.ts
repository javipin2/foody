import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { OnboardingRestauranteService } from './onboarding-restaurante.service';

@Module({
  imports: [DatabaseModule],
  providers: [OnboardingRestauranteService],
  exports: [OnboardingRestauranteService],
})
export class OnboardingModule {}
