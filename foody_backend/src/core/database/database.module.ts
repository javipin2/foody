import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';
import { TransactionHooksService } from './transaction-hooks.service';

@Global()
@Module({
  providers: [DatabaseService, TransactionHooksService],
  exports: [DatabaseService, TransactionHooksService],
})
export class DatabaseModule {}
