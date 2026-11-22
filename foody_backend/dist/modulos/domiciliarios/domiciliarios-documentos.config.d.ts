export declare const TIPOS_DOCUMENTO_DOMICILIARIO: readonly ["cedula_frente", "cedula_reverso", "foto_vehiculo"];
export type TipoDocumentoDomiciliario = (typeof TIPOS_DOCUMENTO_DOMICILIARIO)[number];
export declare function esTipoDocumentoDomiciliario(tipo: string): tipo is TipoDocumentoDomiciliario;
export declare const ETIQUETAS_DOCUMENTO_DOMICILIARIO: Record<TipoDocumentoDomiciliario, string>;
