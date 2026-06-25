import { IsIn } from 'class-validator';
import { PLANES_PAGO } from '../pagos-planes.config';

export class CheckoutPlanDto {
  @IsIn(PLANES_PAGO)
  plan: (typeof PLANES_PAGO)[number];
}
