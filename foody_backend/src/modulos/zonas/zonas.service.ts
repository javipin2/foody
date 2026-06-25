import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient } from 'pg';
import { DatabaseService } from '../../core/database/database.service';
import {
  ActualizarZonaDto,
  CrearZonaDto,
} from './dto/zona.dto';

const COSTO_DOMICILIO_DEFAULT = 5000;

@Injectable()
export class ZonasService {
  constructor(private readonly database: DatabaseService) {}

  listar(sucursalId: string) {
    return this.database.consultar(
      `SELECT id, nombre, costo_domicilio, distancia_max_km, activa, created_at
       FROM zonas_cobertura
       WHERE sucursal_id = $1
       ORDER BY distancia_max_km ASC, nombre ASC`,
      [sucursalId],
    );
  }

  /** Sucursal + anillos de cobertura para el mapa admin. */
  async configuracionMapa(sucursalId: string) {
    const sucursal = await this.database.consultarUno<{
      id: string;
      nombre: string;
      direccion: string | null;
      lat: string | null;
      lng: string | null;
    }>(
      `SELECT id, nombre, direccion, lat, lng
       FROM sucursales
       WHERE id = $1 AND activa = true`,
      [sucursalId],
    );
    if (!sucursal) throw new NotFoundException('Sucursal no encontrada');

    const zonas = await this.listar(sucursalId);

    return {
      sucursal: {
        id: sucursal.id,
        nombre: sucursal.nombre,
        direccion: sucursal.direccion,
        lat: sucursal.lat != null ? Number(sucursal.lat) : null,
        lng: sucursal.lng != null ? Number(sucursal.lng) : null,
      },
      zonas,
    };
  }

  async actualizarUbicacionSucursal(
    sucursalId: string,
    lat: number,
    lng: number,
  ) {
    const fila = await this.database.consultarUno<{ id: string }>(
      `UPDATE sucursales
       SET lat = $1, lng = $2
       WHERE id = $3 AND activa = true
       RETURNING id`,
      [lat, lng, sucursalId],
    );
    if (!fila) throw new NotFoundException('Sucursal no encontrada');
    return { id: fila.id, lat, lng };
  }

  async crear(dto: CrearZonaDto) {
    return this.database.consultarUno(
      `INSERT INTO zonas_cobertura (
         sucursal_id, nombre, costo_domicilio, distancia_max_km, activa
       ) VALUES ($1, $2, $3, $4, true)
       RETURNING id, nombre, costo_domicilio, distancia_max_km, activa`,
      [dto.sucursal_id, dto.nombre.trim(), dto.costo_domicilio, dto.distancia_max_km],
    );
  }

  async actualizar(id: string, sucursalId: string, dto: ActualizarZonaDto) {
    await this.exigirZona(id, sucursalId);
    const campos: string[] = [];
    const valores: unknown[] = [];
    let i = 1;
    if (dto.nombre !== undefined) {
      campos.push(`nombre = $${i++}`);
      valores.push(dto.nombre.trim());
    }
    if (dto.costo_domicilio !== undefined) {
      campos.push(`costo_domicilio = $${i++}`);
      valores.push(dto.costo_domicilio);
    }
    if (dto.distancia_max_km !== undefined) {
      campos.push(`distancia_max_km = $${i++}`);
      valores.push(dto.distancia_max_km);
    }
    if (dto.activa !== undefined) {
      campos.push(`activa = $${i++}`);
      valores.push(dto.activa);
    }
    if (!campos.length) return { id };
    valores.push(id, sucursalId);
    await this.database.consultar(
      `UPDATE zonas_cobertura SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`,
      valores,
    );
    return { id };
  }

