import { IsOptional, IsString, IsUUID, Matches } from 'class-validator';

/** GET /auditoria/timeline (BN-DTO-23). Fechas YYYY-MM-DD. */
export class TimelineAuditoriaDto {
  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'desde debe ser YYYY-MM-DD',
  })
  desde?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'hasta debe ser YYYY-MM-DD',
  })
  hasta?: string;
}
