import { IsBoolean } from 'class-validator';

export class ConfigFiadoDomiciliarioDto {
  @IsBoolean()
  permitir!: boolean;
}

export class ConfigDomicilioCajaDto {
  @IsBoolean()
  ingresa!: boolean;
}
