import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { NotificacionesService } from '../../modulos/notificaciones/notificaciones.service';
import { PagosRecurrentesService } from '../../modulos/pagos/pagos-recurrentes.service';
import { esQaSinEfectosExternos } from '../config/qa-safety';

type SuscripcionAviso = {
  id: string;
  restaurante_id: string;
  plan: string;
  estado: string;
  fecha_vencimiento: Date;
  restaurante_nombre: string;
  sucursal_id: string | null;
};

/** Cron suscripciones: vencer, bloquear tras gracia, avisos FCM (F4). */
@Injectable()
export class SuscripcionesCronService implements OnModuleInit {
  private readonly logger = new Logger(SuscripcionesCronService.name);
  private readonly LOCK_SUSCRIPCIONES_CRON = 9200002;

  constructor(
    private readonly database: DatabaseService,
    private readonly notificaciones: NotificacionesService,
    private readonly pagosRecurrentes: PagosRecurrentesService,
  ) {}

  onModuleInit() {
    if (esQaSinEfectosExternos()) {
      this.logger.warn('Cron de suscripciones pausado por FOODY_QA_SIN_EFECTOS');
      return;
    }
    void this.database.intentarAdvisoryLock(
      this.LOCK_SUSCRIPCIONES_CRON,
      () => this.ejecutar(),
    );
    setInterval(
      () =>
        void this.database.intentarAdvisoryLock(
          this.LOCK_SUSCRIPCIONES_CRON,
          () => this.ejecutar(),
        ),
      60 * 60 * 1000,
    );
  }

  async ejecutar(): Promise<{
    vencidas: number;
    bloqueadas: number;
    avisos3d: number;
    avisosHoy: number;
    renovaciones: number;
    renovaciones_fallos: number;
  }> {
    const renov = await this.procesarRenovacionesAutomaticas();
    const avisos = await this.enviarAvisosVencimiento();
    const vencidas = await this.marcarVencidas();
    const bloqueadas = await this.bloquearTrasGracia();
    return {
      vencidas,
      bloqueadas,
      renovaciones: renov.ok,
      renovaciones_fallos: renov.fallos,
      ...avisos,
    };
  }

  private async procesarRenovacionesAutomaticas(): Promise<{
    ok: number;
    fallos: number;
  }> {
    const candidatas =
      await this.pagosRecurrentes.listarCandidatasRenovacionAutomatica();
    let ok = 0;
    let fallos = 0;
    for (const c of candidatas) {
      try {
        const resultado = await this.pagosRecurrentes.intentarCobroRenovacion(
          c.restaurante_id,
          c.plan as 'basico' | 'pro' | 'enterprise',
        );
        if (resultado.iniciado) {
          ok++;
          this.logger.log(
            `Renovación automática restaurante=${c.restaurante_id} plan=${c.plan} → ${resultado.motivo}`,
          );
        }
      } catch (e) {
        fallos++;
        this.logger.error(
          `Renovación automática falló restaurante=${c.restaurante_id}: ${e instanceof Error ? e.message : e}`,
        );
      }
    }
    if (ok > 0 || fallos > 0) {
      this.logger.log(
        `Renovaciones automáticas: iniciadas=${ok} fallos=${fallos}`,
      );
    }
    return { ok, fallos };
  }

  private async marcarVencidas(): Promise<number> {
    const filas = await this.database.consultar<{ id: string }>(
      `UPDATE suscripciones_restaurante
       SET estado = 'vencida'
       WHERE estado IN ('activa', 'prueba')
         AND plan <> 'gratis'
         AND fecha_vencimiento IS NOT NULL
         AND fecha_vencimiento < now()
       RETURNING id`,
    );
    const n = filas.length;
    if (n > 0) {
      this.logger.log(`Suscripciones marcadas vencidas: ${n}`);
    }
    return n;
  }

  private async bloquearTrasGracia(): Promise<number> {
    const dias = await this.diasGraciaBloqueo();
    const filas = await this.database.consultar<{ id: string }>(
      `UPDATE suscripciones_restaurante
       SET estado = 'bloqueada',
           motivo_bloqueo = COALESCE(motivo_bloqueo, 'Período de gracia finalizado tras vencimiento')
       WHERE estado = 'vencida'
         AND plan <> 'gratis'
         AND fecha_vencimiento < now() - ($1::int * interval '1 day')
       RETURNING id`,
      [dias],
    );
    const n = filas.length;
    if (n > 0) {
      this.logger.log(`Suscripciones bloqueadas tras ${dias} días: ${n}`);
    }
    return n;
  }

  private async enviarAvisosVencimiento(): Promise<{
    avisos3d: number;
    avisosHoy: number;
  }> {
    const avisos3d = await this.enviarAviso3Dias();
    const avisosHoy = await this.enviarAvisoVenceHoy();
    return { avisos3d, avisosHoy };
  }

