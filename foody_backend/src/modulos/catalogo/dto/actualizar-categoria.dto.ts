import { IsBoolean, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class ActualizarCategoriaDto {
  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  orden?: number;

  @IsOptional()
  @IsBoolean()
  activa?: boolean;
}
