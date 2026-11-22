import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class LlamarMeseraClienteDto {
  @IsString()
  @MinLength(1)
  device_id: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  mensaje?: string;
}
