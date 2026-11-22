import {
  BadRequestException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { AlertasRiesgoService } from '../alertas/alertas-riesgo.service';
import { PedidosEstadoCommandService } from '../pedidos/pedidos-estado-command.service';
import { PedidosDispatchHooksService } from '../pedidos/pedidos-dispatch-hooks.service';
import { ConfiguracionGlobalService } from '../../core/config/configuracion-global.module';

const MAX_NOTIFICADOS = 5;

@Injectable()
export class DispatchService implements OnModuleInit {
  private expirandoOfertas = false;
  private readonly LOCK_TICK_EXPIRAR_OFERTAS = 9200001;

  constructor(
    private readonly database: DatabaseService,
    private readonly alertasRiesgo: AlertasRiesgoService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly notificaciones: NotificacionesService,
    private readonly pedidosEstadoCommand: PedidosEstadoCommandService,
    private readonly pedidosDispatchHooks: PedidosDispatchHooksService,
    private readonly configGlobal: ConfiguracionGlobalService,
  ) {}

  private get radioInicialKm() {
    return this.configGlobal.radioInicialKm();
  }

  private get radioIncrementoKm() {
    return this.configGlobal.ampliacionRadioKm();
  }

  private get maxIntentos() {
    return this.configGlobal.intentosMaxBusqueda();
  }

  private get ofertaExpiraSeg() {
    return this.configGlobal.ofertaExpiraSeg();
  }

  private get comisionFoodyPct() {
    return this.configGlobal.comisionFoodyPct();
  }

  onModuleInit() {
    // AQ-CYCLE-01: pedidos llama hooks; nosotros somos el handler.
    this.pedidosDispatchHooks.registrar((pedidoId, sucursalId) =>
      this.intentarDispatchAutomatico(pedidoId, sucursalId),
    );
    setInterval(
      () => void this.database.intentarAdvisoryLock(
        this.LOCK_TICK_EXPIRAR_OFERTAS,
        () => this.tickExpirarOfertas(),
      ),
      30_000,
    );
  }

  private async tickExpirarOfertas() {
    if (this.expirandoOfertas) return;
    this.expirandoOfertas = true;
    try {
      const reintentar = await this.expirarOfertasVencidas();
      for (const r of reintentar) {
        // Auto-amplía radio en el siguiente intento si el pedido sigue listo.
        void this.iniciarBusquedaIndependientes(r.pedido_id, r.sucursal_id);
      }
    } finally {
      this.expirandoOfertas = false;
    }
  }

  async contarPlantaLibres(sucursalId: string): Promise<number> {
    const filas = await this.database.consultar<{ id: string }>(
      `SELECT dp.id
       FROM domiciliarios_planta dp
       JOIN usuarios u ON u.id = dp.usuario_id
       WHERE dp.sucursal_id = $1 AND dp.activo = true AND u.activo = true
         AND NOT EXISTS (
           SELECT 1 FROM asignaciones_domicilio ad
           WHERE ad.domiciliario_planta_id = dp.id
             AND ad.estado IN ('asignado', 'en_camino')
         )`,
      [sucursalId],
    );
    return filas.length;
  }

  async intentarDispatchAutomatico(pedidoId: string, sucursalId: string) {
    const pedido = await this.database.consultarUno<{
      id: string;
      tipo: string;
      estado: string;
      costo_domicilio: string;
    }>(
      `SELECT id, tipo, estado, costo_domicilio FROM pedidos
       WHERE id = $1 AND sucursal_id = $2`,
      [pedidoId, sucursalId],
    );
    if (!pedido || pedido.tipo !== 'domicilio' || pedido.estado !== 'listo') {
      return { iniciado: false, motivo: 'pedido_no_aplica' };
    }

    const asignado = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM asignaciones_domicilio
       WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')`,
      [pedidoId],
    );
    if (asignado) {
      return { iniciado: true, motivo: 'ya_asignado' };
    }

    const plantaLibres = await this.contarPlantaLibres(sucursalId);
    if (plantaLibres > 0) {
      const auto = await this.asignarPrimeraPlantaLibre(pedidoId, sucursalId);
      if (auto) {
        return { iniciado: true, motivo: 'planta_asignada_auto', ...auto };
      }
    }

    return this.iniciarBusquedaIndependientes(pedidoId, sucursalId);
  }

  /** Asigna el primer domiciliario de planta libre (FIFO por nombre). */
  private async asignarPrimeraPlantaLibre(pedidoId: string, sucursalId: string) {
    const result = await this.database.enTransaccion(async (client) => {
      const pedido = await client.query<{ id: string; estado: string; tipo: string }>(
        `SELECT id, estado, tipo FROM pedidos
         WHERE id = $1 AND sucursal_id = $2
         FOR UPDATE`,
        [pedidoId, sucursalId],
      );
      const fila = pedido.rows[0];
      if (!fila || fila.tipo !== 'domicilio' || fila.estado !== 'listo') {
        return null;
      }

      const previa = await client.query<{ id: string }>(
        `SELECT id FROM asignaciones_domicilio
         WHERE pedido_id = $1 AND estado IN ('asignado', 'en_camino')
         LIMIT 1`,
        [pedidoId],
      );
      if (previa.rows[0]) return null;

      const planta = await client.query<{
        id: string;
        usuario_id: string;
      }>(
        `SELECT dp.id, dp.usuario_id
         FROM domiciliarios_planta dp
         JOIN usuarios u ON u.id = dp.usuario_id
         WHERE dp.sucursal_id = $1 AND dp.activo = true AND u.activo = true
           AND NOT EXISTS (
             SELECT 1 FROM asignaciones_domicilio ad
             INNER JOIN pedidos p ON p.id = ad.pedido_id
             WHERE ad.domiciliario_planta_id = dp.id
               AND ad.estado IN ('asignado', 'en_camino')
               AND p.estado NOT IN ('cancelado', 'rechazado', 'entregado', 'pagado')
           )
         ORDER BY u.nombre
         LIMIT 1`,
        [sucursalId],
      );
      const dom = planta.rows[0];
      if (!dom) return null;

      await client.query(
        `INSERT INTO asignaciones_domicilio
           (pedido_id, sucursal_id, domiciliario_planta_id, tipo_domiciliario, estado, distancia_km)
         SELECT $1, $2, $3::uuid, 'planta', 'asignado',
           CASE
             WHEN s.lat IS NOT NULL AND s.lng IS NOT NULL
              AND p.lat IS NOT NULL AND p.lng IS NOT NULL
             THEN ROUND((
               6371 * acos(LEAST(1::float8, GREATEST(-1::float8,
                 cos(radians(s.lat::float8)) * cos(radians(p.lat::float8))
                 * cos(radians(p.lng::float8) - radians(s.lng::float8))
                 + sin(radians(s.lat::float8)) * sin(radians(p.lat::float8))
               )))
             )::numeric, 3)
             ELSE NULL
           END
         FROM pedidos p
         JOIN sucursales s ON s.id = p.sucursal_id
         WHERE p.id = $1 AND p.sucursal_id = $2`,
        [pedidoId, sucursalId, dom.id],
      );

      await this.pedidosEstadoCommand.aplicarEstadoEnTransaccion(client, {
        pedidoId,
        sucursalId,
        nuevoEstado: 'asignado',
        origen: 'dispatch',
        estadoAnterior: 'listo',
        tipo: 'domicilio',
      });

      return {
        pedido_id: pedidoId,
        domiciliario_planta_id: dom.id,
        domiciliario_usuario_id: dom.usuario_id,
        estado: 'asignado' as const,
      };
    });

    if (!result) return null;

    void this.realtime.domiciliarioPlantaActualizado(result.domiciliario_usuario_id, {
      pedido_id: result.pedido_id,
      sucursal_id: sucursalId,
      accion: 'asignado',
    });
    void this.realtime.pedidoActualizado({
      pedido_id: result.pedido_id,
      sucursal_id: sucursalId,
      estado: result.estado,
    });

    void this.notificaciones.enviar({
      sucursal_id: sucursalId,
      tipo: 'domicilio_asignado_planta',
      titulo: 'Nuevo domicilio asignado',
      cuerpo: 'Tienes un pedido listo para recoger y entregar',
      destinatario_usuario_id: result.domiciliario_usuario_id,
      datos: {
        pedido_id: result.pedido_id,
        ruta: '/domiciliario/planta',
      },
    });

    return result;
  }

  async iniciarBusquedaIndependientes(pedidoId: string, sucursalId: string) {
    await this.expirarOfertasVencidas(pedidoId);

    const ofertaActiva = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM ofertas_pedido
       WHERE pedido_id = $1 AND estado = 'activa' AND expira_at > now()`,
      [pedidoId],
    );
    if (ofertaActiva) {
      return { iniciado: false, motivo: 'oferta_activa', oferta_id: ofertaActiva.id };
    }

    const ultimoIntento = await this.database.consultarUno<{ intento: number }>(
      `SELECT COALESCE(MAX(intento_numero), 0) AS intento
       FROM ofertas_pedido WHERE pedido_id = $1`,
      [pedidoId],
    );
    const intentoNumero = (ultimoIntento?.intento ?? 0) + 1;
    if (intentoNumero > this.maxIntentos) {
      await this.crearAlertaSinDomiciliario(pedidoId, sucursalId);
      return { iniciado: false, motivo: 'max_intentos', intento: intentoNumero };
    }

    const sucursal = await this.database.consultarUno<{
      lat: string | null;
      lng: string | null;
      ciudad_id: string;
      ciudad_slug: string | null;
    }>(
      `SELECT s.lat, s.lng, s.ciudad_id, c.slug AS ciudad_slug
       FROM sucursales s
       LEFT JOIN ciudades c ON c.id = s.ciudad_id
       WHERE s.id = $1`,
      [sucursalId],
    );
    if (!sucursal) {
      throw new NotFoundException('Sucursal no encontrada');
    }

    let latSucursal = sucursal.lat != null ? Number(sucursal.lat) : null;
    let lngSucursal = sucursal.lng != null ? Number(sucursal.lng) : null;
    if (latSucursal == null || lngSucursal == null) {
      const centro = this.centroCiudadPorSlug(sucursal.ciudad_slug);
      if (!centro) {
        throw new BadRequestException({
          error: 'SUCURSAL_SIN_COORDENADAS',
          message:
            'La sucursal no tiene ubicación GPS. Configura lat/lng en la sede o usa una ciudad con centro conocido.',
        });
      }
      latSucursal = centro.lat;
      lngSucursal = centro.lng;
    }

    const radioKm =
      this.radioInicialKm + this.radioIncrementoKm * (intentoNumero - 1);
    const candidatos = await this.buscarIndependientesCercanos(
      sucursal.ciudad_id,
      latSucursal,
      lngSucursal,
      radioKm,
    );

    if (!candidatos.length) {
      // Persistir intento vacío para que el radio avance en el siguiente.
      await this.database.consultar(
        `INSERT INTO ofertas_pedido (
           pedido_id, sucursal_id, radio_busqueda_km, intento_numero, estado, expira_at
         ) VALUES ($1,$2,$3,$4,'expirada', now())`,
        [pedidoId, sucursalId, radioKm, intentoNumero],
      );
      if (intentoNumero >= this.maxIntentos) {
        await this.crearAlertaSinDomiciliario(pedidoId, sucursalId);
      }
      return {
        iniciado: false,
        motivo: 'DOMICILIARIO_NO_DISPONIBLE',
        mensaje:
          `No hay repartidores independientes conectados y disponibles en un radio de ${radioKm} km. ` +
          'Un repartidor debe abrir la app (Soy repartidor independiente), iniciar turno y activar disponibilidad en la misma ciudad.',
        intento: intentoNumero,
        radio_km: radioKm,
        expira_en_seg: this.ofertaExpiraSeg,
      };
    }

    const notificados = candidatos.slice(0, MAX_NOTIFICADOS);
    const expiraAt = new Date(Date.now() + this.ofertaExpiraSeg * 1000);

    const oferta = await this.database.enTransaccion(async (client) => {
      const insert = await client.query<{ id: string }>(
        `INSERT INTO ofertas_pedido (
           pedido_id, sucursal_id, radio_busqueda_km, intento_numero, expira_at
         ) VALUES ($1,$2,$3,$4,$5) RETURNING id`,
        [pedidoId, sucursalId, radioKm, intentoNumero, expiraAt.toISOString()],
      );
      const ofertaId = insert.rows[0].id;

      for (const c of notificados) {
        await client.query(
          `INSERT INTO respuestas_oferta (oferta_id, domiciliario_id, respuesta)
           VALUES ($1,$2,'no_vio')`,
          [ofertaId, c.domiciliario_id],
        );
      }

      return { id: ofertaId, notificados: notificados.length };
    });

    void this.notificaciones.enviar({
      sucursal_id: sucursalId,
      tipo: 'domicilio_busqueda_independientes',
      titulo: 'Buscando repartidor',
      cuerpo: `${oferta.notificados} independiente(s) notificado(s)`,
      roles: ['admin', 'gerente'],
      datos: { pedido_id: pedidoId, oferta_id: oferta.id },
    });

    for (const c of notificados) {
      void this.realtime.domiciliarioIndepOferta(c.domiciliario_id, {
        oferta_id: oferta.id,
        pedido_id: pedidoId,
        sucursal_id: sucursalId,
        expira_at: expiraAt.toISOString(),
      });
      void this.notificaciones.enviar({
        tipo: 'oferta_domicilio',
        titulo: 'Nuevo pedido disponible',
        cuerpo: `Tienes ${this.ofertaExpiraSeg} s para aceptar un domicilio`,
        destinatario_domiciliario_id: c.domiciliario_id,
        datos: {
          oferta_id: oferta.id,
          pedido_id: pedidoId,
          sucursal_id: sucursalId,
          expira_en_seg: String(this.ofertaExpiraSeg),
          ruta: '/domiciliario/independiente',
        },
      });
    }

    return {
      iniciado: true,
      oferta_id: oferta.id,
      intento: intentoNumero,
      radio_km: radioKm,
      domiciliarios_notificados: oferta.notificados,
      expira_en_seg: this.ofertaExpiraSeg,
    };
  }

  private async buscarIndependientesCercanos(
    ciudadId: string,
    latSucursal: number,
    lngSucursal: number,
    radioKm: number,
  ) {
    const sesiones = await this.database.consultar<{
      sesion_id: string;
      domiciliario_id: string;
      lat_actual: string;
      lng_actual: string;
      nombre: string;
    }>(
      `SELECT ds.id AS sesion_id,
              ds.domiciliario_id,
              ds.lat_actual,
              ds.lng_actual,
              di.nombre
       FROM domiciliarios_sesiones ds
       JOIN domiciliarios_independientes di ON di.id = ds.domiciliario_id
       WHERE ds.activa = true
         AND ds.disponible = true
         AND di.estado_cuenta = 'activo'
         AND di.ciudad_id = $1
         AND ds.lat_actual IS NOT NULL
         AND ds.lng_actual IS NOT NULL
         AND NOT EXISTS (
           SELECT 1 FROM asignaciones_domicilio ad
           WHERE ad.domiciliario_independiente_id = di.id
             AND ad.estado IN ('asignado', 'en_camino')
         )`,
      [ciudadId],
    );

    return sesiones
      .map((s) => ({
        ...s,
        distancia_km: this.distanciaKm(
          latSucursal,
          lngSucursal,
          Number(s.lat_actual),
          Number(s.lng_actual),
        ),
      }))
      .filter((s) => s.distancia_km <= radioKm)
      .sort((a, b) => a.distancia_km - b.distancia_km);
  }

  /** @returns pedidos a reintentar (aún listos, sin asignación). */
  private async expirarOfertasVencidas(
    pedidoId?: string,
  ): Promise<Array<{ pedido_id: string; sucursal_id: string }>> {
    const filtro = pedidoId ? 'AND pedido_id = $1' : '';
    const params = pedidoId ? [pedidoId] : [];
    const vencidas = await this.database.consultar<{
      id: string;
      pedido_id: string;
      sucursal_id: string;
    }>(
      `UPDATE ofertas_pedido SET estado = 'expirada'
       WHERE estado = 'activa' AND expira_at <= now() ${filtro}
       RETURNING id, pedido_id, sucursal_id`,
      params,
    );

    const reintentar: Array<{ pedido_id: string; sucursal_id: string }> = [];

    for (const oferta of vencidas) {
      const domiciliarios = await this.database.consultar<{
        domiciliario_id: string;
      }>(
        `SELECT domiciliario_id FROM respuestas_oferta
         WHERE oferta_id = $1 AND respuesta = 'no_vio'`,
        [oferta.id],
      );
      for (const d of domiciliarios) {
        void this.realtime.ofertaExpirada(d.domiciliario_id, {
          oferta_id: oferta.id,
          pedido_id: oferta.pedido_id,
          sucursal_id: oferta.sucursal_id,
        });
      }

      const sigueListo = await this.database.consultarUno<{ id: string }>(
        `SELECT p.id FROM pedidos p
         WHERE p.id = $1
           AND p.estado = 'listo'
           AND p.tipo = 'domicilio'
           AND NOT EXISTS (
             SELECT 1 FROM asignaciones_domicilio ad
             WHERE ad.pedido_id = p.id
               AND ad.estado IN ('asignado', 'en_camino')
           )`,
        [oferta.pedido_id],
      );
      if (sigueListo) {
        reintentar.push({
          pedido_id: oferta.pedido_id,
          sucursal_id: oferta.sucursal_id,
        });
      }
    }

    return reintentar;
  }

  private async crearAlertaSinDomiciliario(
    pedidoId: string,
    sucursalId: string,
  ) {
    await this.alertasRiesgo.registrar({
      sucursalId,
      tipo: 'pedido_sin_domiciliario',
      nivel: 'alto',
      descripcion:
        'Pedido de domicilio listo sin domiciliario tras 3 intentos de búsqueda',
      referenciaId: pedidoId,
      referenciaTipo: 'pedido',
      deduplicar: true,
    });
  }

  distanciaKm(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLng = ((lng2 - lng1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  async consultarUnoCliente<T extends QueryResultRow>(
    client: PoolClient,
    sql: string,
    params: unknown[],
  ): Promise<T | null> {
    const r = await client.query<T>(sql, params);
    return r.rows[0] ?? null;
  }

  calcularGanancias(costoDomicilio: number) {
    const comision = Math.round(costoDomicilio * this.comisionFoodyPct);
    const ganancia = costoDomicilio - comision;
    return { comision, ganancia };
  }

  /** Centro aproximado para dispatch cuando la sucursal aún no tiene GPS propio. */
  private centroCiudadPorSlug(slug: string | null | undefined) {
    if (!slug) return null;
    const centros: Record<string, { lat: number; lng: number }> = {
      valledupar: { lat: 10.463714, lng: -73.253222 },
    };
    return centros[slug.toLowerCase()] ?? null;
  }
}
