import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import { esAdminRestaurante } from '../../core/auth/roles-food';
import { DatabaseService } from '../../core/database/database.service';
import { ImpresionService } from '../../core/impresion/impresion.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';
import { CrearPedidoDto } from './dto/crear-pedido.dto';

export type OpcionesStaffPedido = {
  creadoPorStaff?: boolean;
  usuarioId?: string;
  /** Rol JWT del staff que opera (mesero asigna mesa; cajero/admin no). */
  rol?: string;
  /** El usuario puede registrar cobros confirmados desde el POS. */
  puedeCobrar?: boolean;
  /** Solo calcula totales (sin INSERT / stock / idempotencia). AQ-SOLID-06. */
  soloEstimar?: boolean;
};

/** Utilidades compartidas entre subdominios de pedidos (mesa, crear, estado). */
@Injectable()
export class PedidosSoporteService {
  private readonly logger = new Logger(PedidosSoporteService.name);

  constructor(
    private readonly database: DatabaseService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly notificaciones: NotificacionesService,
    private readonly impresion: ImpresionService,
  ) {}

  async obtenerSeguimientoToken(pedidoId: string): Promise<string | null> {
    const row = await this.database.consultarUno<{ seguimiento_token: string }>(
      `SELECT seguimiento_token::text AS seguimiento_token FROM pedidos WHERE id = $1`,
      [pedidoId],
    );
    return row?.seguimiento_token ?? null;
  }

  emitirSeguimientoPedido(pedidoId: string, payload: Record<string, unknown>) {
    void this.obtenerSeguimientoToken(pedidoId).then((token) => {
      if (token) void this.realtime.pedidoSeguimiento(pedidoId, token, payload);
    });
  }

  emitirUbicacionRepartidor(
    pedidoId: string,
    payload: Record<string, unknown>,
  ) {
    void this.obtenerSeguimientoToken(pedidoId).then((token) => {
      if (token)
        void this.realtime.ubicacionRepartidor(pedidoId, token, payload);
    });
  }

  async consultarUnoCliente<T extends QueryResultRow>(
    client: PoolClient,
    sql: string,
    parametros: unknown[],
  ): Promise<T | null> {
    const resultado = await client.query<T>(sql, parametros);
    return resultado.rows[0] ?? null;
  }

  /** Solo el mesero recibe turno de mesa; cajero puede pedir/cobrar sin asignación. */
  esRolMesero(rol?: string): boolean {
    return rol === 'mesero';
  }

  async assertMeseraPuedeTomarMesa(
    client: PoolClient,
    sucursalId: string,
    mesaId: string,
    meseraId: string,
  ) {
    const mesa = await this.consultarUnoCliente<{
      mesera_asignada_id: string | null;
    }>(
      client,
      `SELECT mesera_asignada_id FROM mesas
       WHERE id = $1 AND sucursal_id = $2 AND activa = true`,
      [mesaId, sucursalId],
    );
    if (!mesa) throw new BadRequestException('MESA_NO_ENCONTRADA');
    if (
      mesa.mesera_asignada_id != null &&
      mesa.mesera_asignada_id !== meseraId
    ) {
      throw new BadRequestException({
        error: 'MESA_ASIGNADA_OTRA_MESERA',
        message:
          'Esta mesa está siendo atendida por otra mesera. Pide transferencia al admin.',
      });
    }
  }

  async asignarMeseraAMesa(
    client: PoolClient,
    sucursalId: string,
    mesaId: string,
    meseraId: string,
  ) {
    await client.query(
      `UPDATE mesas
       SET mesera_asignada_id = $1, mesera_asignada_at = now()
       WHERE id = $2 AND sucursal_id = $3`,
      [meseraId, mesaId, sucursalId],
    );
  }

  resolverEstadoInicial(dto: CrearPedidoDto, creadoPorStaff?: boolean): string {
    if (creadoPorStaff) {
      if (dto.tipo === 'mesa' && !dto.mesa_id) {
        throw new BadRequestException('MESA_REQUERIDA');
      }
      if (dto.tipo === 'domicilio') {
        return 'pendiente';
      }
      return 'en_cocina';
    }
    if (dto.tipo === 'mesa') {
      return 'pendiente_aprobacion';
    }
    return 'pendiente';
  }

