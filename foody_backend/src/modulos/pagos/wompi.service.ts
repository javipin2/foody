import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomBytes } from 'crypto';
import { esQaSinEfectosExternos } from '../../core/config/qa-safety';

export interface WompiPaymentLinkResponse {
  data: {
    id: string;
    name: string;
    amount_in_cents: number | null;
    currency: string;
    single_use: boolean;
    sku: string | null;
    url: string;
  };
}

export interface WompiEvento {
  event: string;
  data: Record<string, unknown>;
  environment: string;
  signature: {
    properties: string[];
    checksum: string;
  };
  timestamp: number;
  sent_at?: string;
}

@Injectable()
export class WompiService {
  constructor(private readonly config: ConfigService) {}

  estaConfigurado(): boolean {
    return (
      !esQaSinEfectosExternos() &&
      Boolean(this.clavePrivadaOpcional() && this.secretoEventosOpcional())
    );
  }

  clavePublica(): string {
    if (esQaSinEfectosExternos()) {
      throw new ServiceUnavailableException(
        'Wompi desactivado por FOODY_QA_SIN_EFECTOS',
      );
    }
    const key = this.config.get<string>('WOMPI_PUBLIC_KEY')?.trim();
    if (!key) {
      throw new ServiceUnavailableException(
        'Wompi no configurado (falta clave pública)',
      );
    }
    return key;
  }

  private clavePrivadaOpcional(): string | undefined {
    if (esQaSinEfectosExternos()) return undefined;
    return (
      this.config.get<string>('WOMPI_PRIVATE_KEY')?.trim() ||
      this.config.get<string>('WOMPI_SECRET_KEY')?.trim() ||
      undefined
    );
  }

  private clavePrivada(): string {
    const key = this.clavePrivadaOpcional();
    if (!key) {
      throw new ServiceUnavailableException(
        'Wompi no configurado (falta clave privada)',
      );
    }
    return key;
  }

  private secretoEventosOpcional(): string | undefined {
    if (esQaSinEfectosExternos()) return undefined;
    return (
      this.config.get<string>('WOMPI_EVENTS_SECRET')?.trim() ||
      this.config.get<string>('WOMPI_EVENT_KEY')?.trim() ||
      undefined
    );
  }

  private secretoEventos(): string {
    const key = this.secretoEventosOpcional();
    if (!key) {
      throw new ServiceUnavailableException(
        'Wompi no configurado (falta secreto de eventos)',
      );
    }
    return key;
  }

  private baseUrl(): string {
    const ambiente = (this.config.get<string>('WOMPI_AMBIENTE') ?? 'sandbox')
      .trim()
      .toLowerCase();
    if (ambiente === 'production' || ambiente === 'prod') {
      return 'https://production.wompi.co/v1';
    }
    const priv = this.clavePrivadaOpcional() ?? '';
    if (priv.includes('_prod_')) {
      return 'https://production.wompi.co/v1';
    }
    return 'https://sandbox.wompi.co/v1';
  }

