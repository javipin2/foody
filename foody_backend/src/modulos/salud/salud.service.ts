import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../core/database/database.service';

@Injectable()
export class SaludService {
  constructor(private readonly database: DatabaseService) {}

  async verificar() {
    const fila = await this.database.consultarUno<{ ok: number }>(
      'SELECT 1 AS ok',
    );
    return {
      api: 'foody',
      version: '2026-06-04f',
      base_datos: fila?.ok === 1,
      entorno: process.env.ENTORNO ?? 'desarrollo',
      modulos: {
        mesas: ['GET listar', 'POST crear', 'GET qr', 'POST transferir', 'PATCH', 'DELETE'],
        menu_mesa_qr: 'GET /menu/mesa/:qr_token',
        cocinas: ['GET /cocinas/:sucursal', 'POST', 'PATCH', 'DELETE'],
        impresoras: ['GET /impresoras/:sucursal', 'POST', 'PATCH', 'DELETE'],
        kds: ['GET /cocina/cocinas', 'GET /cocina/tickets/:cocina_id', 'PATCH /cocina/items/:id/estado'],
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
}
