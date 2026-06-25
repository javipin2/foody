import { OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
export declare class FcmService implements OnModuleInit {
    private readonly config;
    private readonly log;
    private listo;
    constructor(config: ConfigService);
    onModuleInit(): void;
    estaListo(): boolean;
    enviarMulticast(tokens: string[], notification: {
        title: string;
        body: string;
    }, data?: Record<string, string>): Promise<{
        enviados: number;
        fallos: number;
        motivo: "sin_fcm";
    } | {
        enviados: number;
        fallos: number;
        motivo: "ok";
    }>;
}
