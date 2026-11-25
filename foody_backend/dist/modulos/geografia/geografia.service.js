"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var GeografiaService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.GeografiaService = void 0;
const common_1 = require("@nestjs/common");
const qa_safety_1 = require("../../core/config/qa-safety");
let GeografiaService = class GeografiaService {
    static { GeografiaService_1 = this; }
    static timeoutMs = 5000;
    cache = new Map();
    maxCache = 300;
    async buscarDirecciones(consulta, opciones = {}) {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            throw new common_1.ServiceUnavailableException('Geocodificación externa desactivada por FOODY_QA_SIN_EFECTOS');
        }
        const q = consulta.trim();
        if (q.length < 3) {
            throw new common_1.BadRequestException('La búsqueda debe tener al menos 3 caracteres');
        }
        const claveCache = this.claveCache(q, opciones.lat, opciones.lng);
        const enCache = this.cache.get(claveCache);
        if (enCache)
            return enCache;
        const limite = Math.min(Math.max(opciones.limite ?? 8, 1), 15);
        const params = new URLSearchParams({
            q,
            lang: 'es',
            limit: String(limite),
        });
        if (opciones.lat != null && opciones.lng != null) {
            params.set('lat', String(opciones.lat));
            params.set('lon', String(opciones.lng));
        }
        const url = `https://photon.komoot.io/api/?${params.toString()}`;
        const signal = AbortSignal.timeout(GeografiaService_1.timeoutMs);
        let respuesta;
        let datos;
        try {
            respuesta = await fetch(url, {
                headers: { Accept: 'application/json' },
                signal,
            });
            if (!respuesta.ok) {
                throw new common_1.BadGatewayException('No se pudo consultar el servicio de direcciones');
            }
            datos = (await respuesta.json());
        }
        catch (error) {
            if (signal.aborted ||
                (error instanceof Error && error.name === 'TimeoutError')) {
                throw new common_1.GatewayTimeoutException('El servicio de direcciones tardó demasiado. Intenta de nuevo.');
            }
            if (error instanceof common_1.BadGatewayException ||
                error instanceof common_1.GatewayTimeoutException) {
                throw error;
            }
            throw new common_1.BadGatewayException('No fue posible conectar con el servicio de direcciones');
        }
        const resultados = (datos.features ?? [])
            .map((f) => {
            const coords = f.geometry?.coordinates;
            if (!coords || coords.length < 2)
                return null;
            const props = f.properties ?? {};
            const partes = [
                props.name,
                props.street,
                props.housenumber,
                props.district,
                props.city ?? props.state,
                props.country,
            ]
                .filter((p) => p && String(p).trim().length > 0)
                .map((p) => String(p).trim());
            const etiqueta = [...new Set(partes)].join(', ');
            if (!etiqueta)
                return null;
            return {
                etiqueta,
                lng: coords[0],
                lat: coords[1],
            };
        })
            .filter((r) => r != null);
        this.guardarCache(claveCache, resultados);
        return resultados;
    }
    claveCache(q, lat, lng) {
        return `${q.toLowerCase()}|${lat ?? ''}|${lng ?? ''}`;
    }
    guardarCache(clave, valor) {
        if (this.cache.size >= this.maxCache) {
            const primera = this.cache.keys().next().value;
            if (primera)
                this.cache.delete(primera);
        }
        this.cache.set(clave, valor);
    }
};
exports.GeografiaService = GeografiaService;
exports.GeografiaService = GeografiaService = GeografiaService_1 = __decorate([
    (0, common_1.Injectable)()
], GeografiaService);
//# sourceMappingURL=geografia.service.js.map