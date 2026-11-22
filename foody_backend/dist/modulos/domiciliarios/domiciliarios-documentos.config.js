"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ETIQUETAS_DOCUMENTO_DOMICILIARIO = exports.TIPOS_DOCUMENTO_DOMICILIARIO = void 0;
exports.esTipoDocumentoDomiciliario = esTipoDocumentoDomiciliario;
exports.TIPOS_DOCUMENTO_DOMICILIARIO = [
    'cedula_frente',
    'cedula_reverso',
    'foto_vehiculo',
];
function esTipoDocumentoDomiciliario(tipo) {
    return exports.TIPOS_DOCUMENTO_DOMICILIARIO.includes(tipo);
}
exports.ETIQUETAS_DOCUMENTO_DOMICILIARIO = {
    cedula_frente: 'Cédula (frente)',
    cedula_reverso: 'Cédula (reverso)',
    foto_vehiculo: 'Foto del vehículo',
};
//# sourceMappingURL=domiciliarios-documentos.config.js.map