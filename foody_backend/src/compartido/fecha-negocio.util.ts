export const ZONA_HORARIA_NEGOCIO = 'America/Bogota';

/** Fecha calendario del negocio, independiente de la zona horaria del proceso. */
export function fechaHoyNegocio(ahora: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA_HORARIA_NEGOCIO,
  }).format(ahora);
}