  async generarNumeroPedido(
    client: PoolClient,
    sucursalId: string,
  ): Promise<string> {
    const anio = Number(
      new Intl.DateTimeFormat('en', {
        timeZone: 'America/Bogota',
        year: 'numeric',
      }).format(new Date()),
    );
    // Serializa la numeración por sucursal/año dentro de la transacción de alta.
    // Sin este lock, dos canales concurrentes pueden calcular el mismo COUNT + 1.
    await client.query(`SELECT pg_advisory_xact_lock(hashtext($1::text))`, [
      `foody:pedido-numero:${sucursalId}:${anio}`,
    ]);
    const fila = await this.consultarUnoCliente<{ n: number }>(
      client,
      `SELECT COUNT(*)::int AS n FROM pedidos
       WHERE sucursal_id = $1
         AND created_at >= make_timestamptz($2::int, 1, 1, 0, 0, 0, 'America/Bogota')
         AND created_at < make_timestamptz($2::int + 1, 1, 1, 0, 0, 0, 'America/Bogota')`,
      [sucursalId, anio],
    );
    const secuencia = (fila?.n ?? 0) + 1;
    return `FDY-${anio}-${String(secuencia).padStart(4, '0')}`;
  }

  precioVentaProducto(
    producto: { precio: string; precio_para_llevar: string | null },
    tipoPedido: string,
  ): number {
    const local = Number(producto.precio);
    if (tipoPedido === 'para_llevar' || tipoPedido === 'domicilio') {
      return producto.precio_para_llevar != null
        ? Number(producto.precio_para_llevar)
        : local;
    }
    return local;
  }

  validarCancelacion(
    pedido: { estado: string; created_at: Date },
    rol: string,
    _permisos: string[],
    motivo?: string,
  ) {
    if (!motivo?.trim()) {
      throw new BadRequestException(
        'Se requiere un motivo para cancelar el pedido',
      );
    }
    const esElevado = esAdminRestaurante(rol) || rol === 'gerente';
    const estadosRestringidos = [
      'en_cocina',
      'listo',
      'asignado',
      'en_camino',
      'entregado',
      'pagado',
    ];
    if (estadosRestringidos.includes(pedido.estado) && !esElevado) {
      throw new BadRequestException(
        'Solo admin o gerente puede cancelar un pedido en esta etapa',
      );
    }
    const minutos =
      (Date.now() - new Date(pedido.created_at).getTime()) / 60000;
    if (minutos > 2 && !esElevado) {
      throw new BadRequestException(
        'Solo admin o gerente puede cancelar después de 2 minutos',
      );
    }
  }

  /** Cliente anónimo: solo antes de cocina; confirmado ≤ 2 min. */
  validarCancelacionCliente(
    pedido: { estado: string; created_at: Date },
    motivo?: string,
  ) {
    if (!motivo?.trim() || motivo.trim().length < 3) {
      throw new BadRequestException(
        'Indica un motivo de cancelación (mínimo 3 caracteres)',
      );
    }
    const bloqueados = [
      'en_cocina',
      'listo',
      'pagando',
      'asignado',
      'en_camino',
      'entregado',
      'pagado',
      'cancelado',
      'rechazado',
    ];
    if (bloqueados.includes(pedido.estado)) {
      throw new BadRequestException({
        error: 'CANCELAR_CLIENTE_NO_PERMITIDO',
        message: 'Ya no puedes cancelar este pedido. Contacta al restaurante.',
      });
    }
    if (pedido.estado === 'confirmado') {
      const minutos =
        (Date.now() - new Date(pedido.created_at).getTime()) / 60000;
      if (minutos > 2) {
        throw new BadRequestException(
          'Solo puedes cancelar en los primeros 2 minutos tras confirmar',
        );
      }
    }
  }

  /** Cliente anónimo: solo pedidos de mesa activos. */
  validarLlamadaMesera(pedido: { mesa_id: string | null; estado: string }) {
    if (!pedido.mesa_id) {
      throw new BadRequestException({
        error: 'LLAMADA_MESERA_NO_MESA',
        message: 'Solo puedes llamar a la mesera desde un pedido de mesa',
      });
    }
    const bloqueados = ['pagado', 'cancelado', 'rechazado', 'entregado'];
    if (bloqueados.includes(pedido.estado)) {
      throw new BadRequestException({
        error: 'LLAMADA_MESERA_NO_PERMITIDA',
        message: 'Este pedido ya está cerrado',
      });
    }
  }

