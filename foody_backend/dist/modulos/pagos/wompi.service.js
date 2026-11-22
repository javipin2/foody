"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.WompiService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const crypto_1 = require("crypto");
let WompiService = class WompiService {
    config;
    constructor(config) {
        this.config = config;
    }
    estaConfigurado() {
        return Boolean(this.clavePrivadaOpcional() && this.secretoEventosOpcional());
    }
    clavePublica() {
        const key = this.config.get('WOMPI_PUBLIC_KEY')?.trim();
        if (!key) {
            throw new common_1.ServiceUnavailableException('Wompi no configurado (falta clave pública)');
        }
        return key;
    }
    clavePrivadaOpcional() {
        return (this.config.get('WOMPI_PRIVATE_KEY')?.trim() ||
            this.config.get('WOMPI_SECRET_KEY')?.trim() ||
            undefined);
    }
    clavePrivada() {
        const key = this.clavePrivadaOpcional();
        if (!key) {
            throw new common_1.ServiceUnavailableException('Wompi no configurado (falta clave privada)');
        }
        return key;
    }
    secretoEventosOpcional() {
        return (this.config.get('WOMPI_EVENTS_SECRET')?.trim() ||
            this.config.get('WOMPI_EVENT_KEY')?.trim() ||
            undefined);
    }
    secretoEventos() {
        const key = this.secretoEventosOpcional();
        if (!key) {
            throw new common_1.ServiceUnavailableException('Wompi no configurado (falta secreto de eventos)');
        }
        return key;
    }
    baseUrl() {
        const ambiente = (this.config.get('WOMPI_AMBIENTE') ?? 'sandbox')
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
    async crearEnlacePago(input) {
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
        const json = (await resp.json());
        if (!resp.ok) {
            const detalle = json?.error?.reason ?? json?.error?.type ?? resp.statusText;
            throw new common_1.BadRequestException(`Wompi rechazó el enlace de pago: ${detalle}`);
        }
        const data = json.data;
        return {
            ...data,
            url: data.url ?? this.urlCheckout(data.id),
        };
    }
    urlCheckout(paymentLinkId) {
        return `https://checkout.wompi.co/l/${paymentLinkId}`;
    }
    async consultarTransaccion(transaccionId) {
        const id = transaccionId.trim();
        const resp = await fetch(`${this.baseUrl()}/transactions/${encodeURIComponent(id)}`, {
            headers: { Authorization: `Bearer ${this.clavePublica()}` },
        });
        const json = (await resp.json());
        if (!resp.ok || !json.data) {
            const detalle = json.error?.reason ?? resp.statusText;
            throw new common_1.BadRequestException(`No se pudo consultar la transacción Wompi: ${detalle}`);
        }
        const d = json.data;
        return {
            id: String(d['id'] ?? id),
            status: String(d['status'] ?? ''),
            reference: String(d['reference'] ?? ''),
            payment_link_id: d['payment_link_id'] ? String(d['payment_link_id']) : null,
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
    secretoIntegridad() {
        const key = this.config.get('WOMPI_INTEGRIDAD')?.trim() ||
            this.config.get('WOMPI_INTEGRITY_SECRET')?.trim();
        if (!key) {
            throw new common_1.ServiceUnavailableException('Wompi no configurado (falta secreto de integridad)');
        }
        return key;
    }
    firmaIntegridad(referencia, montoCentavos, moneda = 'COP') {
        const cadena = `${referencia}${montoCentavos}${moneda}${this.secretoIntegridad()}`;
        return (0, crypto_1.createHash)('sha256').update(cadena).digest('hex');
    }
    async crearTransaccionRecurrente(input) {
        const body = {
            amount_in_cents: input.montoCentavos,
            currency: 'COP',
            customer_email: input.customerEmail,
            reference: input.referenciaInterna,
            payment_source_id: Number(input.paymentSourceId),
            recurrent: true,
            payment_method: { installments: 1 },
            signature: this.firmaIntegridad(input.referenciaInterna, input.montoCentavos),
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
        const json = (await resp.json());
        if (!resp.ok || !json.data) {
            const detalle = json?.error?.reason ?? json?.error?.type ?? resp.statusText;
            throw new common_1.BadRequestException(`Wompi rechazó el cobro recurrente: ${detalle}`);
        }
        const d = json.data;
        return {
            id: String(d['id'] ?? ''),
            status: String(d['status'] ?? ''),
            reference: String(d['reference'] ?? input.referenciaInterna),
        };
    }
    async consultarFuentePago(paymentSourceId) {
        const id = paymentSourceId.trim();
        const resp = await fetch(`${this.baseUrl()}/payment_sources/${encodeURIComponent(id)}`, {
            headers: { Authorization: `Bearer ${this.clavePrivada()}` },
        });
        const json = (await resp.json());
        if (!resp.ok || !json.data) {
            const detalle = json.error?.reason ?? resp.statusText;
            throw new common_1.BadRequestException(`No se pudo consultar la fuente de pago Wompi: ${detalle}`);
        }
        const d = json.data;
        const publicData = d['public_data'];
        return {
            id: String(d['id'] ?? id),
            status: String(d['status'] ?? ''),
            type: d['type'] ? String(d['type']) : null,
            public_data: publicData
                ? {
                    last_four: publicData['last_four']
                        ? String(publicData['last_four'])
                        : undefined,
                    brand: publicData['brand'] ? String(publicData['brand']) : undefined,
                }
                : undefined,
        };
    }
    validarFirmaEvento(evento, checksumHeader) {
        const checksumEsperado = checksumHeader?.trim() || evento.signature?.checksum?.trim();
        if (!checksumEsperado)
            return false;
        const props = evento.signature?.properties ?? [];
        let cadena = '';
        for (const prop of props) {
            cadena += String(this.valorAnidado(evento.data, prop) ?? '');
        }
        cadena += String(evento.timestamp);
        cadena += this.secretoEventos();
        const calculado = (0, crypto_1.createHash)('sha256').update(cadena).digest('hex');
        return calculado.toUpperCase() === checksumEsperado.toUpperCase();
    }
    generarReferenciaInterna() {
        return `fdy_${(0, crypto_1.randomBytes)(8).toString('hex')}`;
    }
    valorAnidado(obj, path) {
        const partes = path.split('.');
        let actual = obj;
        for (const p of partes) {
            if (actual == null || typeof actual !== 'object')
                return undefined;
            actual = actual[p];
        }
        return actual;
    }
};
exports.WompiService = WompiService;
exports.WompiService = WompiService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], WompiService);
//# sourceMappingURL=wompi.service.js.map