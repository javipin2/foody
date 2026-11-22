import { IsString, MinLength } from 'class-validator';

export class AnularFacturaDto {
  @IsString()
  @MinLength(3)
  motivo!: string;
}
