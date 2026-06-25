import { IsBoolean, IsOptional, Matches } from 'class-validator';

export class ActualizarHorarioDto {
  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'hora_apertura debe ser HH:MM (24h)',
  })
  hora_apertura?: string;

  @IsOptional()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d$/, {
    message: 'hora_cierre debe ser HH:MM (24h)',
  })
  hora_cierre?: string;

  @IsOptional()
  @IsBoolean()
  activo?: boolean;
}
