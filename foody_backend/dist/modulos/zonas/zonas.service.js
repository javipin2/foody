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
exports.ZonasService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const COSTO_DOMICILIO_DEFAULT = 5000;
let ZonasService = class ZonasService {
    database;
    constructor(database) {
        this.database = database;
    }
    listar(sucursalId) {
        return this.database.consultar(`SELECT id, nombre, costo_domicilio, distancia_max_km, activa, created_at
       FROM zonas_cobertura
       WHERE sucursal_id = $1
       ORDER BY distancia_max_km ASC, nombre ASC`, [sucursalId]);
    }
    async configuracionMapa(sucursalId) {
        const sucursal = await this.database.consultarUno(`SELECT id, nombre, direccion, lat, lng
       FROM sucursales
       WHERE id = $1 AND activa = true`, [sucursalId]);
        if (!sucursal)
            throw new common_1.NotFoundException('Sucursal no encontrada');
        const zonas = await this.listar(sucursalId);
        return {
            sucursal: {
                id: sucursal.id,
                nombre: sucursal.nombre,
                direccion: sucursal.direccion,
                lat: sucursal.lat != null ? Number(sucursal.lat) : null,
                lng: sucursal.lng != null ? Number(sucursal.lng) : null,
            },
            zonas,
        };
    }
    async actualizarUbicacionSucursal(sucursalId, lat, lng) {
        const fila = await this.database.consultarUno(`UPDATE sucursales
       SET lat = $1, lng = $2
       WHERE id = $3 AND activa = true
       RETURNING id`, [lat, lng, sucursalId]);
        if (!fila)
            throw new common_1.NotFoundException('Sucursal no encontrada');
        return { id: fila.id, lat, lng };
    }
    async crear(dto) {
        return this.database.consultarUno(`INSERT INTO zonas_cobertura (
         sucursal_id, nombre, costo_domicilio, distancia_max_km, activa
       ) VALUES ($1, $2, $3, $4, true)
       RETURNING id, nombre, costo_domicilio, distancia_max_km, activa`, [dto.sucursal_id, dto.nombre.trim(), dto.costo_domicilio, dto.distancia_max_km]);
    }
    async actualizar(id, sucursalId, dto) {
        await this.exigirZona(id, sucursalId);
        const campos = [];
        const valores = [];
        let i = 1;
        if (dto.nombre !== undefined) {
            campos.push(`nombre = $${i++}`);
            valores.push(dto.nombre.trim());
        }
        if (dto.costo_domicilio !== undefined) {
            campos.push(`costo_domicilio = $${i++}`);
            valores.push(dto.costo_domicilio);
        }
        if (dto.distancia_max_km !== undefined) {
            campos.push(`distancia_max_km = $${i++}`);
            valores.push(dto.distancia_max_km);
        }
        if (dto.activa !== undefined) {
            campos.push(`activa = $${i++}`);
            valores.push(dto.activa);
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        await this.database.consultar(`UPDATE zonas_cobertura SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}`, valores);
        return { id };
    }
    async desactivar(id, sucursalId) {
        await this.exigirZona(id, sucursalId);
        await this.database.consultar(`UPDATE zonas_cobertura SET activa = false WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        return { id, activa: false };
    }
    async cotizarDomicilio(sucursalId, lat, lng) {
        const resultado = await this.calcularCostoDomicilio(null, sucursalId, lat, lng);
        return resultado;
    }
    async calcularCostoDomicilio(client, sucursalId, lat, lng) {
        const query = client
            ? (sql, params) => client.query(sql, params)
            : (sql, params) => this.database.consultar(sql, params);
        const sucursalRes = await query(`SELECT lat, lng FROM sucursales WHERE id = $1 AND activa = true`, [sucursalId]);
        const sucursal = client
            ? sucursalRes.rows[0]
            : sucursalRes[0];
        const zonasRes = await query(`SELECT id, nombre, costo_domicilio, distancia_max_km
       FROM zonas_cobertura
       WHERE sucursal_id = $1 AND activa = true
       ORDER BY distancia_max_km ASC`, [sucursalId]);
        const zonas = client
            ? zonasRes.rows
            : zonasRes;
        if (!zonas.length) {
            return {
                costo: COSTO_DOMICILIO_DEFAULT,
                zona_id: null,
                zona_nombre: null,
                distancia_km: null,
                fuente: 'default',
            };
        }
        let distanciaKm = null;
        if (lat != null &&
            lng != null &&
            sucursal?.lat != null &&
            sucursal?.lng != null) {
            distanciaKm = this.distanciaKm(Number(sucursal.lat), Number(sucursal.lng), lat, lng);
            for (const z of zonas) {
                if (distanciaKm <= Number(z.distancia_max_km)) {
                    return {
                        costo: Number(z.costo_domicilio),
                        zona_id: z.id,
                        zona_nombre: z.nombre,
                        distancia_km: Math.round(distanciaKm * 100) / 100,
                        fuente: 'zona',
                    };
                }
            }
            throw new common_1.BadRequestException({
                error: 'FUERA_DE_COBERTURA',
                message: `La dirección está fuera de cobertura (máx. ${zonas[zonas.length - 1].distancia_max_km} km)`,
                distancia_km: Math.round(distanciaKm * 100) / 100,
            });
        }
        const zona = zonas[0];
        return {
            costo: Number(zona.costo_domicilio),
            zona_id: zona.id,
            zona_nombre: zona.nombre,
            distancia_km: null,
            fuente: 'zona',
        };
    }
    distanciaKm(lat1, lng1, lat2, lng2) {
        const R = 6371;
        const dLat = this.toRad(lat2 - lat1);
        const dLng = this.toRad(lng2 - lng1);
        const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(this.toRad(lat1)) *
                Math.cos(this.toRad(lat2)) *
                Math.sin(dLng / 2) ** 2;
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }
    toRad(deg) {
        return (deg * Math.PI) / 180;
    }
    async exigirZona(id, sucursalId) {
        const z = await this.database.consultarUno(`SELECT id FROM zonas_cobertura WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!z)
            throw new common_1.NotFoundException('Zona no encontrada');
    }
    async obtenerSucursalIdDeZona(zonaId) {
        const fila = await this.database.consultarUno(`SELECT sucursal_id FROM zonas_cobertura WHERE id = $1`, [zonaId]);
        if (!fila)
            throw new common_1.NotFoundException('Zona no encontrada');
        return fila.sucursal_id;
    }
};
exports.ZonasService = ZonasService;
exports.ZonasService = ZonasService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], ZonasService);
//# sourceMappingURL=zonas.service.js.map