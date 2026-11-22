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
exports.OnboardingRestauranteService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
let OnboardingRestauranteService = class OnboardingRestauranteService {
    database;
    constructor(database) {
        this.database = database;
    }
    async crear(dto) {
        const ciudad = await this.database.consultarUno(`SELECT id, slug FROM ciudades WHERE id = $1 AND activa = true`, [dto.ciudad_id]);
        if (!ciudad)
            throw new common_1.BadRequestException('Ciudad no válida');
        const centroCiudad = this.centroCiudadPorSlug(ciudad.slug);
        const email = dto.admin_email.trim().toLowerCase();
        const existeEmail = await this.database.consultarUno(`SELECT id FROM usuarios WHERE LOWER(email) = $1`, [email]);
        if (existeEmail) {
            throw new common_1.ConflictException('El correo ya está registrado');
        }
        const origen = dto.origen ?? 'manual';
        const plan = dto.plan ?? 'basico';
        const estado = dto.estado_suscripcion ?? 'prueba';
        const proveedor = dto.proveedor_auth ?? 'correo';
        const diasPrueba = dto.dias_prueba ?? 14;
        if (proveedor === 'correo' && !dto.hash_contrasena) {
            throw new common_1.BadRequestException('La contraseña es obligatoria para registro por correo');
        }
        const fechaVencimiento = new Date();
        if (plan === 'gratis') {
            fechaVencimiento.setTime(Date.parse('2099-12-31T23:59:59.000Z'));
        }
        else if (estado === 'prueba') {
            fechaVencimiento.setDate(fechaVencimiento.getDate() + diasPrueba);
        }
        else {
            fechaVencimiento.setDate(fechaVencimiento.getDate() + 30);
        }
        return this.database.enTransaccion(async (client) => {
            const rest = await client.query(`INSERT INTO restaurantes (ciudad_id, nombre, activo, origen)
         VALUES ($1, $2, true, $3) RETURNING id`, [dto.ciudad_id, dto.nombre_restaurante.trim(), origen]);
            const restauranteId = rest.rows[0].id;
            const suc = await client.query(`INSERT INTO sucursales (
           restaurante_id, ciudad_id, nombre, direccion, lat, lng, activa
         ) VALUES ($1, $2, $3, $4, $5, $6, true) RETURNING id`, [
                restauranteId,
                dto.ciudad_id,
                dto.nombre_sucursal.trim(),
                dto.direccion_sucursal?.trim() ?? null,
                centroCiudad?.lat ?? null,
                centroCiudad?.lng ?? null,
            ]);
            const sucursalId = suc.rows[0].id;
            await client.query(`INSERT INTO cocinas (sucursal_id, nombre) VALUES ($1, 'Cocina principal')`, [sucursalId]);
            await client.query(`INSERT INTO suscripciones_restaurante (
           restaurante_id, estado, plan, fecha_vencimiento
         ) VALUES ($1, $2, $3, $4)`, [restauranteId, estado, plan, fechaVencimiento]);
            const admin = await client.query(`INSERT INTO usuarios (
           id, sucursal_id, restaurante_id, nombre, email, rol, activo,
           hash_contrasena, proveedor_auth, proveedor_id, email_verificado
         ) VALUES (
           gen_random_uuid(), $1, $2, $3, $4, 'admin', true,
           $5, $6, $7, $8
         ) RETURNING id`, [
                sucursalId,
                restauranteId,
                dto.admin_nombre.trim(),
                email,
                dto.hash_contrasena ?? null,
                proveedor,
                dto.proveedor_id ?? null,
                dto.email_verificado ?? proveedor === 'google',
            ]);
            return {
                restaurante_id: restauranteId,
                sucursal_id: sucursalId,
                admin_id: admin.rows[0].id,
                admin_email: email,
                ciudad_slug: ciudad.slug,
                suscripcion: {
                    estado,
                    plan,
                    ...(estado === 'prueba' ? { dias_prueba: diasPrueba } : {}),
                },
            };
        }).then(async (resultado) => {
            await this.completarPostCommit(resultado.sucursal_id, resultado.ciudad_slug);
            const { ciudad_slug: _slug, ...out } = resultado;
            return out;
        });
    }
    async completarPostCommit(sucursalId, ciudadSlug) {
        try {
            const centro = this.centroCiudadPorSlug(ciudadSlug);
            if (centro) {
                await this.database.consultar(`INSERT INTO zonas_cobertura (sucursal_id, nombre, costo_domicilio, distancia_max_km, activa)
           SELECT $1, 'Zona centro', 4000, 5, true
           WHERE NOT EXISTS (
             SELECT 1 FROM zonas_cobertura WHERE sucursal_id = $1
           )`, [sucursalId]);
            }
            await this.database.consultar(`INSERT INTO horarios_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, activo)
         SELECT $1, d, '08:00', '22:00', true
         FROM generate_series(0, 6) AS d
         WHERE NOT EXISTS (
           SELECT 1 FROM horarios_sucursal WHERE sucursal_id = $1
         )`, [sucursalId]);
        }
        catch {
        }
    }
    centroCiudadPorSlug(slug) {
        const centros = {
            valledupar: { lat: 10.463714, lng: -73.253222 },
        };
        return centros[slug.toLowerCase()] ?? null;
    }
};
exports.OnboardingRestauranteService = OnboardingRestauranteService;
exports.OnboardingRestauranteService = OnboardingRestauranteService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], OnboardingRestauranteService);
//# sourceMappingURL=onboarding-restaurante.service.js.map