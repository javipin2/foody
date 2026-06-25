import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Response } from 'express';

/** Códigos técnicos → mensaje legible para el cliente Flutter. */
const MENSAJES_NEGOCIO: Record<string, string> = {
  RESTAURANTE_CERRADO: 'El restaurante está cerrado en este momento.',
  PRODUCTO_NO_DISPONIBLE: 'Un producto del pedido ya no está disponible.',
  COMBO_NO_DISPONIBLE: 'El combo seleccionado ya no está disponible.',
  TOPPING_NO_DISPONIBLE: 'Un topping seleccionado ya no está disponible.',
  BEBIDA_NO_DISPONIBLE: 'Una bebida seleccionada ya no está disponible.',
  STOCK_INSUFICIENTE:
    'No hay suficiente stock para preparar este pedido. Intenta con menos cantidad.',
  MESA_NO_ENCONTRADA: 'La mesa indicada no existe o no está activa.',
  FUERA_DE_COBERTURA:
    'La dirección de entrega está fuera de la zona de domicilio.',
  MESA_ASIGNADA_OTRA_MESERA:
    'Esta mesa la está atendiendo otra mesera.',
};

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let error = 'ERROR_INTERNO';
    let mensaje = 'Ocurrió un error inesperado';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const cuerpo = exception.getResponse();
      if (typeof cuerpo === 'string') {
        mensaje = cuerpo;
      } else if (typeof cuerpo === 'object' && cuerpo !== null) {
        const obj = cuerpo as Record<string, unknown>;
        const msg = obj.message;
        if (typeof msg === 'object' && msg !== null) {
          const anidado = msg as Record<string, unknown>;
          if (anidado.mensaje != null) {
            mensaje = String(anidado.mensaje);
          }
          if (anidado.error != null) {
            error = String(anidado.error);
          }
        } else if (typeof msg === 'string') {
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
      if (status === HttpStatus.UNAUTHORIZED) error = 'NO_AUTORIZADO';
      if (status === HttpStatus.FORBIDDEN) {
        const codigosNegocio = [
          'PLAN_NO_INCLUYE_MODULO',
          'PLAN_LIMITE_EXCEDIDO',
        ];
        if (!codigosNegocio.includes(error)) error = 'PROHIBIDO';
      }
      if (status === HttpStatus.NOT_FOUND) error = 'NO_ENCONTRADO';
      if (
        status === HttpStatus.BAD_REQUEST &&
        error !== 'STOCK_INSUFICIENTE'
      ) {
        error = 'SOLICITUD_INVALIDA';
      }
    }

    let detalles: unknown;
    if (exception instanceof HttpException) {
      const cuerpo = exception.getResponse();
      if (typeof cuerpo === 'object' && cuerpo !== null) {
        const obj = cuerpo as Record<string, unknown>;
        const msg = obj.message;
        if (typeof msg === 'object' && msg !== null) {
          const anidado = msg as Record<string, unknown>;
          if (anidado.detalles != null) detalles = anidado.detalles;
          if (anidado.message != null && typeof anidado.message === 'string') {
            mensaje = anidado.message;
          }
          if (anidado.error != null) error = String(anidado.error);
        } else if (obj.detalles != null) {
          detalles = obj.detalles;
        }
        if (
          typeof obj.message === 'string' &&
          obj.error === 'STOCK_INSUFICIENTE'
        ) {
          mensaje = obj.message;
          error = 'STOCK_INSUFICIENTE';
        }
      }
    }

    if (MENSAJES_NEGOCIO[mensaje]) {
      mensaje = MENSAJES_NEGOCIO[mensaje];
    } else if (MENSAJES_NEGOCIO[error]) {
      const tieneDetalleStock =
          error === 'STOCK_INSUFICIENTE' && detalles != null;
      if (!tieneDetalleStock) {
        mensaje = MENSAJES_NEGOCIO[error];
      }
    }

    const cuerpoRespuesta: Record<string, unknown> = {
      exito: false,
      error,
      mensaje,
    };
    if (detalles !== undefined) {
      cuerpoRespuesta.detalles = detalles;
    }
    response.status(status).json(cuerpoRespuesta);
  }
}
