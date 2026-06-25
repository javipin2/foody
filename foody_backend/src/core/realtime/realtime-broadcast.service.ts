import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createClient,
  RealtimeChannel,
  SupabaseClient,
} from '@supabase/supabase-js';
import WebSocket from 'ws';

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

@Injectable()
export class RealtimeBroadcastService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RealtimeBroadcastService.name);
  private cliente: SupabaseClient | null = null;
  private readonly canales = new Map<string, RealtimeChannel>();

  constructor(private readonly config: ConfigService) {
    const url = this.config.get<string>('SUPABASE_URL');
    const key = this.config.get<string>('SUPABASE_SERVICE_KEY');
    if (url && key) {
      this.cliente = createClient(url, key, {
        auth: { persistSession: false, autoRefreshToken: false },
        realtime: {
          // Node 20: WebSocket nativo no disponible; requiere paquete ws
          transport: WebSocket as never,
        },
      });
    } else {
      this.logger.error(
        'SUPABASE_URL o SUPABASE_SERVICE_KEY no configurados — broadcast Realtime desactivado',
      );
    }
  }

  onModuleInit() {
    if (this.estaConfigurado()) return;
    this.logger.error(
      'Realtime inactivo al arranque: configure SUPABASE_URL y SUPABASE_SERVICE_KEY en .env',
    );
  }

  estaConfigurado(): boolean {
    return this.cliente !== null;
  }

  async verificarConexion(): Promise<SaludRealtime> {
    if (!this.cliente) {
      return {
        configurado: false,
        conectado: false,
        detalle: 'Faltan SUPABASE_URL o SUPABASE_SERVICE_KEY',
      };
    }
    try {
      const ch = await this.obtenerCanal('foody_health_check');
      if (!ch) {
        return {
          configurado: true,
          conectado: false,
          detalle: 'No se pudo abrir canal Realtime',
        };
      }
      await ch.send({
        type: 'broadcast',
        event: 'ping',
        payload: { origen: 'health', t: Date.now() },
      });
      return { configurado: true, conectado: true };
    } catch (e) {
      const detalle = e instanceof Error ? e.message : String(e);
      this.logger.error(`Health Realtime falló: ${detalle}`);
      return { configurado: true, conectado: false, detalle };
    }
  }

  onModuleDestroy() {
    if (!this.cliente) return;
    for (const [, ch] of this.canales) {
      void this.cliente.removeChannel(ch);
    }
    this.canales.clear();
  }

  async pedidoActualizado(payload: EventoPedidoBroadcast) {
    await this.enviarBroadcast(
      `sucursal_${payload.sucursal_id}`,
      'pedido_actualizado',
      payload as unknown as Record<string, unknown>,
    );
  }

  async pedidoSeguimiento(pedidoId: string, payload: Record<string, unknown>) {
    await this.enviarBroadcast(`pedido_${pedidoId}`, 'estado_actualizado', payload);
  }

  async mesasActualizadas(sucursalId: string) {
    await this.enviarBroadcast(`sucursal_${sucursalId}`, 'mesas_actualizadas', {
      sucursal_id: sucursalId,
    });
  }

  async cocinaActualizada(
    cocinaId: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(`cocina_${cocinaId}`, 'cocina_actualizada', {
      cocina_id: cocinaId,
      ...payload,
    });
  }

  /** Domiciliario de planta (JWT sub = usuario_id). */
  async domiciliarioPlantaActualizado(
    usuarioId: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(
      `domiciliario_${usuarioId}`,
      'pedido_asignado',
      { usuario_id: usuarioId, ...payload },
    );
  }

  /** Domiciliario independiente (JWT sub = domiciliarios_independientes.id). */
  async domiciliarioIndepOferta(
    domiciliarioId: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(
      `domiciliario_indep_${domiciliarioId}`,
      'oferta_nueva',
      { domiciliario_id: domiciliarioId, ...payload },
    );
  }

  async cajaMovimiento(sucursalId: string, payload: Record<string, unknown> = {}) {
    await this.enviarBroadcast(`sucursal_${sucursalId}`, 'caja_movimiento', {
      sucursal_id: sucursalId,
      ...payload,
    });
  }

  async alertaNueva(sucursalId: string, payload: Record<string, unknown> = {}) {
    await this.enviarBroadcast(`sucursal_${sucursalId}`, 'alerta_nueva', {
      sucursal_id: sucursalId,
      ...payload,
    });
  }

  /** Pedido QR en mesa esperando aprobación (staff debe ver grid al instante). */
  async qrAprobacionUrgente(
    sucursalId: string,
    payload: {
      pedido_id: string;
      mesa_id?: string | null;
      numero_pedido?: string;
      creado_at?: string;
      nivel?: 'nuevo' | 'advertencia_3min' | 'urgente_5min';
    },
  ) {
    await this.enviarBroadcast(`sucursal_${sucursalId}`, 'qr_aprobacion_urgente', {
      sucursal_id: sucursalId,
      ...payload,
    });
  }

  /** Producto/combo agotado o reactivado — menús abiertos refrescan sin recargar app. */
  async catalogoDisponibilidad(
    sucursalId: string,
    payload: {
      producto_ids?: string[];
      combo_ids?: string[];
      disponible: boolean;
    },
  ) {
    await this.enviarBroadcast(`sucursal_${sucursalId}`, 'catalogo_disponibilidad', {
      sucursal_id: sucursalId,
      ...payload,
    });
  }

  private async obtenerCanal(nombre: string): Promise<RealtimeChannel | null> {
    if (!this.cliente) return null;
    const existente = this.canales.get(nombre);
    if (existente) return existente;

    const ch = this.cliente.channel(nombre, {
      config: { broadcast: { ack: false, self: false } },
    });

    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Timeout suscripción Realtime')), 8000);
      ch.subscribe((status, err) => {
        if (status === 'SUBSCRIBED') {
          clearTimeout(timeout);
          resolve();
        }
        if (status === 'CHANNEL_ERROR') {
          clearTimeout(timeout);
          reject(err ?? new Error('CHANNEL_ERROR'));
        }
      });
    });

    this.canales.set(nombre, ch);
    return ch;
  }

  private async enviarBroadcast(
    canal: string,
    evento: string,
    payload: Record<string, unknown>,
  ) {
    try {
      const ch = await this.obtenerCanal(canal);
      if (!ch) return;
      await ch.send({ type: 'broadcast', event: evento, payload });
    } catch (e) {
      this.logger.warn(`Broadcast ${canal}/${evento}: ${e}`);
    }
  }
}
