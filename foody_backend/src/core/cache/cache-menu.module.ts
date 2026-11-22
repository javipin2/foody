import { Global, Module } from '@nestjs/common';
import { MenuCacheService } from './menu-cache.service';

@Global()
@Module({
  providers: [MenuCacheService],
  exports: [MenuCacheService],
})
export class CacheMenuModule {}
