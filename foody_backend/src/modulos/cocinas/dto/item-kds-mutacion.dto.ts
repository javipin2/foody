import { IsBoolean, IsString, MaxLength } from 'class-validator';

export class ActualizarObservacionesItemDto {
  @IsString()
  @MaxLength(500)
  observaciones!: string;
}

export class PrioridadItemCocinaDto {
  @IsBoolean()
  urgente!: boolean;
}
