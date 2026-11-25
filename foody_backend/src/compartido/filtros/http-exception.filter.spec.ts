import { ArgumentsHost, BadRequestException } from '@nestjs/common';
import { HttpExceptionFilter } from './http-exception.filter';

describe('HttpExceptionFilter', () => {
  it('preserva COBRO_REQUERIDO y devuelve un mensaje legible', () => {
    const response = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    const host = {
      switchToHttp: () => ({ getResponse: () => response }),
    } as unknown as ArgumentsHost;

    new HttpExceptionFilter().catch(
      new BadRequestException({
        error: 'COBRO_REQUERIDO',
        message:
          'Indica método de pago al entregar (efectivo, tarjeta, transferencia o nequi)',
      }),
      host,
    );

    expect(response.status).toHaveBeenCalledWith(400);
    expect(response.json).toHaveBeenCalledWith({
      exito: false,
      error: 'COBRO_REQUERIDO',
      mensaje:
        'Indica método de pago al entregar (efectivo, tarjeta, transferencia o nequi)',
    });
  });
});
