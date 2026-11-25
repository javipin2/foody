import { createHash, timingSafeEqual } from 'node:crypto';
import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';
import { SupabaseAuthService } from '../../core/auth/supabase-auth.service';

@Injectable()
export class DispositivosService {
  constructor(
    private readonly database: DatabaseService,
    private readonly supabaseAuth: SupabaseAuthService,
  ) {}

  async registrar(datos: {
    device_id: string;
    device_capability: string;
    fcm_token?: string;
    ciudad_id?: string;
    plataforma?: string;
  }) {
    const hash = this.hashCapability(datos.device_capability);
    const fila = await this.database.consultarUno<{ device_id: string }>(
      `INSERT INTO dispositivos_cliente
         (device_id, fcm_token, ciudad_id, plataforma, ultimo_acceso, capability_hash)
       VALUES ($1, $2, $3, $4, now(), $5)
       ON CONFLICT (device_id) DO UPDATE SET
         fcm_token = COALESCE(EXCLUDED.fcm_token, dispositivos_cliente.fcm_token),
         ciudad_id = COALESCE(EXCLUDED.ciudad_id, dispositivos_cliente.ciudad_id),
         plataforma = COALESCE(EXCLUDED.plataforma, dispositivos_cliente.plataforma),
         ultimo_acceso = now(),
         capability_hash = COALESCE(dispositivos_cliente.capability_hash, EXCLUDED.capability_hash)
       WHERE dispositivos_cliente.anonimizado = false
         AND (dispositivos_cliente.capability_hash IS NULL
           OR dispositivos_cliente.capability_hash = EXCLUDED.capability_hash)
       RETURNING device_id`,
      [
        datos.device_id,
        datos.fcm_token ?? null,
        datos.ciudad_id ?? null,
        datos.plataforma ?? 'android',
        hash,
      ],
    );
    return { device_id: datos.device_id, registrado: !!fila };
  }

  /** Autoriza un identificador público con el secreto independiente del device. */
  async verificarCapability(
    deviceId: string,
    capability: string,
  ): Promise<boolean> {
    if (!/^[a-f0-9]{64}$/i.test(capability)) return false;
    const fila = await this.database.consultarUno<{
      capability_hash: string | null;
      anonimizado: boolean;
    }>(
      `SELECT capability_hash, anonimizado
       FROM dispositivos_cliente
       WHERE device_id = $1`,
      [deviceId],
    );
    if (!fila || fila.anonimizado || !fila.capability_hash) return false;
    const esperado = Buffer.from(fila.capability_hash, 'hex');
    const recibido = Buffer.from(this.hashCapability(capability), 'hex');
    return (
      esperado.length === recibido.length && timingSafeEqual(esperado, recibido)
    );
  }

  async exigirCapability(deviceId: string, capability?: string): Promise<void> {
    if (
      !capability ||
      !(await this.verificarCapability(deviceId, capability))
    ) {
      throw new ForbiddenException({
        error: 'DISPOSITIVO_NO_AUTORIZADO',
        message: 'No se pudo comprobar la posesión de este dispositivo.',
      });
    }
  }

  /**
   * Vincula device_id → auth_uid (Google / Supabase) y reclama pedidos previos del device.
   * No crea fila en `usuarios` (eso es staff).
   */
  async vincularAuth(
    datos: { device_id: string; access_token: string },
    capability: string,
  ) {
    const deviceId = datos.device_id?.trim();
    if (!deviceId) {
      throw new BadRequestException('device_id es obligatorio');
    }
    await this.exigirCapability(deviceId, capability);
    const user = await this.supabaseAuth.usuarioDesdeAccessToken(
      datos.access_token,
    );
    const authUid = user.id;

    await this.database.consultar(
      `INSERT INTO dispositivos_cliente (device_id, auth_uid, ultimo_acceso, plataforma)
       VALUES ($1, $2::uuid, now(), 'android')
       ON CONFLICT (device_id) DO UPDATE SET
         auth_uid = EXCLUDED.auth_uid,
         ultimo_acceso = now()
       WHERE dispositivos_cliente.anonimizado = false`,
      [deviceId, authUid],
    );

    const reclamados = await this.database.consultarUno<{ n: string }>(
      `WITH u AS (
         UPDATE pedidos
         SET cliente_auth_uid = $2::uuid
         WHERE device_id = $1
           AND (cliente_auth_uid IS NULL OR cliente_auth_uid = $2::uuid)
         RETURNING id
       )
       SELECT count(*)::text AS n FROM u`,
      [deviceId, authUid],
    );

    return {
      device_id: deviceId,
      auth_uid: authUid,
      email: user.email ?? null,
      nombre:
        (user.user_metadata?.['full_name'] as string | undefined) ??
        (user.user_metadata?.['name'] as string | undefined) ??
        null,
      pedidos_vinculados: Number(reclamados?.n ?? 0),
    };
  }

  /**
   * Prueba de posesión: FCM token actual del device, o Supabase JWT del auth_uid vinculado.
   */
  async verificarPosesionParaAnonimizar(
    deviceId: string,
    prueba: { fcm_token?: string; access_token?: string },
  ): Promise<boolean> {
    const fila = await this.database.consultarUno<{
      fcm_token: string | null;
      auth_uid: string | null;
      anonimizado: boolean;
    }>(
      `SELECT fcm_token, auth_uid, anonimizado FROM dispositivos_cliente
       WHERE device_id = $1`,
      [deviceId],
    );
    if (!fila || fila.anonimizado) return false;

    if (
      prueba.fcm_token &&
      fila.fcm_token &&
      prueba.fcm_token === fila.fcm_token
    ) {
      return true;
    }

    if (prueba.access_token && fila.auth_uid) {
      try {
        const user = await this.supabaseAuth.usuarioDesdeAccessToken(
          prueba.access_token,
        );
        return !!user?.id && user.id === fila.auth_uid;
      } catch {
        return false;
      }
    }

    return false;
  }

  /** X-008 — GDPR: anonimiza device sin borrar fila (auditoría). */
  async anonimizar(deviceId: string) {
    const fila = await this.database.consultarUno<{ device_id: string }>(
      `UPDATE dispositivos_cliente
       SET fcm_token = NULL,
           ciudad_id = NULL,
           auth_uid = NULL,
           capability_hash = NULL,
           anonimizado = true,
           anonimizado_at = now()
       WHERE device_id = $1 AND anonimizado = false
       RETURNING device_id`,
      [deviceId],
    );
    if (!fila) {
      return {
        device_id: deviceId,
        anonimizado: false,
        motivo: 'no_encontrado',
      };
    }
    return { device_id: deviceId, anonimizado: true };
  }

  private hashCapability(capability: string): string {
    if (!/^[a-f0-9]{64}$/i.test(capability)) {
      throw new BadRequestException('device_capability no es válida');
    }
    return createHash('sha256').update(capability.toLowerCase()).digest('hex');
  }
}
