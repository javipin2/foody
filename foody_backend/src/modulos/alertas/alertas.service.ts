import { Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';

@Injectable()
export class AlertasService {
  constructor(private readonly database: DatabaseService) {}

  async listar(sucursalId: string, soloPendientes = true) {
    const filtro = soloPendientes ? 'AND revisada = false' : '';
    return this.database.consultar(
      `SELECT id, tipo, nivel, descripcion, referencia_id, referencia_tipo,
              revisada, revisada_at, created_at
       FROM alertas_riesgo
       WHERE sucursal_id = $1 ${filtro}
       ORDER BY
         CASE nivel
           WHEN 'critico' THEN 1
           WHEN 'alto' THEN 2
           WHEN 'medio' THEN 3
           ELSE 4
         END,
         created_at DESC
       LIMIT 100`,
      [sucursalId],
    );
  }

  async revisar(alertaId: string, sucursalId: string, usuarioId: string) {
    const fila = await this.database.consultarUno<{ id: string }>(
      `UPDATE alertas_riesgo
       SET revisada = true,
           revisada_por = $3,
           revisada_at = now()
       WHERE id = $1 AND sucursal_id = $2 AND revisada = false
       RETURNING id`,
      [alertaId, sucursalId, usuarioId],
    );
    if (!fila) {
      throw new NotFoundException('Alerta no encontrada o ya revisada');
    }
    return { id: alertaId, revisada: true };
  }
}
