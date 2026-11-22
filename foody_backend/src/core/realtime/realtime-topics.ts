import { createHmac } from 'crypto';

/**
 * RT-SEC-01: topics staff opacos (HMAC).
 * Anon + UUID de sucursal (QR) ya no alcanza para unirse a caja/alertas.
 * Catálogo (`*_catalogo`) y `pedido_{id}_{token}` siguen públicos a propósito.
 *
 * ponytail: sin Realtime Authorization de Supabase (self-hosted frágil).
 * Upgrade: private:true + RLS en realtime.messages cuando VPS lo soporte bien.
 */
export type TipoCanalStaff =
  | 'sucursal'
  | 'cocina'
  | 'restaurante'
  | 'domiciliario'
  | 'domiciliario_indep';

export function pepperRealtime(env: {
  get: (clave: string) => string | undefined;
}): string {
  return (
    env.get('REALTIME_CANAL_PEPPER')?.trim() ||
    env.get('JWT_SECRET')?.trim() ||
    'foody_jwt_secret_cambiar'
  );
}

export function firmaCanal(
  pepper: string,
  tipo: TipoCanalStaff,
  id: string,
): string {
  return createHmac('sha256', pepper)
    .update(`${tipo}:${id}`)
    .digest('hex')
    .slice(0, 16);
}

export function topicStaff(
  pepper: string,
  tipo: TipoCanalStaff,
  id: string,
): string {
  return `${tipo}_${id}_${firmaCanal(pepper, tipo, id)}`;
}

export function topicCatalogoPublico(sucursalId: string): string {
  return `sucursal_${sucursalId}_catalogo`;
}

export function esTopicPublico(nombre: string): boolean {
  return (
    nombre === 'foody_health_check' ||
    nombre.endsWith('_catalogo') ||
    nombre.startsWith('pedido_')
  );
}
