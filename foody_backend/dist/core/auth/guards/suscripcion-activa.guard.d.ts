import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { SuscripcionesVencimientoService } from '../suscripciones-vencimiento.service';
export declare class SuscripcionActivaGuard implements CanActivate {
    private readonly vencimiento;
    private readonly reflector;
    constructor(vencimiento: SuscripcionesVencimientoService, reflector: Reflector);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
