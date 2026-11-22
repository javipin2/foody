import { CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { DatabaseService } from '../../core/database/database.service';
export declare const RATE_LIMIT_META = "rate_limit";
export type RateLimitOptions = {
    ventanaMs: number;
    maximo: number;
};
export declare const RateLimitPublico: (maximo?: number, ventanaMs?: number) => import("@nestjs/common").CustomDecorator<string>;
export declare class RateLimitGuard implements CanActivate {
    private readonly reflector;
    private readonly database;
    private static readonly store;
    constructor(reflector: Reflector, database: DatabaseService);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
