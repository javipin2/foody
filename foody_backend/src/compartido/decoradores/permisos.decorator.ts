import { SetMetadata } from '@nestjs/common';

export const PERMISOS_KEY = 'permisos';
export const PERMISOS_TODOS_KEY = 'permisos_todos';
export const Permisos = (...permisos: string[]) =>
  SetMetadata(PERMISOS_KEY, permisos);
export const PermisosTodos = (...permisos: string[]) =>
  SetMetadata(PERMISOS_TODOS_KEY, permisos);
