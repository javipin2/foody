import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/** Tope cuando el cliente no manda `page` (kanban/admin legacy = array). */
export const LIMITE_LISTADO_SIN_PAGINA = 200;

/** Query params estándar para listados paginados. */
export class PaginacionQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}

export interface ResultadoPaginado<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export function resolverPaginacion(
  page?: number,
  limit?: number,
  limitPorDefecto = 20,
): { page: number; limit: number; offset: number } {
  const p = Math.max(1, page ?? 1);
  const l = Math.min(100, Math.max(1, limit ?? limitPorDefecto));
  return { page: p, limit: l, offset: (p - 1) * l };
}

export function envolverPaginado<T>(
  items: T[],
  total: number,
  page: number,
  limit: number,
): ResultadoPaginado<T> {
  return {
    items,
    total,
    page,
    limit,
    totalPages: total === 0 ? 0 : Math.ceil(total / limit),
  };
}

/** Opt-in: con `page` → meta; sin `page` → array con tope (API-PAGE). */
export function opcionesListado(
  query: PaginacionQueryDto,
  limitPorDefectoPagina = 50,
): { paginar: boolean; page?: number; limite: number } {
  if (query.page != null) {
    const { page, limit } = resolverPaginacion(
      query.page,
      query.limit,
      limitPorDefectoPagina,
    );
    return { paginar: true, page, limite: limit };
  }
  const tope = query.limit != null
    ? Math.min(100, Math.max(1, query.limit))
    : LIMITE_LISTADO_SIN_PAGINA;
  return { paginar: false, limite: tope };
}
