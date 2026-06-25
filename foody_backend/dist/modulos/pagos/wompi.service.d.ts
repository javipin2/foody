import { ConfigService } from '@nestjs/config';
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
export declare class WompiService {
    private readonly config;
    constructor(config: ConfigService);
    estaConfigurado(): boolean;
    clavePublica(): string;
    private clavePrivadaOpcional;
    private clavePrivada;
    private secretoEventosOpcional;
    private secretoEventos;
    private baseUrl;
    crearEnlacePago(input: {
        nombre: string;
        descripcion: string;
        montoCentavos: number;
        referenciaInterna: string;
        redirectUrl?: string;
    }): Promise<WompiPaymentLinkResponse['data']>;
    urlCheckout(paymentLinkId: string): string;
    consultarTransaccion(transaccionId: string): Promise<{
        id: string;
        status: string;
        reference: string;
        payment_link_id: string | null;
        payment_method_type: string | null;
        amount_in_cents: number;
    }>;
    validarFirmaEvento(evento: WompiEvento, checksumHeader?: string): boolean;
    generarReferenciaInterna(): string;
    private valorAnidado;
}
