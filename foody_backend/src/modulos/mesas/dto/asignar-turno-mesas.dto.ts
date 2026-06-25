import { Type } from 'class-transformer';
import {
  IsArray,
  IsOptional,
  IsUUID,
  ValidateNested,
} from 'class-validator';

export class AsignacionMesaTurnoDto {
  @IsUUID()
  mesa_id: string;

  /** null o omitir = quitar mesera asignada */
  @IsOptional()
  @IsUUID()
  mesera_asignada_id?: string | null;
}

export class AsignarTurnoMesasDto {
  @IsUUID()
  sucursal_id: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => AsignacionMesaTurnoDto)
  asignaciones: AsignacionMesaTurnoDto[];
}
