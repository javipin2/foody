import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
export declare const RATE_LIMIT_META = "rate_limit";
export type RateLimitOptions = {
    ventanaMs: number;
    maximo: number;
};
export declare const RateLimitPublico: (maximo?: number, ventanaMs?: number) => import("@nestjs/common").CustomDecorator<string>;
export declare class RateLimitGuard implements CanActivate {
    private readonly reflector;
    private static readonly store;
    constructor(reflector: Reflector);
    canActivate(context: ExecutionContext): boolean;
}
