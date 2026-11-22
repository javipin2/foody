/**
 * Antispike registro self-service (VIRAL-FIX-01/04/05).
 * Env:
 * - REGISTRO_RESTAURANTE_ABIERTO=0|1 (default 1)
 * - REGISTRO_CUPO_DIARIO=N (0 = sin cupo; prod tipico 50–200)
 * - REGISTRO_MAX_POR_MINUTO=N (0 = sin techo global; tipico 20–40)
 * - BCRYPT_ROUNDS=8..12 (default 10)
 */
export function registroSelfServiceAbierto(): boolean {
  const v = (process.env.REGISTRO_RESTAURANTE_ABIERTO ?? '1').trim().toLowerCase();
  return !(v === '0' || v === 'false' || v === 'off' || v === 'no');
}

export function registroCupoDiario(): number {
  const n = Number(process.env.REGISTRO_CUPO_DIARIO ?? '0');
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.floor(n);
}

export function registroMaxPorMinuto(): number {
  const n = Number(process.env.REGISTRO_MAX_POR_MINUTO ?? '0');
  if (!Number.isFinite(n) || n < 0) return 0;
  return Math.floor(n);
}

export function bcryptRoundsRegistro(): number {
  const n = Number(process.env.BCRYPT_ROUNDS ?? '10');
  if (!Number.isFinite(n)) return 10;
  return Math.min(12, Math.max(8, Math.floor(n)));
}
