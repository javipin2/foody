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
var PromocionesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.PromocionesService = void 0;
const common_1 = require("@nestjs/common");
const database_service_1 = require("../../core/database/database.service");
const almacenamiento_service_1 = require("../almacenamiento/almacenamiento.service");
let PromocionesService = PromocionesService_1 = class PromocionesService {
    database;
    almacenamiento;
    logger = new common_1.Logger(PromocionesService_1.name);
    constructor(database, almacenamiento) {
        this.database = database;
        this.almacenamiento = almacenamiento;
    }
    listarActivas(sucursalId) {
        return this.database.consultar(`SELECT p.id, p.titulo, p.imagen_url, p.tipo_media, p.descripcion, p.codigo,
              p.descuento_porcentaje, p.descuento_monto,
              p.expira_at, p.vistas, p.created_at,
              p.producto_id, pr.nombre AS producto_nombre
       FROM estados_promociones p
       LEFT JOIN productos pr ON pr.id = p.producto_id
       WHERE p.sucursal_id = $1
         AND p.activa = true
         AND (p.expira_at IS NULL OR p.expira_at > now())
       ORDER BY p.created_at DESC`, [sucursalId]);
    }
    listarStoriesPorCiudad(slug) {
        return this.database.consultar(`SELECT r.id AS restaurante_id,
              r.nombre AS restaurante_nombre,
              r.logo_url,
              r.banner_url,
              COALESCE(
                json_agg(
                  json_build_object(
                    'id', p.id,
                    'titulo', p.titulo,
                    'imagen_url', p.imagen_url,
                    'tipo_media', p.tipo_media,
                    'descripcion', p.descripcion,
                    'sucursal_id', s.id,
                    'producto_id', p.producto_id,
                    'producto_nombre', pr.nombre,
                    'expira_at', p.expira_at
                  )
                  ORDER BY p.created_at DESC
                ) FILTER (WHERE p.id IS NOT NULL),
                '[]'::json
              ) AS promociones
       FROM restaurantes r
       INNER JOIN ciudades c ON c.id = r.ciudad_id
       LEFT JOIN sucursales s ON s.restaurante_id = r.id AND s.activa = true
       LEFT JOIN estados_promociones p ON p.sucursal_id = s.id
         AND p.activa = true
         AND (p.expira_at IS NULL OR p.expira_at > now())
       LEFT JOIN productos pr ON pr.id = p.producto_id
       WHERE c.slug = $1 AND c.activa = true AND r.activo = true
       GROUP BY r.id, r.nombre, r.logo_url, r.banner_url
       HAVING COUNT(p.id) > 0
       ORDER BY r.nombre ASC`, [slug]);
    }
    listarAdmin(sucursalId) {
        return this.database.consultar(`SELECT p.id, p.titulo, p.imagen_url, p.tipo_media, p.descripcion, p.codigo,
              p.descuento_porcentaje, p.descuento_monto,
              p.activa, p.expira_at, p.vistas, p.created_at,
              p.producto_id, pr.nombre AS producto_nombre
       FROM estados_promociones p
       LEFT JOIN productos pr ON pr.id = p.producto_id
       WHERE p.sucursal_id = $1
       ORDER BY p.created_at DESC`, [sucursalId]);
    }
    async crear(dto) {
        if (!dto.imagen_url?.trim()) {
            throw new common_1.BadRequestException('La URL de media es obligatoria');
        }
        const tipoMedia = dto.tipo_media === 'video' ? 'video' : 'imagen';
        this.validarDescuentoDto(dto.descuento_porcentaje, dto.descuento_monto, dto.codigo);
        if (dto.producto_id) {
            await this.exigirProductoDeSucursal(dto.producto_id, dto.sucursal_id);
        }
        const expiraAt = dto.expira_at ?? new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
        return this.database.consultarUno(`INSERT INTO estados_promociones (
         sucursal_id, titulo, imagen_url, tipo_media, descripcion, expira_at, activa,
         codigo, descuento_porcentaje, descuento_monto, producto_id
       ) VALUES ($1, $2, $3, $4, $5, $6, true, $7, $8, $9, $10)
       RETURNING id, titulo, imagen_url, tipo_media, descripcion, codigo,
                 descuento_porcentaje, descuento_monto, activa, expira_at,
                 vistas, created_at, producto_id`, [
            dto.sucursal_id,
            dto.titulo?.trim() || null,
            dto.imagen_url.trim(),
            tipoMedia,
            dto.descripcion?.trim() || null,
            expiraAt,
            dto.codigo?.trim().toUpperCase() || null,
            dto.descuento_porcentaje ?? null,
            dto.descuento_monto ?? null,
            dto.producto_id ?? null,
        ]);
    }
    async actualizar(id, sucursalId, dto) {
        await this.exigirPromocion(id, sucursalId);
        const campos = [];
        const valores = [];
        let i = 1;
        if (dto.titulo !== undefined) {
            campos.push(`titulo = $${i++}`);
            valores.push(dto.titulo.trim() || null);
        }
        if (dto.imagen_url !== undefined) {
            campos.push(`imagen_url = $${i++}`);
            valores.push(dto.imagen_url.trim());
        }
        if (dto.descripcion !== undefined) {
            campos.push(`descripcion = $${i++}`);
            valores.push(dto.descripcion.trim() || null);
        }
        if (dto.expira_at !== undefined) {
            campos.push(`expira_at = $${i++}`);
            valores.push(dto.expira_at || null);
        }
        if (dto.activa !== undefined) {
            campos.push(`activa = $${i++}`);
            valores.push(dto.activa);
        }
        if (dto.codigo !== undefined) {
            campos.push(`codigo = $${i++}`);
            valores.push(dto.codigo.trim().toUpperCase() || null);
        }
        if (dto.descuento_porcentaje !== undefined) {
            campos.push(`descuento_porcentaje = $${i++}`);
            valores.push(dto.descuento_porcentaje);
        }
        if (dto.descuento_monto !== undefined) {
            campos.push(`descuento_monto = $${i++}`);
            valores.push(dto.descuento_monto);
        }
        if (dto.producto_id !== undefined) {
            if (dto.producto_id) {
                await this.exigirProductoDeSucursal(dto.producto_id, sucursalId);
            }
            campos.push(`producto_id = $${i++}`);
            valores.push(dto.producto_id || null);
        }
        if (!campos.length)
            return { id };
        valores.push(id, sucursalId);
        return this.database.consultarUno(`UPDATE estados_promociones SET ${campos.join(', ')}
       WHERE id = $${i++} AND sucursal_id = $${i}
       RETURNING id, titulo, imagen_url, descripcion, codigo,
                 descuento_porcentaje, descuento_monto, activa, expira_at,
                 vistas, created_at, producto_id`, valores);
    }
    async previewCodigo(sucursalId, codigo, subtotal) {
        return this.database.enTransaccion((client) => this.resolverDescuentoPorCodigo(client, sucursalId, codigo, subtotal));
    }
    async resolverDescuentoPorCodigo(client, sucursalId, codigo, subtotal) {
        const normalizado = codigo.trim().toUpperCase();
        if (!normalizado) {
            throw new common_1.BadRequestException({
                error: 'PROMOCION_CODIGO_VACIO',
                message: 'Indica un código promocional',
            });
        }
        const promo = await client.query(`SELECT id, titulo, codigo, descuento_porcentaje, descuento_monto
       FROM estados_promociones
       WHERE sucursal_id = $1
         AND activa = true
         AND (expira_at IS NULL OR expira_at > now())
         AND lower(trim(codigo)) = lower($2)`, [sucursalId, normalizado]);
        const fila = promo.rows[0];
        if (!fila) {
            throw new common_1.BadRequestException({
                error: 'PROMOCION_INVALIDA',
                message: 'Código promocional no válido o expirado',
            });
        }
        const pct = fila.descuento_porcentaje != null
            ? Number(fila.descuento_porcentaje)
            : null;
        const fijo = fila.descuento_monto != null ? Number(fila.descuento_monto) : null;
        if ((pct == null || pct <= 0) && (fijo == null || fijo <= 0)) {
            throw new common_1.BadRequestException({
                error: 'PROMOCION_SIN_DESCUENTO',
                message: 'Esta promoción no tiene descuento configurado',
            });
        }
        let monto = 0;
        if (pct != null && pct > 0) {
            monto = Math.round((subtotal * pct) / 100);
        }
        else if (fijo != null && fijo > 0) {
            monto = Math.round(fijo);
        }
        monto = Math.min(monto, subtotal);
        if (monto <= 0) {
            throw new common_1.BadRequestException({
                error: 'PROMOCION_SIN_APLICAR',
                message: 'El descuento no aplica al subtotal actual',
            });
        }
        const motivo = fila.titulo?.trim()
            ? `Promoción: ${fila.titulo} (${fila.codigo})`
            : `Promoción ${fila.codigo}`;
        return { promocion_id: fila.id, monto, motivo };
    }
    async resolverMejorAutomatica(client, sucursalId, subtotal) {
        const promos = await client.query(`SELECT id, titulo, descuento_porcentaje, descuento_monto
       FROM estados_promociones
       WHERE sucursal_id = $1
         AND activa = true
         AND (expira_at IS NULL OR expira_at > now())
         AND (codigo IS NULL OR trim(codigo) = '')
         AND (descuento_porcentaje > 0 OR descuento_monto > 0)`, [sucursalId]);
        let mejor = null;
        for (const fila of promos.rows) {
            const pct = fila.descuento_porcentaje != null
                ? Number(fila.descuento_porcentaje)
                : null;
            const fijo = fila.descuento_monto != null ? Number(fila.descuento_monto) : null;
            let monto = 0;
            if (pct != null && pct > 0)
                monto = Math.round((subtotal * pct) / 100);
            else if (fijo != null && fijo > 0)
                monto = Math.round(fijo);
            monto = Math.min(monto, subtotal);
            if (monto <= 0)
                continue;
            if (!mejor || monto > mejor.monto) {
                mejor = {
                    promocion_id: fila.id,
                    monto,
                    motivo: fila.titulo?.trim()
                        ? `Promo automática: ${fila.titulo}`
                        : 'Promoción automática',
                };
            }
        }
        return mejor;
    }
    validarDescuentoDto(porcentaje, monto, codigo) {
        if (codigo?.trim() && porcentaje == null && monto == null) {
            throw new common_1.BadRequestException('Si defines un código, indica descuento_porcentaje o descuento_monto');
        }
        if (porcentaje != null && monto != null) {
            throw new common_1.BadRequestException('Usa solo descuento_porcentaje o descuento_monto, no ambos');
        }
    }
    async registrarVista(promocionId, deviceId) {
        const promo = await this.database.consultarUno(`SELECT id FROM estados_promociones
       WHERE id = $1 AND activa = true
         AND (expira_at IS NULL OR expira_at > now())`, [promocionId]);
        if (!promo)
            throw new common_1.NotFoundException('Promoción no encontrada');
        await this.database.consultar(`INSERT INTO dispositivos_cliente (device_id, ultimo_acceso)
       VALUES ($1, now())
       ON CONFLICT (device_id) DO UPDATE SET ultimo_acceso = now()`, [deviceId]);
        const existente = await this.database.consultarUno(`SELECT id FROM promocion_vistas
       WHERE promocion_id = $1 AND device_id = $2`, [promocionId, deviceId]);
        if (!existente) {
            await this.database.consultar(`INSERT INTO promocion_vistas (promocion_id, device_id) VALUES ($1, $2)`, [promocionId, deviceId]);
            await this.database.consultar(`UPDATE estados_promociones SET vistas = vistas + 1 WHERE id = $1`, [promocionId]);
        }
        return { registrado: true };
    }
    async exigirPromocion(id, sucursalId) {
        const fila = await this.database.consultarUno(`SELECT id FROM estados_promociones WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!fila)
            throw new common_1.NotFoundException('Promoción no encontrada');
    }
    async eliminar(id, sucursalId) {
        const fila = await this.database.consultarUno(`SELECT id, imagen_url FROM estados_promociones WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        if (!fila)
            throw new common_1.NotFoundException('Promoción no encontrada');
        await this.database.consultar(`DELETE FROM promocion_vistas WHERE promocion_id = $1`, [id]);
        await this.database.consultar(`DELETE FROM estados_promociones WHERE id = $1 AND sucursal_id = $2`, [id, sucursalId]);
        await this.almacenamiento.eliminarPorUrl(fila.imagen_url);
        return { eliminado: true };
    }
    async limpiarExpiradas(diasGracia = 7) {
        const gracia = Number.isFinite(diasGracia) && diasGracia >= 0 ? diasGracia : 7;
        const filas = await this.database.consultar(`SELECT id, imagen_url FROM estados_promociones
       WHERE expira_at IS NOT NULL
         AND expira_at < now() - ($1::int * interval '1 day')
       LIMIT 200`, [gracia]);
        let objetos = 0;
        for (const f of filas) {
            if (await this.almacenamiento.eliminarPorUrl(f.imagen_url))
                objetos += 1;
            await this.database.consultar(`DELETE FROM promocion_vistas WHERE promocion_id = $1`, [f.id]);
            await this.database.consultar(`DELETE FROM estados_promociones WHERE id = $1`, [f.id]);
        }
        if (filas.length > 0) {
            this.logger.log(`Limpieza estados: ${filas.length} filas, ${objetos} objetos Storage`);
        }
        return { filas: filas.length, objetos_storage: objetos };
    }
    async exigirProductoDeSucursal(productoId, sucursalId) {
        const fila = await this.database.consultarUno(`SELECT id FROM productos
       WHERE id = $1 AND sucursal_id = $2 AND disponible = true`, [productoId, sucursalId]);
        if (!fila) {
            throw new common_1.BadRequestException('El producto no pertenece a esta sede o no está disponible');
        }
    }
};
exports.PromocionesService = PromocionesService;
exports.PromocionesService = PromocionesService = PromocionesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService,
        almacenamiento_service_1.AlmacenamientoService])
], PromocionesService);
//# sourceMappingURL=promociones.service.js.map