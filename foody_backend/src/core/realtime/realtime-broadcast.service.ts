import { randomUUID } from 'crypto';
import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  createClient,
  RealtimeChannel,
  SupabaseClient,
} from '@supabase/supabase-js';
import WebSocket from 'ws';
import { esQaSinEfectosExternos } from '../config/qa-safety';
import {
  pepperRealtime,
  topicCatalogoPublico,
  topicStaff,
} from './realtime-topics';

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
    if (esQaSinEfectosExternos()) {
      this.logger.warn('Realtime desactivado por FOODY_QA_SIN_EFECTOS');
      return;
    }
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
    if (esQaSinEfectosExternos()) return;
    if (!this.estaConfigurado()) {
      this.logger.error(
        'Realtime inactivo al arranque: configure SUPABASE_URL y SUPABASE_SERVICE_KEY en .env',
      );
      return;
    }
    void this.verificarConexion().then((salud) => {
      if (salud.conectado) {
        this.logger.log('Realtime broadcast operativo');
      } else {
        this.logger.error(
          `Realtime broadcast no conectado: ${salud.detalle ?? 'sin detalle'}`,
        );
      }
    });
  }

  estaConfigurado(): boolean {
    return this.cliente !== null;
  }

  /** Pepper HMAC (REALTIME_CANAL_PEPPER o JWT_SECRET). */
  pepper(): string {
    return pepperRealtime(this.config);
  }

  topicSucursal(sucursalId: string): string {
    return topicStaff(this.pepper(), 'sucursal', sucursalId);
  }

  topicCocina(cocinaId: string): string {
    return topicStaff(this.pepper(), 'cocina', cocinaId);
  }

  topicRestaurante(restauranteId: string): string {
    return topicStaff(this.pepper(), 'restaurante', restauranteId);
  }

  topicDomiciliarioPlanta(usuarioId: string): string {
    return topicStaff(this.pepper(), 'domiciliario', usuarioId);
  }

  topicDomiciliarioIndep(domiciliarioId: string): string {
    return topicStaff(this.pepper(), 'domiciliario_indep', domiciliarioId);
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
      this.topicSucursal(payload.sucursal_id),
      'pedido_actualizado',
      payload as unknown as Record<string, unknown>,
    );
  }

  /** Canal opaco: requiere seguimiento_token del pedido (RT-9). */
  static canalPedidoSeguimiento(pedidoId: string, seguimientoToken: string) {
    return `pedido_${pedidoId}_${seguimientoToken}`;
  }

  async pedidoSeguimiento(
    pedidoId: string,
    seguimientoToken: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(
      RealtimeBroadcastService.canalPedidoSeguimiento(
        pedidoId,
        seguimientoToken,
      ),
      'estado_actualizado',
      payload,
    );
  }

  async mesasActualizadas(sucursalId: string) {
    await this.enviarBroadcast(
      this.topicSucursal(sucursalId),
      'mesas_actualizadas',
      { sucursal_id: sucursalId },
    );
  }

  async cocinaActualizada(cocinaId: string, payload: Record<string, unknown>) {
    await this.enviarBroadcast(
      this.topicCocina(cocinaId),
      'cocina_actualizada',
      {
        cocina_id: cocinaId,
        ...payload,
      },
    );
  }

  /** Domiciliario de planta (JWT sub = usuario_id). */
  async domiciliarioPlantaActualizado(
    usuarioId: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(
      this.topicDomiciliarioPlanta(usuarioId),
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
      this.topicDomiciliarioIndep(domiciliarioId),
      'oferta_nueva',
      { domiciliario_id: domiciliarioId, ...payload },
    );
  }

  async cajaMovimiento(
    sucursalId: string,
    payload: Record<string, unknown> = {},
  ) {
    await this.enviarBroadcast(
      this.topicSucursal(sucursalId),
      'caja_movimiento',
      {
        sucursal_id: sucursalId,
        ...payload,
      },
    );
  }

  async alertaNueva(sucursalId: string, payload: Record<string, unknown> = {}) {
    await this.enviarBroadcast(this.topicSucursal(sucursalId), 'alerta_nueva', {
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
    await this.enviarBroadcast(
      this.topicSucursal(sucursalId),
      'qr_aprobacion_urgente',
      {
        sucursal_id: sucursalId,
        ...payload,
      },
    );
  }

  /**
   * Producto/combo agotado o reactivado — menús abiertos refrescan sin recargar app.
   *
   * Se emite en dos canales: el de sucursal (staff, junto al resto de eventos) y
   * `sucursal_{id}_catalogo`, que escucha el menú del cliente anónimo y el POS.
   * El canal de catálogo está separado a propósito: los dispositivos de cliente no
   * deben recibir los payloads de staff (caja, alertas) del canal de sucursal.
   */
  async catalogoDisponibilidad(
    sucursalId: string,
    payload: {
      producto_ids?: string[];
      combo_ids?: string[];
      topping_ids?: string[];
      bebida_ids?: string[];
      disponible: boolean;
    },
  ) {
    const cuerpo = { sucursal_id: sucursalId, ...payload };
    await this.enviarBroadcast(
      this.topicSucursal(sucursalId),
      'catalogo_disponibilidad',
      cuerpo,
    );
    await this.enviarBroadcast(
      topicCatalogoPublico(sucursalId),
      'catalogo_disponibilidad',
      cuerpo,
    );
  }

  /** Plan/suscripción activada tras Wompi — panel admin refresca perfil sin reiniciar. */
  async suscripcionActualizada(
    restauranteId: string,
    payload: { plan: string; pago_id?: string },
  ) {
    await this.enviarBroadcast(
      this.topicRestaurante(restauranteId),
      'suscripcion_actualizada',
      {
        restaurante_id: restauranteId,
        ...payload,
      },
    );
  }

  /** Cliente en mesa pide atención — grid mesero sin refetch completo de mesas. */
  async llamarMesera(
    sucursalId: string,
    payload: {
      pedido_id: string;
      mesa_id?: string | null;
      numero_pedido?: string;
    },
  ) {
    await this.enviarBroadcast(
      this.topicSucursal(sucursalId),
      'llamar_mesera',
      {
        sucursal_id: sucursalId,
        ...payload,
      },
    );
  }

  /** GPS repartidor — separado de cambio de estado del pedido. */
  async ubicacionRepartidor(
    pedidoId: string,
    seguimientoToken: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(
      RealtimeBroadcastService.canalPedidoSeguimiento(
        pedidoId,
        seguimientoToken,
      ),
      'ubicacion_repartidor',
      {
        pedido_id: pedidoId,
        ...payload,
      },
    );
  }

  /** Oferta independiente venció (60 s). */
  async ofertaExpirada(
    domiciliarioId: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(
      this.topicDomiciliarioIndep(domiciliarioId),
      'oferta_expirada',
      { domiciliario_id: domiciliarioId, ...payload },
    );
  }

  /** Pedido cancelado o reasignado — domiciliario de planta deja de verlo. */
  async pedidoDesasignado(usuarioId: string, payload: Record<string, unknown>) {
    await this.enviarBroadcast(
      this.topicDomiciliarioPlanta(usuarioId),
      'pedido_desasignado',
      {
        usuario_id: usuarioId,
        ...payload,
      },
    );
  }

  /** Pedido cancelado — domiciliario independiente debe retirar el pedido activo. */
  async pedidoDesasignadoIndep(
    domiciliarioId: string,
    payload: Record<string, unknown>,
  ) {
    await this.enviarBroadcast(
      this.topicDomiciliarioIndep(domiciliarioId),
      'pedido_desasignado',
      { domiciliario_id: domiciliarioId, ...payload },
    );
  }

  private async obtenerCanal(nombre: string): Promise<RealtimeChannel | null> {
    if (!this.cliente) return null;
    const existente = this.canales.get(nombre);
    if (existente) return existente;

    const ch = this.cliente.channel(nombre, {
      config: { broadcast: { ack: false, self: false } },
    });

    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(
        () => reject(new Error('Timeout suscripción Realtime')),
        8000,
      );
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
      await ch.send({
        type: 'broadcast',
        event: evento,
        payload: {
          event_id: randomUUID(),
          emitido_at: new Date().toISOString(),
          ...payload,
        },
      });
    } catch (e) {
      this.logger.warn(`Broadcast ${canal}/${evento}: ${e}`);
    }
  }
}
