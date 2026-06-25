import { IsOptional, IsString, MaxLength } from 'class-validator';

export class ActualizarComensalDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  comensal_etiqueta?: string | null;
}
