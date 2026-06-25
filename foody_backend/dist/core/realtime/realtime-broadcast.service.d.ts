import { OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
export type EventoPedidoBroadcast = {
    pedido_id: string;
    sucursal_id: string;
    estado?: string;
    numero_pedido?: string;
};
export type SaludRealtime = {
    configurado: boolean;
    conectado: boolean;
    detalle?: string;
};
export declare class RealtimeBroadcastService implements OnModuleInit, OnModuleDestroy {
    private readonly config;
    private readonly logger;
    private cliente;
    private readonly canales;
    constructor(config: ConfigService);
    onModuleInit(): void;
    estaConfigurado(): boolean;
    verificarConexion(): Promise<SaludRealtime>;
    onModuleDestroy(): void;
    pedidoActualizado(payload: EventoPedidoBroadcast): Promise<void>;
    pedidoSeguimiento(pedidoId: string, payload: Record<string, unknown>): Promise<void>;
    mesasActualizadas(sucursalId: string): Promise<void>;
    cocinaActualizada(cocinaId: string, payload: Record<string, unknown>): Promise<void>;
    domiciliarioPlantaActualizado(usuarioId: string, payload: Record<string, unknown>): Promise<void>;
    domiciliarioIndepOferta(domiciliarioId: string, payload: Record<string, unknown>): Promise<void>;
    cajaMovimiento(sucursalId: string, payload?: Record<string, unknown>): Promise<void>;
    alertaNueva(sucursalId: string, payload?: Record<string, unknown>): Promise<void>;
    qrAprobacionUrgente(sucursalId: string, payload: {
        pedido_id: string;
        mesa_id?: string | null;
        numero_pedido?: string;
        creado_at?: string;
        nivel?: 'nuevo' | 'advertencia_3min' | 'urgente_5min';
    }): Promise<void>;
    catalogoDisponibilidad(sucursalId: string, payload: {
        producto_ids?: string[];
        combo_ids?: string[];
        disponible: boolean;
    }): Promise<void>;
    private obtenerCanal;
    private enviarBroadcast;
}
