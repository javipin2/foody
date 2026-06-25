import {
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { JwtPayload } from './jwt-payload';

/** Permiso corporativo: operar varias sucursales del mismo restaurante. */
export const PERMISO_OPERAR_MULTI_SUCURSAL = 'gestionar_sucursales';

/** Solo lectura de inventario en sucursales hermanas. */
export const PERMISO_VER_INVENTARIO_HERMANAS =
  'ver_inventario_otras_sucursales';

@Injectable()
export class SucursalScopeService {
  constructor(private readonly database: DatabaseService) {}

  esCorporativo(usuario: JwtPayload): boolean {
    return (
      usuario.permisos?.includes(PERMISO_OPERAR_MULTI_SUCURSAL) ?? false
    );
  }

  puedeVerInventarioHermanas(usuario: JwtPayload): boolean {
    return (
      this.esCorporativo(usuario) ||
      (usuario.permisos?.includes(PERMISO_VER_INVENTARIO_HERMANAS) ?? false)
    );
  }

  resolverSucursalId(usuario: JwtPayload, solicitada?: string | null): string {
    const id = solicitada ?? usuario.sucursal_id;
    if (!id) {
      throw new UnauthorizedException('Usuario sin sucursal asignada');
    }
    return id;
  }

  async assertPerteneceRestaurante(
    sucursalId: string,
    restauranteId: string,
  ): Promise<void> {
    const fila = await this.database.consultarUno<{ id: string }>(
      `SELECT id FROM sucursales
       WHERE id = $1 AND restaurante_id = $2 AND activa = true`,
      [sucursalId, restauranteId],
    );
    if (!fila) {
      throw new ForbiddenException(
        'La sucursal no pertenece a tu restaurante o está inactiva',
      );
    }
  }

  /** Lectura de módulos operativos (pedidos, caja, menú, dashboard…). */
  async validarLecturaOperativa(
    usuario: JwtPayload,
    sucursalId: string,
  ): Promise<void> {
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Usuario sin restaurante asignado');
    }
    await this.assertPerteneceRestaurante(
      sucursalId,
      usuario.restaurante_id,
    );
    if (sucursalId === usuario.sucursal_id) return;
    if (!this.esCorporativo(usuario)) {
      throw new ForbiddenException(
        'Solo puedes consultar la operación de tu sucursal asignada',
      );
    }
  }

  /** Lectura de inventario (propia u otra sede con permiso). */
  async validarLecturaInventario(
    usuario: JwtPayload,
    sucursalId: string,
  ): Promise<void> {
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Usuario sin restaurante asignado');
    }
    await this.assertPerteneceRestaurante(
      sucursalId,
      usuario.restaurante_id,
    );
    if (sucursalId === usuario.sucursal_id) return;
    if (!this.puedeVerInventarioHermanas(usuario)) {
      throw new ForbiddenException(
        'No tienes permiso para ver inventario de otras sucursales',
      );
    }
  }

  /** Escritura: solo sucursal del JWT o rol corporativo. */
  async validarEscritura(
    usuario: JwtPayload,
    sucursalId: string,
  ): Promise<void> {
    if (!usuario.restaurante_id) {
      throw new ForbiddenException('Usuario sin restaurante asignado');
    }
    await this.assertPerteneceRestaurante(
      sucursalId,
      usuario.restaurante_id,
    );
    if (sucursalId === usuario.sucursal_id) return;
    if (!this.esCorporativo(usuario)) {
      throw new ForbiddenException(
        'Solo puedes modificar datos de tu sucursal asignada',
      );
    }
  }

  async resolverLecturaOperativa(
    usuario: JwtPayload,
    solicitada?: string | null,
  ): Promise<string> {
    const id = this.resolverSucursalId(usuario, solicitada);
    await this.validarLecturaOperativa(usuario, id);
    return id;
  }

  async resolverLecturaInventario(
    usuario: JwtPayload,
    solicitada?: string | null,
  ): Promise<string> {
    const id = this.resolverSucursalId(usuario, solicitada);
    await this.validarLecturaInventario(usuario, id);
    return id;
  }

  async resolverEscritura(
    usuario: JwtPayload,
    solicitada?: string | null,
  ): Promise<string> {
    const id = this.resolverSucursalId(usuario, solicitada);
    await this.validarEscritura(usuario, id);
    return id;
  }
}
