import { Injectable } from '@nestjs/common';

export type ResultadoDispatchAuto = {
  iniciado: boolean;
  motivo?: string;
};

type HandlerDispatchAuto = (
  pedidoId: string,
  sucursalId: string,
) => Promise<ResultadoDispatchAuto>;

/**
 * Rompe AQ-CYCLE-01: pedidos no importa DomiciliariosModule.
 * DispatchService se registra en onModuleInit (one-way).
 */
@Injectable()
export class PedidosDispatchHooksService {
  private handler: HandlerDispatchAuto | null = null;

  registrar(handler: HandlerDispatchAuto): void {
    this.handler = handler;
  }

  async intentarDispatchAutomatico(
    pedidoId: string,
    sucursalId: string,
  ): Promise<ResultadoDispatchAuto> {
    if (!this.handler) {
      return { iniciado: false, motivo: 'sin_handler' };
    }
    return this.handler(pedidoId, sucursalId);
  }
}
