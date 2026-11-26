import {
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  MinLength,
} from 'class-validator';

export class CambiarDisponibilidadDto {
  @IsBoolean()
  disponible!: boolean;
}

export class VincularToppingDto {
  @IsUUID()
  topping_id!: string;
}

export class ConfigurarToppingsDto {
  @IsArray()
  @ArrayUnique()
  @IsUUID('4', { each: true })
  topping_ids!: string[];
}

export class VincularBebidaDto {
  @IsUUID()
  bebida_id!: string;
}

export class ActualizarExtraDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  nombre?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  precio?: number;

  @IsOptional()
  @IsBoolean()
  disponible?: boolean;
}
