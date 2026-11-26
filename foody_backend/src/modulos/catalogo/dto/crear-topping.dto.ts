import { ArrayUnique, IsArray, IsOptional, IsUUID } from 'class-validator';
import { CrearExtraDto } from './crear-extra.dto';

export class CrearToppingDto extends CrearExtraDto {
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsUUID('4', { each: true })
  producto_ids?: string[];
}
