import { CanActivate, ExecutionContext } from '@nestjs/common';
import { SuscripcionesVencimientoService } from '../suscripciones-vencimiento.service';
export declare class SuscripcionActivaGuard implements CanActivate {
    private readonly vencimiento;
    constructor(vencimiento: SuscripcionesVencimientoService);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