  async crearEnlacePago(input: {
    nombre: string;
    descripcion: string;
    montoCentavos: number;
    referenciaInterna: string;
    redirectUrl?: string;
  }): Promise<WompiPaymentLinkResponse['data']> {
    const body = {
      name: input.nombre.slice(0, 120),
      description: input.descripcion.slice(0, 300),
      single_use: true,
      collect_shipping: false,
      currency: 'COP',
      amount_in_cents: input.montoCentavos,
      sku: input.referenciaInterna,
      redirect_url: input.redirectUrl ?? null,
    };

    const resp = await fetch(`${this.baseUrl()}/payment_links`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.clavePrivada()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const json = (await resp.json()) as WompiPaymentLinkResponse & {
      error?: { reason?: string; type?: string };
    };

    if (!resp.ok) {
      const detalle =
        json?.error?.reason ?? json?.error?.type ?? resp.statusText;
      throw new BadRequestException(
        `Wompi rechazó el enlace de pago: ${detalle}`,
      );
    }

    const data = json.data;
    return {
      ...data,
      url: data.url ?? this.urlCheckout(data.id),
    };
  }

  /** Wompi no incluye `url` en POST /payment_links; se arma con el id. */
  urlCheckout(paymentLinkId: string): string {
    return `https://checkout.wompi.co/l/${paymentLinkId}`;
  }

  /** Consulta estado de una transacción (llave pública). */
  async consultarTransaccion(transaccionId: string): Promise<{
    id: string;
    status: string;
    reference: string;
    payment_link_id: string | null;
    payment_source_id: string | null;
    payment_method_type: string | null;
    amount_in_cents: number;
    customer_email: string | null;
  }> {
    const id = transaccionId.trim();
    const resp = await fetch(
      `${this.baseUrl()}/transactions/${encodeURIComponent(id)}`,
      {
        headers: { Authorization: `Bearer ${this.clavePublica()}` },
      },
    );
    const json = (await resp.json()) as {
      data?: Record<string, unknown>;
      error?: { reason?: string };
    };
    if (!resp.ok || !json.data) {
      const detalle = json.error?.reason ?? resp.statusText;
      throw new BadRequestException(
        `No se pudo consultar la transacción Wompi: ${detalle}`,
      );
    }
    const d = json.data;
    return {
      id: String(d['id'] ?? id),
      status: String(d['status'] ?? ''),
      reference: String(d['reference'] ?? ''),
      payment_link_id: d['payment_link_id']
        ? String(d['payment_link_id'])
        : null,
      payment_source_id: d['payment_source_id']
        ? String(d['payment_source_id'])
        : null,
      payment_method_type: d['payment_method_type']
        ? String(d['payment_method_type'])
        : null,
      amount_in_cents: Number(d['amount_in_cents'] ?? 0),
      customer_email: d['customer_email'] ? String(d['customer_email']) : null,
    };
  }

  private secretoIntegridad(): string {
    if (esQaSinEfectosExternos()) {
      throw new ServiceUnavailableException(
        'Wompi desactivado por FOODY_QA_SIN_EFECTOS',
      );
    }
    const key =
      this.config.get<string>('WOMPI_INTEGRIDAD')?.trim() ||
      this.config.get<string>('WOMPI_INTEGRITY_SECRET')?.trim();
    if (!key) {
      throw new ServiceUnavailableException(
        'Wompi no configurado (falta secreto de integridad)',
      );
    }
    return key;
  }

  firmaIntegridad(
    referencia: string,
    montoCentavos: number,
    moneda = 'COP',
  ): string {
    const cadena = `${referencia}${montoCentavos}${moneda}${this.secretoIntegridad()}`;
    return createHash('sha256').update(cadena).digest('hex');
  }

  /** Cobro con fuente de pago guardada (renovación mensual). */
  async crearTransaccionRecurrente(input: {
    referenciaInterna: string;
    montoCentavos: number;
    customerEmail: string;
    paymentSourceId: string;
    redirectUrl?: string;
  }): Promise<{
    id: string;
    status: string;
    reference: string;
  }> {
    const body: Record<string, unknown> = {
      amount_in_cents: input.montoCentavos,
      currency: 'COP',
      customer_email: input.customerEmail,
      reference: input.referenciaInterna,
      payment_source_id: Number(input.paymentSourceId),
      recurrent: true,
      payment_method: { installments: 1 },
      signature: this.firmaIntegridad(
        input.referenciaInterna,
        input.montoCentavos,
      ),
    };
    if (input.redirectUrl) {
      body.redirect_url = input.redirectUrl;
    }

    const resp = await fetch(`${this.baseUrl()}/transactions`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.clavePrivada()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    const json = (await resp.json()) as {
      data?: Record<string, unknown>;
      error?: { reason?: string; type?: string };
    };

    if (!resp.ok || !json.data) {
      const detalle =
        json?.error?.reason ?? json?.error?.type ?? resp.statusText;
      throw new BadRequestException(
        `Wompi rechazó el cobro recurrente: ${detalle}`,
      );
    }

    const d = json.data;
    return {
      id: String(d['id'] ?? ''),
      status: String(d['status'] ?? ''),
      reference: String(d['reference'] ?? input.referenciaInterna),
    };
  }

  async consultarFuentePago(paymentSourceId: string): Promise<{
    id: string;
    status: string;
    type: string | null;
    public_data?: { last_four?: string; brand?: string };
  }> {
    const id = paymentSourceId.trim();
    const resp = await fetch(
      `${this.baseUrl()}/payment_sources/${encodeURIComponent(id)}`,
      {
        headers: { Authorization: `Bearer ${this.clavePrivada()}` },
      },
    );
    const json = (await resp.json()) as {
      data?: Record<string, unknown>;
      error?: { reason?: string };
    };
    if (!resp.ok || !json.data) {
      const detalle = json.error?.reason ?? resp.statusText;
      throw new BadRequestException(
        `No se pudo consultar la fuente de pago Wompi: ${detalle}`,
      );
    }
    const d = json.data;
    const publicData = d['public_data'] as Record<string, unknown> | undefined;
    return {
      id: String(d['id'] ?? id),
      status: String(d['status'] ?? ''),
      type: d['type'] ? String(d['type']) : null,
      public_data: publicData
        ? {
            last_four: publicData['last_four']
              ? String(publicData['last_four'])
              : undefined,
            brand: publicData['brand']
              ? String(publicData['brand'])
              : undefined,
          }
        : undefined,
    };
  }

  validarFirmaEvento(evento: WompiEvento, checksumHeader?: string): boolean {
    if (esQaSinEfectosExternos()) return false;
    const checksumEsperado =
      checksumHeader?.trim() || evento.signature?.checksum?.trim();
    if (!checksumEsperado) return false;

    const props = evento.signature?.properties ?? [];
    let cadena = '';
    for (const prop of props) {
      cadena += String(this.valorAnidado(evento.data, prop) ?? '');
    }
    cadena += String(evento.timestamp);
    cadena += this.secretoEventos();

    const calculado = createHash('sha256').update(cadena).digest('hex');
    return calculado.toUpperCase() === checksumEsperado.toUpperCase();
  }

  generarReferenciaInterna(): string {
    return `fdy_${randomBytes(8).toString('hex')}`;
  }

  private valorAnidado(obj: Record<string, unknown>, path: string): unknown {
    const partes = path.split('.');
    let actual: unknown = obj;
    for (const p of partes) {
      if (actual == null || typeof actual !== 'object') return undefined;
      actual = (actual as Record<string, unknown>)[p];
    }
    return actual;
  }
}
