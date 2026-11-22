"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var HttpExceptionFilter_1;
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
    ITEMS_EXCEDEN_SALDO: 'El total de los ítems seleccionados supera el saldo pendiente de la mesa.',
    ITEMS_INVALIDOS: 'Algunos ítems ya fueron cobrados o no pertenecen a esta mesa.',
    FUERA_DE_COBERTURA: 'La dirección de entrega está fuera de la zona de domicilio.',
    MESA_DESTINO_OCUPADA: 'La mesa destino tiene otro pedido activo.',
    MESERA_INVALIDA: 'La mesera indicada no es válida para esta sucursal.',
    MESA_REQUERIDA: 'Un pedido de mesa requiere mesa_id.',
    CAJA_CIERRE_OPERACION_ABIERTA: 'No puedes cerrar la caja con pedidos activos, mesas ocupadas o domicilios sin cobrar.',
    CAJA_NO_ABIERTA: 'No hay caja abierta. Abre un turno antes de esta operación.',
    CAJA_YA_ABIERTA: 'Ya hay una caja abierta en esta sucursal.',
    DEVOLUCION_EXCEDE_VENTAS_TURNO: 'La devolución supera las ventas cobradas en este turno. Si cancelaste un pedido no cobrado, no registres devolución manual.',
    PEDIDO_SIN_COBRO_CAJA: 'Este pedido no tiene cobro en caja. Cancelar el pedido es suficiente.',
    DEVOLUCION_EXCEDE_COBRO_PEDIDO: 'La devolución supera lo cobrado en caja para este pedido.',
    RESTAURANTE_BLOQUEADO: 'Tu suscripción no está activa. Reactiva tu plan para usar el panel. Tus datos se conservan.',
    COCINA_INCOMPLETA_PARA_PAGADO: 'Hay ítems aún en cocina. Registra un abono o espera cocina completa. Admin/gerente puede cerrar con motivo.',
    CANTIDAD_COCINA_INMUTABLE: 'No se puede bajar la cantidad de un ítem en preparación o listo. Elimínalo con motivo (merma).',
    FALLO_PREPARACION_MOTIVO: 'Indica el motivo del fallo de preparación (obligatorio).',
    IMPRESION_SIN_COCINA: 'Este pedido no tiene ítems de cocina para imprimir.',
    PEDIDO_NO_ENCONTRADO: 'Pedido no encontrado en esta sucursal.',
};
const CODIGOS_ERROR_PRESERVAR = new Set([
    'STOCK_INSUFICIENTE',
    'CAJA_CIERRE_OPERACION_ABIERTA',
    'CAJA_NO_ABIERTA',
    'CAJA_YA_ABIERTA',
    'CAJA_YA_CERRADA',
    'PEDIDO_CERRADO',
    'SIN_SALDO',
    'PLAN_NO_INCLUYE_MODULO',
    'PLAN_LIMITE_EXCEDIDO',
    'ITEMS_EXCEDEN_SALDO',
    'ITEMS_INVALIDOS',
    'MONTO_PARCIAL_EXCESO',
    'PAGOS_NO_COINCIDEN',
    'DEVOLUCION_EXCEDE_VENTAS_TURNO',
    'PEDIDO_SIN_COBRO_CAJA',
    'DEVOLUCION_EXCEDE_COBRO_PEDIDO',
    'COCINA_INCOMPLETA_PARA_PAGADO',
    'CANTIDAD_COCINA_INMUTABLE',
    'FALLO_PREPARACION_MOTIVO',
    'MESA_ASIGNADA_OTRA_MESERA',
    'MESA_DESTINO_OCUPADA',
    'MESERA_INVALIDA',
    'MESA_REQUERIDA',
    'MISMA_MESA',
    'NO_ES_PEDIDO_MESA',
    'PEDIDO_NO_EN_MESA_ORIGEN',
    'QR_TOKEN_DUPLICADO',
    'REGISTRO_CERRADO',
    'REGISTRO_CUPO',
]);
let HttpExceptionFilter = HttpExceptionFilter_1 = class HttpExceptionFilter {
    logger = new common_1.Logger(HttpExceptionFilter_1.name);
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
                    if (anidado.message != null && mensaje === 'Ocurrió un error inesperado') {
                        mensaje = String(anidado.message);
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
                if (mensaje === 'Ocurrió un error inesperado' &&
                    typeof obj.message === 'string') {
                    mensaje = obj.message;
                }
            }
            if (status === common_1.HttpStatus.UNAUTHORIZED)
                error = 'NO_AUTORIZADO';
            if (status === common_1.HttpStatus.FORBIDDEN) {
                const codigosNegocio = [
                    'PLAN_NO_INCLUYE_MODULO',
                    'PLAN_LIMITE_EXCEDIDO',
                    'RESTAURANTE_BLOQUEADO',
                ];
                if (!codigosNegocio.includes(error))
                    error = 'PROHIBIDO';
            }
            if (status === common_1.HttpStatus.NOT_FOUND)
                error = 'NO_ENCONTRADO';
            if (status === common_1.HttpStatus.BAD_REQUEST &&
                !CODIGOS_ERROR_PRESERVAR.has(error)) {
                error = 'SOLICITUD_INVALIDA';
            }
        }
        let detalles;
        let limitePlan;
        let actualPlan;
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
                if (error === 'PLAN_LIMITE_EXCEDIDO') {
                    if (typeof obj.limite === 'number')
                        limitePlan = obj.limite;
                    if (typeof obj.actual === 'number')
                        actualPlan = obj.actual;
                }
            }
        }
        if (MENSAJES_NEGOCIO[mensaje]) {
            mensaje = MENSAJES_NEGOCIO[mensaje];
        }
        else if (MENSAJES_NEGOCIO[error]) {
            const tieneDetalleStock = error === 'STOCK_INSUFICIENTE' && detalles != null;
            const mensajeYaEspecifico = mensaje !== 'Ocurrió un error inesperado' &&
                mensaje !== error &&
                !MENSAJES_NEGOCIO[mensaje];
            if (!tieneDetalleStock && !mensajeYaEspecifico) {
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
        if (limitePlan !== undefined) {
            cuerpoRespuesta.limite = limitePlan;
        }
        if (actualPlan !== undefined) {
            cuerpoRespuesta.actual = actualPlan;
        }
        if (status >= common_1.HttpStatus.INTERNAL_SERVER_ERROR) {
            this.logger.error(`Error ${error}: ${mensaje}`, exception instanceof Error ? exception.stack : String(exception));
        }
        response.status(status).json(cuerpoRespuesta);
    }
};
exports.HttpExceptionFilter = HttpExceptionFilter;
exports.HttpExceptionFilter = HttpExceptionFilter = HttpExceptionFilter_1 = __decorate([
    (0, common_1.Catch)()
], HttpExceptionFilter);
//# sourceMappingURL=http-exception.filter.js.map