  async desactivar(id: string, sucursalId: string) {
    await this.exigirZona(id, sucursalId);
    await this.database.consultar(
      `UPDATE zonas_cobertura SET activa = false WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    return { id, activa: false };
  }

  /** Cotiza costo de domicilio según distancia a la sucursal y zonas activas. */
  async cotizarDomicilio(
    sucursalId: string,
    lat?: number,
    lng?: number,
  ) {
    const resultado = await this.calcularCostoDomicilio(
      null,
      sucursalId,
      lat,
      lng,
    );
    return resultado;
  }

  async calcularCostoDomicilio(
    client: PoolClient | null,
    sucursalId: string,
    lat?: number | null,
    lng?: number | null,
  ): Promise<{
    costo: number;
    zona_id: string | null;
    zona_nombre: string | null;
    distancia_km: number | null;
    fuente: 'zona' | 'default';
  }> {
    const query = client
      ? (sql: string, params: unknown[]) => client.query(sql, params)
      : (sql: string, params: unknown[]) => this.database.consultar(sql, params);

    const sucursalRes = await query(
      `SELECT lat, lng FROM sucursales WHERE id = $1 AND activa = true`,
      [sucursalId],
    );
    const sucursal = client
      ? (sucursalRes as { rows: { lat: string | null; lng: string | null }[] }).rows[0]
      : (sucursalRes as { lat: string | null; lng: string | null }[])[0];

    const zonasRes = await query(
      `SELECT id, nombre, costo_domicilio, distancia_max_km
       FROM zonas_cobertura
       WHERE sucursal_id = $1 AND activa = true
       ORDER BY distancia_max_km ASC`,
      [sucursalId],
    );
    const zonas = client
      ? (zonasRes as { rows: { id: string; nombre: string; costo_domicilio: string; distancia_max_km: string }[] }).rows
      : (zonasRes as { id: string; nombre: string; costo_domicilio: string; distancia_max_km: string }[]);

    if (!zonas.length) {
      return {
        costo: COSTO_DOMICILIO_DEFAULT,
        zona_id: null,
        zona_nombre: null,
        distancia_km: null,
        fuente: 'default',
      };
    }

    let distanciaKm: number | null = null;
    if (
      lat != null &&
      lng != null &&
      sucursal?.lat != null &&
      sucursal?.lng != null
    ) {
      distanciaKm = this.distanciaKm(
        Number(sucursal.lat),
        Number(sucursal.lng),
        lat,
        lng,
      );
      for (const z of zonas) {
        if (distanciaKm <= Number(z.distancia_max_km)) {
          return {
            costo: Number(z.costo_domicilio),
            zona_id: z.id,
            zona_nombre: z.nombre,
            distancia_km: Math.round(distanciaKm * 100) / 100,
            fuente: 'zona',
          };
        }
      }
      throw new BadRequestException({
        error: 'FUERA_DE_COBERTURA',
        message: `La dirección está fuera de cobertura (máx. ${zonas[zonas.length - 1].distancia_max_km} km)`,
        distancia_km: Math.round(distanciaKm * 100) / 100,
      });
    }

    // Sin GPS: usar la zona más económica (radio menor) como estimado
    const zona = zonas[0];
    return {
      costo: Number(zona.costo_domicilio),
      zona_id: zona.id,
      zona_nombre: zona.nombre,
      distancia_km: null,
      fuente: 'zona',
    };
  }

  private distanciaKm(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const R = 6371;
    const dLat = this.toRad(lat2 - lat1);
    const dLng = this.toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(this.toRad(lat1)) *
        Math.cos(this.toRad(lat2)) *
        Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  private toRad(deg: number) {
    return (deg * Math.PI) / 180;
  }

  private async exigirZona(id: string, sucursalId: string) {
    const z = await this.database.consultarUno(
      `SELECT id FROM zonas_cobertura WHERE id = $1 AND sucursal_id = $2`,
      [id, sucursalId],
    );
    if (!z) throw new NotFoundException('Zona no encontrada');
  }

  async obtenerSucursalIdDeZona(zonaId: string): Promise<string> {
    const fila = await this.database.consultarUno<{ sucursal_id: string }>(
      `SELECT sucursal_id FROM zonas_cobertura WHERE id = $1`,
      [zonaId],
    );
    if (!fila) throw new NotFoundException('Zona no encontrada');
    return fila.sucursal_id;
  }
}
