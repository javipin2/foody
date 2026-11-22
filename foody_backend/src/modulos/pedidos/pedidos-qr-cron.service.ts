import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { UMBRALES_ALERTA } from '../alertas/alertas-riesgo.service';
import { AuditoriaService } from '../auditoria/auditoria.service';
import { DatabaseService } from '../../core/database/database.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';
import { NotificacionesService } from '../notificaciones/notificaciones.service';

/** P2-03: recordatorio FCM si QR `pendiente_aprobacion` supera N minutos sin aprobar. */
@Injectable()
export class PedidosQrCronService implements OnModuleInit {
  private readonly logger = new Logger(PedidosQrCronService.name);
  private ejecutando = false;
  private readonly LOCK_PEDIDOS_QR_CRON = 9200005;

  constructor(
    private readonly database: DatabaseService,
    private readonly notificaciones: NotificacionesService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly auditoria: AuditoriaService,
  ) {}

  onModuleInit() {
    setInterval(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_PEDIDOS_QR_CRON,
          () => this.ejecutar(),
        ),
      60_000,
    );
    setTimeout(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_PEDIDOS_QR_CRON,
          () => this.ejecutar(),
        ),
      15_000,
    );
  }

  async ejecutar(): Promise<number> {
    if (this.ejecutando) return 0;
    this.ejecutando = true;
    try {
      const minutos = UMBRALES_ALERTA.qrRecordatorioAprobacionMinutos;
      const pendientes = await this.database.consultar<{
        id: string;
        sucursal_id: string;
        mesa_id: string | null;
        numero_pedido: string;
        created_at: Date;
        mesa_nombre: string | null;
      }>(
        `SELECT p.id, p.sucursal_id, p.mesa_id, p.numero_pedido, p.created_at,
                m.nombre AS mesa_nombre
         FROM pedidos p
         LEFT JOIN mesas m ON m.id = p.mesa_id
         WHERE p.estado = 'pendiente_aprobacion'
           AND p.created_at < now() - ($1::text || ' minutes')::interval
           AND NOT EXISTS (
             SELECT 1 FROM auditoria_logs a
             WHERE a.registro_id = p.id
               AND a.accion = 'QR_RECORDATORIO_APROBACION'
               AND a.created_at > now() - ($1::text || ' minutes')::interval
           )`,
        [String(minutos)],
      );

      for (const p of pendientes) {
        const num = p.numero_pedido ? `#${p.numero_pedido}` : 'QR';
        const mesa = p.mesa_nombre ? ` · ${p.mesa_nombre}` : '';
        const minEspera = Math.max(
          minutos,
          Math.floor(
            (Date.now() - new Date(p.created_at).getTime()) / 60_000,
          ),
        );
        const nivelUrgente = UMBRALES_ALERTA.qrUrgenteAprobacionMinutos;
        const nivel =
          minEspera >= nivelUrgente ? 'urgente_5min' : 'advertencia_3min';

        await this.auditoria.registrar({
          sucursalId: p.sucursal_id,
          accion: 'QR_RECORDATORIO_APROBACION',
          tablaAfectada: 'pedidos',
          registroId: p.id,
          datosDespues: {
            minutos_espera: minEspera,
            mesa_id: p.mesa_id,
          },
        });

        void this.notificaciones.enviar({
          sucursal_id: p.sucursal_id,
          tipo: 'qr_recordatorio_aprobacion',
          titulo: 'QR sin aprobar',
          cuerpo: `Pedido ${num}${mesa} lleva ${minEspera} min esperando`,
          roles: ['mesero', 'admin', 'gerente', 'cajero'],
          datos: {
            pedido_id: p.id,
            sucursal_id: p.sucursal_id,
            mesa_id: p.mesa_id ?? '',
            ruta: '/admin/mesero',
          },
        });

        void this.realtime.qrAprobacionUrgente(p.sucursal_id, {
          pedido_id: p.id,
          mesa_id: p.mesa_id,
          numero_pedido: p.numero_pedido,
          creado_at: new Date(p.created_at).toISOString(),
          nivel,
        });
      }

      if (pendientes.length > 0) {
        this.logger.debug(
          `QR recordatorio: ${pendientes.length} pedido(s) (> ${minutos} min)`,
        );
      }
      return pendientes.length;
    } finally {
      this.ejecutando = false;
    }
  }
}