  notificarLlamadaMesera(
    sucursalId: string,
    pedidoId: string,
    numeroPedido: string,
    mesaId: string | null,
    mesaNombre?: string | null,
    mensajeCliente?: string,
  ) {
    const num = numeroPedido ? `#${numeroPedido}` : '';
    const mesa = mesaNombre ? ` (${mesaNombre})` : '';
    const cuerpo =
      mensajeCliente?.trim() ||
      `Cliente en mesa${mesa} pide atención — pedido ${num}`;
    void this.notificaciones.enviar({
      sucursal_id: sucursalId,
      tipo: 'llamar_mesera',
      titulo: 'Cliente pide atención',
      cuerpo,
      roles: ['mesero', 'admin', 'gerente', 'cajero'],
      datos: {
        pedido_id: pedidoId,
        sucursal_id: sucursalId,
        mesa_id: mesaId ?? '',
        ruta: mesaId ? `/admin/mesero?mesa_id=${mesaId}` : '/admin/mesero',
      },
    });
    void this.realtime.mesasActualizadas(sucursalId);
    void this.realtime.llamarMesera(sucursalId, {
      pedido_id: pedidoId,
      mesa_id: mesaId ?? null,
      numero_pedido: numeroPedido,
    });
  }

  notificarDesasignacionesDomicilio(
    usuarioIds: string[],
    pedidoId: string,
    independientesIds: string[] = [],
  ) {
    for (const usuarioId of usuarioIds) {
      void this.realtime.pedidoDesasignado(usuarioId, {
        pedido_id: pedidoId,
        accion: 'cancelado',
      });
    }
    for (const domiciliarioId of independientesIds) {
      void this.realtime.pedidoDesasignadoIndep(domiciliarioId, {
        pedido_id: pedidoId,
        accion: 'cancelado',
      });
    }
  }

  notificarPedidoRealtime(
    sucursalId: string,
    pedidoId: string,
    estado: string,
    numeroPedido?: string,
    opciones: { mesaId?: string | null; creadoAt?: Date | string } = {},
  ) {
    void this.realtime.pedidoActualizado({
      pedido_id: pedidoId,
      sucursal_id: sucursalId,
      estado,
      numero_pedido: numeroPedido,
    });
    this.emitirSeguimientoPedido(pedidoId, { pedido_id: pedidoId, estado });
    if (estado === 'pendiente_aprobacion') {
      void this.realtime.mesasActualizadas(sucursalId);
      void this.realtime.qrAprobacionUrgente(sucursalId, {
        pedido_id: pedidoId,
        mesa_id: opciones.mesaId ?? null,
        numero_pedido: numeroPedido,
        creado_at:
          opciones.creadoAt != null
            ? new Date(opciones.creadoAt).toISOString()
            : new Date().toISOString(),
        nivel: 'nuevo',
      });
    }
    if (estado === 'pagado' && opciones.mesaId) {
      void this.realtime.mesasActualizadas(sucursalId);
    }
    void this.notificarPushPedido(
      sucursalId,
      pedidoId,
      estado,
      numeroPedido,
      opciones.mesaId,
    );
  }

  private notificarPushPedido(
    sucursalId: string,
    pedidoId: string,
    estado: string,
    numeroPedido?: string,
    mesaId?: string | null,
  ) {
    const num = numeroPedido ? `#${numeroPedido}` : 'nuevo';
    const base = {
      sucursal_id: sucursalId,
      datos: {
        pedido_id: pedidoId,
        sucursal_id: sucursalId,
        mesa_id: mesaId ?? '',
      },
    };

    if (estado === 'pendiente_aprobacion') {
      void this.notificaciones.enviar({
        ...base,
        tipo: 'qr_pendiente_aprobacion',
        titulo: 'Aprobar pedido de mesa',
        cuerpo: `Pedido ${num} espera aprobación QR`,
        roles: ['mesero', 'admin', 'gerente', 'cajero'],
        datos: {
          ...base.datos,
          ruta: mesaId ? `/admin/mesero?mesa_id=${mesaId}` : '/admin/mesero',
        },
      });
      return;
    }

    if (estado === 'pendiente') {
      void this.notificaciones.enviar({
        ...base,
        tipo: 'pedido_nuevo',
        titulo: 'Nuevo pedido',
        cuerpo: `Pedido ${num} por confirmar`,
        roles: ['cajero', 'admin', 'mesero'],
        datos: {
          ...base.datos,
          ruta: '/admin/panel?seccion=pedidos',
        },
      });
      return;
    }

    if (estado === 'confirmado' || estado === 'en_cocina') {
      void this.notificaciones.enviar({
        ...base,
        tipo: 'pedido_cocina',
        titulo: 'Nuevo pedido en cocina',
        cuerpo: `Pedido ${num} para preparar`,
        roles: ['cocina', 'admin'],
        datos: {
          ...base.datos,
          ruta: '/admin/cocina',
        },
      });
      if (estado === 'en_cocina' || estado === 'confirmado') {
        void this.notificarPushCliente(
          pedidoId,
          'Pedido en preparación',
          `Tu pedido ${num} está en cocina`,
        );
      }
      return;
    }

    if (estado === 'listo') {
      const qMesero = [
        'tab=pedidos',
        `pedido_id=${pedidoId}`,
        ...(mesaId ? [`mesa_id=${mesaId}`] : []),
      ].join('&');
      void this.notificaciones.enviar({
        ...base,
        tipo: 'pedido_listo',
        titulo: 'Pedido listo',
        cuerpo: `Pedido ${num} listo para servir`,
        roles: ['mesero', 'cajero', 'admin', 'domiciliario_planta'],
        datos: {
          ...base.datos,
          ruta: `/admin/mesero?${qMesero}`,
        },
      });
      void this.notificarPushCliente(
        pedidoId,
        'Tu pedido está listo',
        `Pedido ${num}`,
      );
      return;
    }

    if (estado === 'en_camino' || estado === 'asignado') {
      void this.notificarPushCliente(
        pedidoId,
        'Pedido en camino',
        `Tu pedido ${num} va hacia ti`,
      );
      return;
    }

    if (estado === 'entregado') {
      void this.notificarPushCliente(
        pedidoId,
        'Pedido entregado',
        `Pedido ${num} entregado. ¡Buen provecho!`,
      );
      return;
    }

    if (estado === 'cancelado' || estado === 'rechazado') {
      void this.notificarPushCliente(
        pedidoId,
        'Pedido cancelado',
        `Tu pedido ${num} fue cancelado`,
      );
    }
  }

