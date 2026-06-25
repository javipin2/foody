import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PlanFeaturesService } from '../plan-features.service';
export declare class PlanFeaturesGuard implements CanActivate {
    private readonly reflector;
    private readonly planFeatures;
    constructor(reflector: Reflector, planFeatures: PlanFeaturesService);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
