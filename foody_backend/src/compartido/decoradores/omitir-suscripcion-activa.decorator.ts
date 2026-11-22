import { SetMetadata } from '@nestjs/common';

export const OMITIR_SUSCRIPCION_ACTIVA_KEY = 'omitir_suscripcion_activa';

/** Rutas que deben funcionar con suscripción vencida/bloqueada (p. ej. pagos, perfil). */
export const OmitirSuscripcionActiva = () =>
  SetMetadata(OMITIR_SUSCRIPCION_ACTIVA_KEY, true);
