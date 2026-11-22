import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class CalificarDomicilioClienteDto {
  @IsString()
  device_id!: string;

  @IsInt()
  @Min(1)
  @Max(5)
  calificacion!: number;

  @IsOptional()
  @IsString()
  comentario?: string;
}
