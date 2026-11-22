export const TIPOS_DOCUMENTO_DOMICILIARIO = [
  'cedula_frente',
  'cedula_reverso',
  'foto_vehiculo',
] as const;

export type TipoDocumentoDomiciliario =
  (typeof TIPOS_DOCUMENTO_DOMICILIARIO)[number];

export function esTipoDocumentoDomiciliario(
  tipo: string,
): tipo is TipoDocumentoDomiciliario {
  return (TIPOS_DOCUMENTO_DOMICILIARIO as readonly string[]).includes(tipo);
}

export const ETIQUETAS_DOCUMENTO_DOMICILIARIO: Record<
  TipoDocumentoDomiciliario,
  string
> = {
  cedula_frente: 'Cédula (frente)',
  cedula_reverso: 'Cédula (reverso)',
  foto_vehiculo: 'Foto del vehículo',
};
