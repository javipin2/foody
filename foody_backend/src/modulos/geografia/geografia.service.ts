import {
  BadGatewayException,
  Injectable,
  BadRequestException,
  GatewayTimeoutException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { esQaSinEfectosExternos } from '../../core/config/qa-safety';

type ResultadoBusqueda = {
  etiqueta: string;
  lat: number;
  lng: number;
};

@Injectable()
export class GeografiaService {
  private static readonly timeoutMs = 5000;
  private readonly cache = new Map<string, ResultadoBusqueda[]>();
  private readonly maxCache = 300;

  async buscarDirecciones(
    consulta: string,
    opciones: { lat?: number; lng?: number; limite?: number } = {},
  ): Promise<ResultadoBusqueda[]> {
    if (esQaSinEfectosExternos()) {
      throw new ServiceUnavailableException(
        'Geocodificación externa desactivada por FOODY_QA_SIN_EFECTOS',
      );
    }
    const q = consulta.trim();
    if (q.length < 3) {
      throw new BadRequestException(
        'La búsqueda debe tener al menos 3 caracteres',
      );
    }

    const claveCache = this.claveCache(q, opciones.lat, opciones.lng);
    const enCache = this.cache.get(claveCache);
    if (enCache) return enCache;

    const limite = Math.min(Math.max(opciones.limite ?? 8, 1), 15);
    const params = new URLSearchParams({
      q,
      lang: 'es',
      limit: String(limite),
    });
    if (opciones.lat != null && opciones.lng != null) {
      params.set('lat', String(opciones.lat));
      params.set('lon', String(opciones.lng));
    }

    const url = `https://photon.komoot.io/api/?${params.toString()}`;
    const signal = AbortSignal.timeout(GeografiaService.timeoutMs);
    let respuesta: Response;
    let datos: {
      features?: Array<{
        geometry?: { coordinates?: [number, number] };
        properties?: Record<string, string | undefined>;
      }>;
    };
    try {
      respuesta = await fetch(url, {
        headers: { Accept: 'application/json' },
        signal,
      });
      if (!respuesta.ok) {
        throw new BadGatewayException(
          'No se pudo consultar el servicio de direcciones',
        );
      }
      datos = (await respuesta.json()) as typeof datos;
    } catch (error) {
      if (
        signal.aborted ||
        (error instanceof Error && error.name === 'TimeoutError')
      ) {
        throw new GatewayTimeoutException(
          'El servicio de direcciones tardó demasiado. Intenta de nuevo.',
        );
      }
      if (
        error instanceof BadGatewayException ||
        error instanceof GatewayTimeoutException
      ) {
        throw error;
      }
      throw new BadGatewayException(
        'No fue posible conectar con el servicio de direcciones',
      );
    }

    const resultados: ResultadoBusqueda[] = (datos.features ?? [])
      .map((f) => {
        const coords = f.geometry?.coordinates;
        if (!coords || coords.length < 2) return null;
        const props = f.properties ?? {};
        const partes = [
          props.name,
          props.street,
          props.housenumber,
          props.district,
          props.city ?? props.state,
          props.country,
        ]
          .filter((p) => p && String(p).trim().length > 0)
          .map((p) => String(p).trim());
        const etiqueta = [...new Set(partes)].join(', ');
        if (!etiqueta) return null;
        return {
          etiqueta,
          lng: coords[0],
          lat: coords[1],
        };
      })
      .filter((r): r is ResultadoBusqueda => r != null);

    this.guardarCache(claveCache, resultados);
    return resultados;
  }

  private claveCache(q: string, lat?: number, lng?: number) {
    return `${q.toLowerCase()}|${lat ?? ''}|${lng ?? ''}`;
  }

  private guardarCache(clave: string, valor: ResultadoBusqueda[]) {
    if (this.cache.size >= this.maxCache) {
      const primera = this.cache.keys().next().value;
      if (primera) this.cache.delete(primera);
    }
    this.cache.set(clave, valor);
  }
}
