import { Transform } from 'class-transformer';
import {
  IsBooleanString,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  Min,
} from 'class-validator';

export const PRESETS_ANALITICA = [
  'hoy',
  'ayer',
  'semana',
  'mes',
  'mes_anterior',
  '7d',
  '30d',
  'anio',
  'rango',
] as const;

export type PresetAnalitica = (typeof PRESETS_ANALITICA)[number];

/** Query ?ids=a,b o ?ids=a&ids=b → string[] */
function aLista(value: unknown): string[] | undefined {
  if (value == null || value === '') return undefined;
  const raw = Array.isArray(value) ? value : String(value).split(',');
  const list = raw.map((v) => String(v).trim()).filter(Boolean);
  return list.length ? list : undefined;
}

function aEntero(value: unknown): number | undefined {
  if (value == null || value === '') return undefined;
  const n = Number(value);
  return Number.isFinite(n) ? n : undefined;
}

export class FiltroAnaliticaDto {
  @IsOptional()
  @IsIn([...PRESETS_ANALITICA])
  preset?: PresetAnalitica;

  @IsOptional()
  @IsDateString()
  desde?: string;

  @IsOptional()
  @IsDateString()
  hasta?: string;

  @IsOptional()
  @IsBooleanString()
  comparar?: string;

  @IsOptional()
  @IsDateString()
  comparar_desde?: string;

  @IsOptional()
  @IsDateString()
  comparar_hasta?: string;

  @IsOptional()
  @IsUUID()
  sucursal_id?: string;

  @IsOptional()
  @Transform(({ value }) => aEntero(value))
  @IsInt()
  @Min(0)
  @Max(23)
  hora_desde?: number;

  @IsOptional()
  @Transform(({ value }) => aEntero(value))
  @IsInt()
  @Min(0)
  @Max(23)
  hora_hasta?: number;

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsString({ each: true })
  estados?: string[];

  /** Si true, `estados` puede incluir cancelado/rechazado (ANA-ESTADOS-01). */
  @IsOptional()
  @IsBooleanString()
  incluir_cancelados?: string;

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsString({ each: true })
  item_estados_cocina?: string[];

  @IsOptional()
  @IsBooleanString()
  solo_pendiente_pago?: string;

  @IsOptional()
  @IsBooleanString()
  solo_facturados?: string;

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsUUID('4', { each: true })
  mesera_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsUUID('4', { each: true })
  cocina_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsUUID('4', { each: true })
  producto_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsUUID('4', { each: true })
  categoria_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsUUID('4', { each: true })
  domiciliario_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsUUID('4', { each: true })
  caja_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsUUID('4', { each: true })
  cajero_ids?: string[];

  @IsOptional()
  @Transform(({ value }) => aLista(value))
  @IsString({ each: true })
  metodos_pago?: string[];

  @IsOptional()
  @IsString()
  cliente_telefono?: string;

  @IsOptional()
  @IsString()
  device_id?: string;

  @IsOptional()
  @IsIn(['frecuente', 'nuevo', 'todos'])
  cliente_segmento?: 'frecuente' | 'nuevo' | 'todos';

  /** csv = UTF-8 BOM para Excel; xlsx = mismo CSV (Fase 3 = .xlsx nativo sin dep extra). */
  @IsOptional()
  @IsIn(['csv', 'xlsx'])
  formato?: 'csv' | 'xlsx';

  /** Límite para pedidos-recientes (1–50). */
  @IsOptional()
  @Transform(({ value }) => aEntero(value))
  @IsInt()
  @Min(1)
  @Max(50)
  limite?: number;
}
