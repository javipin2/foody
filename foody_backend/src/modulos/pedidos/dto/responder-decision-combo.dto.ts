import {
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';

export class ResponderDecisionComboDto {
  @IsIn(['aceptar_sustitucion', 'cancelar_combo'])
  accion!: 'aceptar_sustitucion' | 'cancelar_combo';

  @ValidateIf(
    (o: ResponderDecisionComboDto) => o.accion === 'aceptar_sustitucion',
  )
  @IsInt()
  @Min(1)
  cotizacion_version?: number;

  @ValidateIf(
    (o: ResponderDecisionComboDto) => o.accion === 'aceptar_sustitucion',
  )
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  total_aceptado?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  motivo?: string;
}
