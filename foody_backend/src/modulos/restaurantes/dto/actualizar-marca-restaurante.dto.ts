import {
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

/** Marca del restaurante (nombre/tel + portada/logo en app cliente). */
export class ActualizarMarcaRestauranteDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  nombre?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  telefono?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  logo_url?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  banner_url?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  descripcion?: string | null;
}
