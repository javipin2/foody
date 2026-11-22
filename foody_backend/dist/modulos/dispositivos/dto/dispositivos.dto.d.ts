export declare class RegistrarDispositivoDto {
    device_id: string;
    fcm_token?: string;
    ciudad_id?: string;
    plataforma?: string;
}
export declare class VincularAuthDispositivoDto {
    device_id: string;
    access_token: string;
}
export declare class AnonimizarDispositivoDto {
    fcm_token?: string;
    access_token?: string;
}