  private async notificarPushCliente(
    pedidoId: string,
    titulo: string,
    cuerpo: string,
  ) {
    const pedido = await this.database.consultarUno<{
      device_id: string | null;
      sucursal_id: string;
    }>(`SELECT device_id, sucursal_id FROM pedidos WHERE id = $1`, [pedidoId]);
    if (!pedido?.device_id) return;
    await this.notificaciones.enviar({
      sucursal_id: pedido.sucursal_id,
      tipo: 'pedido_cliente',
      titulo,
      cuerpo,
      device_id: pedido.device_id,
      datos: {
        pedido_id: pedidoId,
        ruta: `/pedidos/${pedidoId}/seguimiento`,
      },
    });
  }

  notificarCatalogoDisponibilidad(
    sucursalId: string,
    cambios: { producto_id: string; disponible: boolean }[],
  ) {
    if (!cambios.length) return;
    const agotados = cambios
      .filter((c) => !c.disponible)
      .map((c) => c.producto_id);
    const reactivados = cambios
      .filter((c) => c.disponible)
      .map((c) => c.producto_id);
    if (agotados.length) {
      void this.realtime.catalogoDisponibilidad(sucursalId, {
        producto_ids: agotados,
        disponible: false,
      });
    }
    if (reactivados.length) {
      void this.realtime.catalogoDisponibilidad(sucursalId, {
        producto_ids: reactivados,
        disponible: true,
      });
    }
  }

  async notificarCocinasPorPedido(pedidoId: string, sucursalId: string) {
    try {
      const filas = await this.database.consultar<{ cocina_id: string }>(
        `SELECT DISTINCT estaciones.cocina_id
         FROM (
           SELECT pi.cocina_id
           FROM pedido_items pi
           INNER JOIN pedidos p ON p.id = pi.pedido_id
           WHERE pi.pedido_id = $1 AND p.sucursal_id = $2
             AND pi.cocina_id IS NOT NULL
             AND NOT EXISTS (
               SELECT 1 FROM pedido_combo_tareas_cocina t
               WHERE t.pedido_item_id = pi.id
             )
           UNION
           SELECT t.cocina_id
           FROM pedido_combo_tareas_cocina t
           WHERE t.pedido_id = $1 AND t.sucursal_id = $2
             AND t.estado <> 'cancelada'
         ) estaciones`,
        [pedidoId, sucursalId],
      );
      for (const f of filas) {
        void this.realtime
          .cocinaActualizada(f.cocina_id, {
            pedido_id: pedidoId,
            sucursal_id: sucursalId,
          })
          .catch((error: unknown) => {
            this.logger.warn(
              `Realtime de cocina falló para pedido ${pedidoId}: ${this.errorTexto(error)}`,
            );
          });
      }
    } catch (error) {
      this.logger.error(
        `No se pudieron resolver las cocinas del pedido ${pedidoId}: ${this.errorTexto(error)}`,
      );
    }
    try {
      await this.impresion.encolarPorPedido(pedidoId, sucursalId);
    } catch (error) {
      this.logger.error(
        `No se pudo solicitar impresión del pedido ${pedidoId}: ${this.errorTexto(error)}`,
      );
    }
  }

  private errorTexto(error: unknown): string {
    return error instanceof Error ? error.message : String(error);
  }
}
