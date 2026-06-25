import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';

@Injectable()
export class DashboardService {
  constructor(private readonly database: DatabaseService) {}

  async resumen(sucursalId: string) {
    const ventasHoy = await this.database.consultarUno<{ total: string }>(
      `SELECT COALESCE(SUM(total), 0)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND created_at::date = (NOW() AT TIME ZONE 'America/Bogota')::date
         AND estado NOT IN ('cancelado', 'rechazado')`,
      [sucursalId],
    );

    const pedidosActivos = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND estado IN (
           'pendiente_aprobacion', 'pendiente', 'confirmado',
           'en_cocina', 'listo', 'en_camino'
         )`,
      [sucursalId],
    );

    const pendientesQr = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1 AND estado = 'pendiente_aprobacion'`,
      [sucursalId],
    );

    const alertas = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM alertas_riesgo
       WHERE sucursal_id = $1 AND revisada = false`,
      [sucursalId],
    );

    const completadosHoy = await this.database.consultarUno<{ total: string }>(
      `SELECT COUNT(*)::text AS total
       FROM pedidos
       WHERE sucursal_id = $1
         AND estado = 'entregado'
         AND created_at::date = (NOW() AT TIME ZONE 'America/Bogota')::date`,
      [sucursalId],
    );

    return {
      ventas_hoy: Number(ventasHoy?.total ?? 0),
      pedidos_activos: Number(pedidosActivos?.total ?? 0),
      pedidos_pendientes_qr: Number(pendientesQr?.total ?? 0),
      pedidos_completados_hoy: Number(completadosHoy?.total ?? 0),
      alertas_pendientes: Number(alertas?.total ?? 0),
    };
  }
}
