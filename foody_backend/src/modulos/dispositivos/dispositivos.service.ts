import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';

@Injectable()
export class DispositivosService {
  constructor(private readonly database: DatabaseService) {}

  async registrar(datos: {
    device_id: string;
    fcm_token?: string;
    ciudad_id?: string;
    plataforma?: string;
  }) {
    await this.database.consultar(
      `INSERT INTO dispositivos_cliente (device_id, fcm_token, ciudad_id, plataforma, ultimo_acceso)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (device_id) DO UPDATE SET
         fcm_token = COALESCE(EXCLUDED.fcm_token, dispositivos_cliente.fcm_token),
         ciudad_id = COALESCE(EXCLUDED.ciudad_id, dispositivos_cliente.ciudad_id),
         plataforma = COALESCE(EXCLUDED.plataforma, dispositivos_cliente.plataforma),
         ultimo_acceso = now()
       WHERE dispositivos_cliente.anonimizado = false`,
      [
        datos.device_id,
        datos.fcm_token ?? null,
        datos.ciudad_id ?? null,
        datos.plataforma ?? 'android',
      ],
    );
    return { device_id: datos.device_id, registrado: true };
  }

  /** X-008 — GDPR: anonimiza device sin borrar fila (auditoría). */
  async anonimizar(deviceId: string) {
    const fila = await this.database.consultarUno<{ device_id: string }>(
      `UPDATE dispositivos_cliente
       SET fcm_token = NULL,
           ciudad_id = NULL,
           plataforma = 'anonimo',
           anonimizado = true,
           anonimizado_at = now()
       WHERE device_id = $1 AND anonimizado = false
       RETURNING device_id`,
      [deviceId],
    );
    if (!fila) {
      return { device_id: deviceId, anonimizado: false, motivo: 'no_encontrado' };
    }
    return { device_id: deviceId, anonimizado: true };
  }
}
