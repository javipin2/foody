/**
 * Aislamiento explícito para API E2E local. No debe activarse en desarrollo
 * normal ni en producción: omite integraciones y workers de arranque para que
 * una suite no contacte proveedores ni procese colas fuera de la prueba.
 */
export function esQaSinEfectosExternos(): boolean {
  return process.env.FOODY_QA_SIN_EFECTOS === '1';
}
