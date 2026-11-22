import { Injectable } from '@nestjs/common';
import { esProduccion } from '../../core/config/validar-config-produccion';
import { DatabaseService } from '../../core/database/database.service';
import { ImpresionService } from '../../core/impresion/impresion.service';
import { RealtimeBroadcastService } from '../../core/realtime/realtime-broadcast.service';

@Injectable()
export class SaludService {
  constructor(
    private readonly database: DatabaseService,
    private readonly realtime: RealtimeBroadcastService,
    private readonly impresion: ImpresionService,
  ) {}

  async verificar() {
    const fila = await this.database.consultarUno<{ ok: number }>(
      'SELECT 1 AS ok',
    );
    const base = {
      api: 'foody',
      version: '2026-07-01',
      base_datos: fila?.ok === 1,
      entorno: process.env.ENTORNO ?? 'desarrollo',
      timestamp: new Date().toISOString(),
    };
    if (esProduccion()) {
      return base;
    }
    return {
      ...base,
      modulos: {
        mesas: ['GET listar', 'POST crear', 'GET qr', 'POST transferir', 'PATCH', 'DELETE'],
        menu_mesa_qr: 'GET /menu/mesa/:qr_token',
        cocinas: ['GET /cocinas/:sucursal', 'POST', 'PATCH', 'DELETE'],
        impresoras: ['GET /impresoras/:sucursal', 'POST', 'PATCH', 'DELETE'],
        kds: ['GET /cocina/cocinas', 'GET /cocina/tickets/:cocina_id', 'PATCH /cocina/items/:id/estado', 'POST /cocina/items/:id/fallo-preparacion'],
        zonas: [
          'GET /zonas/cotizar-domicilio',
          'GET /zonas/sucursal/:id/configuracion-mapa',
          'PATCH /zonas/sucursal/:id/ubicacion',
          'GET /zonas/:sucursal',
          'POST',
          'PATCH',
          'DELETE',
        ],
        geografia: ['GET /geografia/buscar (Photon OSM)'],
        pedidos_dinero: ['POST /pedidos/:id/descuento', 'IVA en crear pedido', 'cancelación con reglas'],
        super_admin: [
          'POST /super/restaurantes',
          'GET/POST/PATCH /super/usuarios',
          'PATCH /super/configuracion/:clave',
          'GET /super/estadisticas',
          'documentos domiciliario',
        ],
        sucursales_staff: ['GET /sucursales/mi-restaurante', 'POST /sucursales'],
      },
    };
  }
  async verificarCompleto() {
    const fila = await this.database.consultarUno<{ ok: number }>(
      'SELECT 1 AS ok',
    );
    const baseDatos = fila?.ok === 1;

    const [realtime, agente, cola] = await Promise.all([
      this.realtime.verificarConexion(),
      this.impresion.verificarAgente(),
      this.impresion.estadisticasCola(),
    ]);

    const alertas: string[] = [];
    if (!baseDatos) alertas.push('base_datos_no_responde');
    if (!realtime.conectado) {
      alertas.push(
        realtime.configurado
          ? 'realtime_desconectado'
          : 'realtime_no_configurado',
      );
    }
    if (!agente.conectado) alertas.push('agente_impresion_offline');
    if (cola.error > 0) alertas.push(`cola_impresion_errores:${cola.error}`);
    if (cola.pendientes > 20) {
      alertas.push(`cola_impresion_pendientes:${cola.pendientes}`);
    }

    const estado = !baseDatos
      ? 'critico'
      : alertas.length > 0
        ? 'degradado'
        : 'ok';

    return {
      estado,
      api: 'foody',
      version: '2026-07-01',
      entorno: process.env.ENTORNO ?? 'desarrollo',
      timestamp: new Date().toISOString(),
      base_datos: baseDatos,
      realtime,
      impresion: { agente, cola },
      alertas,
    };
  }
}
