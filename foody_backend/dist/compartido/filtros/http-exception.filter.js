"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.HttpExceptionFilter = void 0;
const common_1 = require("@nestjs/common");
const MENSAJES_NEGOCIO = {
    RESTAURANTE_CERRADO: 'El restaurante está cerrado en este momento.',
    PRODUCTO_NO_DISPONIBLE: 'Un producto del pedido ya no está disponible.',
    COMBO_NO_DISPONIBLE: 'El combo seleccionado ya no está disponible.',
    TOPPING_NO_DISPONIBLE: 'Un topping seleccionado ya no está disponible.',
    BEBIDA_NO_DISPONIBLE: 'Una bebida seleccionada ya no está disponible.',
    STOCK_INSUFICIENTE: 'No hay suficiente stock para preparar este pedido. Intenta con menos cantidad.',
    MESA_NO_ENCONTRADA: 'La mesa indicada no existe o no está activa.',
    FUERA_DE_COBERTURA: 'La dirección de entrega está fuera de la zona de domicilio.',
    MESA_ASIGNADA_OTRA_MESERA: 'Esta mesa la está atendiendo otra mesera.',
};
let HttpExceptionFilter = class HttpExceptionFilter {
    catch(exception, host) {
        const ctx = host.switchToHttp();
        const response = ctx.getResponse();
        let status = common_1.HttpStatus.INTERNAL_SERVER_ERROR;
        let error = 'ERROR_INTERNO';
        let mensaje = 'Ocurrió un error inesperado';
        if (exception instanceof common_1.HttpException) {
            status = exception.getStatus();
            const cuerpo = exception.getResponse();
            if (typeof cuerpo === 'string') {
                mensaje = cuerpo;
            }
            else if (typeof cuerpo === 'object' && cuerpo !== null) {
                const obj = cuerpo;
                const msg = obj.message;
                if (typeof msg === 'object' && msg !== null) {
                    const anidado = msg;
                    if (anidado.mensaje != null) {
                        mensaje = String(anidado.mensaje);
                    }
                    if (anidado.error != null) {
                        error = String(anidado.error);
                    }
                }
                else if (typeof msg === 'string') {
                    mensaje = msg;
                    if (Array.isArray(mensaje)) {
                        mensaje = mensaje.join(', ');
                    }
                }
                if (mensaje === 'Ocurrió un error inesperado' && obj.mensaje != null) {
                    mensaje = String(obj.mensaje);
                }
                if (obj.error != null) {
                    error = String(obj.error);
                }
            }
            if (status === common_1.HttpStatus.UNAUTHORIZED)
                error = 'NO_AUTORIZADO';
            if (status === common_1.HttpStatus.FORBIDDEN) {
                const codigosNegocio = [
                    'PLAN_NO_INCLUYE_MODULO',
                    'PLAN_LIMITE_EXCEDIDO',
                ];
                if (!codigosNegocio.includes(error))
                    error = 'PROHIBIDO';
            }
            if (status === common_1.HttpStatus.NOT_FOUND)
                error = 'NO_ENCONTRADO';
            if (status === common_1.HttpStatus.BAD_REQUEST &&
                error !== 'STOCK_INSUFICIENTE') {
                error = 'SOLICITUD_INVALIDA';
            }
        }
        let detalles;
        if (exception instanceof common_1.HttpException) {
            const cuerpo = exception.getResponse();
            if (typeof cuerpo === 'object' && cuerpo !== null) {
                const obj = cuerpo;
                const msg = obj.message;
                if (typeof msg === 'object' && msg !== null) {
                    const anidado = msg;
                    if (anidado.detalles != null)
                        detalles = anidado.detalles;
                    if (anidado.message != null && typeof anidado.message === 'string') {
                        mensaje = anidado.message;
                    }
                    if (anidado.error != null)
                        error = String(anidado.error);
                }
                else if (obj.detalles != null) {
                    detalles = obj.detalles;
                }
                if (typeof obj.message === 'string' &&
                    obj.error === 'STOCK_INSUFICIENTE') {
                    mensaje = obj.message;
                    error = 'STOCK_INSUFICIENTE';
                }
            }
        }
        if (MENSAJES_NEGOCIO[mensaje]) {
            mensaje = MENSAJES_NEGOCIO[mensaje];
        }
        else if (MENSAJES_NEGOCIO[error]) {
            const tieneDetalleStock = error === 'STOCK_INSUFICIENTE' && detalles != null;
            if (!tieneDetalleStock) {
                mensaje = MENSAJES_NEGOCIO[error];
            }
        }
        const cuerpoRespuesta = {
            exito: false,
            error,
            mensaje,
        };
        if (detalles !== undefined) {
            cuerpoRespuesta.detalles = detalles;
        }
        response.status(status).json(cuerpoRespuesta);
    }
};
exports.HttpExceptionFilter = HttpExceptionFilter;
exports.HttpExceptionFilter = HttpExceptionFilter = __decorate([
    (0, common_1.Catch)()
], HttpExceptionFilter);
//# sourceMappingURL=http-exception.filter.js.map