  private async enviarAviso3Dias(): Promise<number> {
    const filas = await this.listarParaAviso3Dias();
    let enviados = 0;
    for (const s of filas) {
      const ok = await this.pushAviso(s, {
        titulo: 'Tu plan Foody vence pronto',
        cuerpo: `«${s.restaurante_nombre}»: tu plan ${s.plan} vence en 3 días. Renueva para no perder acceso.`,
        tipo: 'suscripcion_aviso_3d',
      });
      if (ok) {
        await this.database.consultar(
          `UPDATE suscripciones_restaurante
           SET aviso_3d_enviado_at = now()
           WHERE id = $1`,
          [s.id],
        );
        enviados++;
      }
    }
    if (enviados > 0) {
      this.logger.log(`Avisos 3 días antes enviados: ${enviados}`);
    }
    return enviados;
  }

  private async enviarAvisoVenceHoy(): Promise<number> {
    const filas = await this.listarParaAvisoHoy();
    let enviados = 0;
    for (const s of filas) {
      const ok = await this.pushAviso(s, {
        titulo: 'Tu plan Foody vence hoy',
        cuerpo: `«${s.restaurante_nombre}»: hoy vence tu plan ${s.plan}. Renueva para seguir operando.`,
        tipo: 'suscripcion_aviso_hoy',
      });
      if (ok) {
        await this.database.consultar(
          `UPDATE suscripciones_restaurante
           SET aviso_vence_hoy_enviado_at = now()
           WHERE id = $1`,
          [s.id],
        );
        enviados++;
      }
    }
    if (enviados > 0) {
      this.logger.log(`Avisos vencimiento hoy enviados: ${enviados}`);
    }
    return enviados;
  }

  private async listarParaAviso3Dias(): Promise<SuscripcionAviso[]> {
    return this.database.consultar<SuscripcionAviso>(
      `SELECT s.id, s.restaurante_id, s.plan, s.estado, s.fecha_vencimiento,
              r.nombre AS restaurante_nombre,
              (
                SELECT u.sucursal_id FROM usuarios u
                WHERE u.restaurante_id = s.restaurante_id
                  AND u.rol IN ('admin', 'gerente_cadena') AND u.activo = true
                ORDER BY CASE WHEN u.rol = 'admin' THEN 0 ELSE 1 END, u.created_at ASC
                LIMIT 1
              ) AS sucursal_id
       FROM suscripciones_restaurante s
       INNER JOIN restaurantes r ON r.id = s.restaurante_id
       WHERE s.estado IN ('activa', 'prueba')
         AND s.plan <> 'gratis'
         AND s.aviso_3d_enviado_at IS NULL
         AND s.fecha_vencimiento::date = (CURRENT_DATE + 3)`,
    );
  }

  private async listarParaAvisoHoy(): Promise<SuscripcionAviso[]> {
    return this.database.consultar<SuscripcionAviso>(
      `SELECT s.id, s.restaurante_id, s.plan, s.estado, s.fecha_vencimiento,
              r.nombre AS restaurante_nombre,
              (
                SELECT u.sucursal_id FROM usuarios u
                WHERE u.restaurante_id = s.restaurante_id
                  AND u.rol IN ('admin', 'gerente_cadena') AND u.activo = true
                ORDER BY CASE WHEN u.rol = 'admin' THEN 0 ELSE 1 END, u.created_at ASC
                LIMIT 1
              ) AS sucursal_id
       FROM suscripciones_restaurante s
       INNER JOIN restaurantes r ON r.id = s.restaurante_id
       WHERE s.estado IN ('activa', 'prueba')
         AND s.plan <> 'gratis'
         AND s.aviso_vence_hoy_enviado_at IS NULL
         AND s.fecha_vencimiento::date = CURRENT_DATE
         AND s.fecha_vencimiento > now()`,
    );
  }

  private async pushAviso(
    s: SuscripcionAviso,
    msg: { titulo: string; cuerpo: string; tipo: string },
  ): Promise<boolean> {
    if (!s.sucursal_id) return false;
    try {
      await this.notificaciones.enviar({
        sucursal_id: s.sucursal_id,
        tipo: msg.tipo,
        titulo: msg.titulo,
        cuerpo: msg.cuerpo,
        roles: ['admin'],
        datos: {
          restaurante_id: s.restaurante_id,
          plan: s.plan,
          fecha_vencimiento: s.fecha_vencimiento.toISOString(),
        },
      });
      return true;
    } catch (e) {
      this.logger.warn(
        `No se pudo enviar aviso suscripción ${s.id}: ${e instanceof Error ? e.message : e}`,
      );
      return false;
    }
  }

  private async diasGraciaBloqueo(): Promise<number> {
    const fila = await this.database.consultarUno<{ valor: string }>(
      `SELECT valor FROM configuracion_global_foody
       WHERE clave = 'dias_datos_restaurante_bloqueado'`,
    );
    const n = Number(fila?.valor ?? 30);
    return Number.isFinite(n) && n > 0 ? n : 30;
  }
}
