import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
export declare class HealthController {
    private readonly realtimeService;
    constructor(realtimeService: RealtimeBroadcastService);
    verificarRealtime(): Promise<import("../../core/realtime/realtime-broadcast.service").SaludRealtime>;
}
