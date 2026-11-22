# Remediación Nest / Auth — 2026-08-07

> Cierre de deuda **BN-\*** (Prompt 02) + **AUTH-FLOW/REV** (Prompt 05).  
> Estado oficial: `MASTER_STATUS.md` · Detalle técnico: `AVANCE_PROYECTO.md` · IDs: `archivo/auditorias-prompts/AUDITORIA_BACKEND_NESTJS.md` + `AUDITORIA_AUTH_JWT.md`.

**Para qué sirve (producto):** endurecer la API antes de go-live — entradas basura rechazadas, sesiones revocables, authz de usuarios/traslados en services, fallos de billing/impresión visibles. **No** es UI nueva ni módulo de negocio.

---

## 1. Qué se implementó (cerrado ✅)

| ID | Qué hace | Archivos / scripts clave |
|----|----------|---------------------------|
| **AUTH-FLOW / AUTH-REV** | JWT claim `tv` + `token_version` (mig `084`); `POST /auth/refresh` (mismo `tv`); `POST /auth/logout` (bump); password bump; Flutter logout→API + Dio refresh/retry 401 | `084_*.sql`, `auth.*`, `cliente_dio.dart`, `verificar-auth-flow.ps1` |
| **BN-FIX-01** | Upload catálogo: SQL/ownership/cache fuera del controller | `almacenamiento.service.ts`, `verificar-bn-almacenamiento.ps1` |
| **BN-FIX-02/03** | DTOs dispositivos + mutaciones inline 06…19 | `dispositivos.dto.ts`, DTOs pedidos/catálogo/…, `verificar-bn-dto-inline.ps1` |
| **BN-FIX-04** | Query DTOs promo/geografía; `@IsBoolean` CrearPedido; Cotizar cableado | `ValidarCodigoPromocionDto`, `BuscarGeografiaDto`, `verificar-bn-dto-query.ps1` |
| **BN-FIX-05** | Fallos fuente Wompi auditados; cron expone `renovaciones_fallos` | `pagos.service`, `suscripciones-cron.service` |
| **BN-FIX-06** | `ValidationPipe({ whitelist, forbidNonWhitelisted, transform })` | `main.ts`, `verificar-bn-pipe-forbid.ps1` |
| **BN-DTO-01/02** | Bodies FCM con class-validator | `dto/fcm.dto.ts`, `verificar-bn-dto-fcm.ps1` |
| **BN-CTRL-02** | Authz crear/actualizar usuarios (sede + gerente_cadena) en service | `usuarios.service.ts`, `verificar-bn-ctrl-usuarios.ps1` |
| **BN-CTRL-03** | Gate traslados / hermanas en InventarioService | `inventario.service.ts` |
| **BN-EXC-18** | Fallo encolar impresión → job `estado=error` (pedido no se tumba) | `impresion.service.ts` |
| **RT-SCRIPT-01** | Script realtime lee `/health` (no `/salud`) | `verificar-realtime.ps1` |
| **FL-LEAK-01/02** | Dispose TEC inventario; `FoodyRealtime.liberarCanal` | Flutter |

---

## 2. Verificación ejecutada (evidencia)

API local `:3000`, demo `admin@foody.demo` / `123456`, `GET /salud` → `exito: true` tras `npm run build` + restart.

| Check | Resultado | Notas |
|-------|-----------|--------|
| `verificar-bn-pipe-forbid.ps1` | ✅ OK | login / disponibilidad / cotizar rechazan prop extra |
| `verificar-bn-dto-query.ps1` | ✅ OK | UUID inválido, geografía sin `q`, bool basura en pedido |
| `verificar-bn-dto-fcm.ps1` | ✅ OK | sin token / prop extra / registrar + desactivar |
| `verificar-bn-ctrl-usuarios.ps1` | ✅ OK | crear cajero; gerente_cadena OK (admin demo **es** corporativo vía `gestionar_sucursales`) |
| `verificar-usuarios-editar.ps1` | ✅ OK | catálogo + PATCH |
| `GET /inventario/hermanas/resumen` | ✅ 200 | `puede_ver_hermanas=true` |
| `verificar-auth-flow.ps1` | ✅ OK (sesión previa) | refresh / logout / 401 post-logout — **no re-corrido en el último lote** |
| `verificar-bn-almacenamiento.ps1` / `verificar-bn-dto-inline.ps1` | ✅ OK (sesión previa) | |

### Qué **no** se probó (gaps de QA)

| Gap | Severidad | Por qué importa |
|-----|-----------|-----------------|
| Click-through Flutter (login/logout UI, FCM real en dispositivo) | Media | Contrato API OK; UX/plugin no revalidada en esta tanda |
| Photon / `GET /geografia/buscar?q=…` feliz | Baja (DX) | Offline local → 400 `No se pudo consultar el servicio de direcciones` (DTO OK; dependencia externa) |
| Código promo seed real en `validar-codigo` | Baja | Solo se validó rechazo de UUID / código inexistente (negocio 400) |
| Impresora térmica física + agente Python | Alta (F5) | BN-EXC-18 solo garantiza job error en BD, no ticket papel |
| Wompi dashboard / renovación real | Alta (F5) | Auditoría de fallo fuente; no pago E2E prod |
| VPS + tunnel + backups | Alta (F5/F8) | Código local ≠ go-live |
| 403 gerente_cadena con actor **no** corporativo | Baja | Demo admin tiene `gestionar_sucursales`; falta usuario seed “solo sede” sin ese permiso para assert 403 |
| Traslado invent. 403 sin permiso hermanas | Baja | Smoke hermanas con admin OK; no se forzó actor sin permiso |
| Re-run `verificar-auth-flow.ps1` post-BN-CTRL | Baja | Distinto dominio; regenerar confianza al tocar auth otra vez |

---

## 3. Detalles a pulir (abiertos / residuales)

### 3.1 Nest — validación residual (código, bajo–medio)

| ID | Estado | Detalle a pulir |
|----|--------|-----------------|
| **BN-DTO-23** | ✅ | `GET /auditoria/timeline` — `TimelineAuditoriaDto` | `verificar-bn-dto-auditoria.ps1` |
| **BN-DTO-24** | ✅ | `GET /pedidos`, `cerrados-hoy` | `verificar-bn-dto-query-rest.ps1` |
| **BN-DTO-25** | ✅ | Costeo `impacto-stock` | idem |
| **BN-DTO-26** | ✅ | Uploads imagen/video query | idem |
| **BN-DTO-27** | ✅ | `GET /pagos/retorno-app` `pago_id` UUID opcional | idem |
| **BN-DTO-28** | ✅ | `AprobarPedidoMesaDto` + body `{}` validado | `verificar-bn-residuales.ps1` |
| **BN-DTO-33** | ✅ | ParseUUIDPipe hot paths (mesas/catálogo/…) | idem |
| **BN-MOD-03** | 🟡 | Dual `/salud` + `/health` + alias `/salud/completo` | aceptado |
| **BN-PIPE-04** | 🟡 | Sin implicit conversion global; `@Type` en DTOs | aceptado |
| **BN-DTO-05** | 🟡 | Webhook Wompi = `Record` (firma aparte; OK aceptado) | |
| **BN-PIPE-05** | 🟡 | Pipe en `main.ts` vs filter en `AppModule` (DX) | |
| **BN-EXC-03/04** | ✅ | Recurrentes: throw sin source; error + `consulta_fallida` | Código; E2E Wompi pendiente |
| **BN-CTRL-04/05/07/10–12** | ✅ | Gates/parse en services (2026-08-11) | `verificar-bn-ctrl-04.ps1` |
| **BN-MOD-05** | ✅ | SQL ventas compartido reportes/analítica/dashboard | `verificar-bn-mod-05.ps1` |
| **BN-MOD-08…13** | 🟣 | God modules/services (pedidos, catálogo, analítica, inventario) — post-MVP |

### 3.2 Auth — residuales

| ID | Estado | Detalle a pulir |
|----|--------|-----------------|
| **AUTH-FLOW-05** | 🟡 | Perfil puede re-emitir token si cambian plan/permisos/`tv` — documentar/contrato Flutter |
| **AUTH-FLOW-06 / AUTH-FIX-02** | 🟡 | TTL JWT default **7 días**; acortar en prod con `JWT_EXPIRACION` |
| **AUTH-EXP-01** | 🟡 | Retry 1× no salva mutación no-idempotente si el JWT ya está revocado |
| **AUTH-EXP-04** | 🟣 | Refresh mid-call cliente Supabase (no staff) |
| **AUTH-FIX-06** | 📅 | WhatsApp OTP solo si producto lo pide |
| **AUTH-FB-01** | 🟡 | Ruido Firebase Identity Toolkit en consola web (no bloquea Nest) |

### 3.3 Go-live humano (no es “falta un DTO”)

| Ítem | Doc | Estado |
|------|-----|--------|
| Impresora térmica + agente | `CHECKLIST_F5_GOLIVE.md`, `IMPRESION_RESTAURANTE.md` | 🟡 F5 |
| Wompi prod / dashboard | `WOMPI_PRODUCCION.md` | 🟡 F5 |
| VPS + tunnel + backups | `PREPARACION_VPS.md`, `BACKUPS_FOODY.md` | 🟡 F5/F8 / P0 |
| Photon (geocoding) estable en entorno QA | config env Photon URL | 🟡 DX local |

### 3.4 Scripts / DX a pulir

- Añadir seed o usuario demo **sin** `gestionar_sucursales` para assert 403 en `verificar-bn-ctrl-usuarios.ps1`.
- Extender script inventarios: actor sin hermanas → 403 en `POST /inventario/traslados`.
- Incluir `verificar-bn-*` / `verificar-auth-flow` en `verificar-ci.ps1 -Completo` (listados en `CI_E2E.md`; aún no orquestados).
- Re-correr `verificar-auth-flow.ps1` en cada tanda que toque `auth.*` o guards.
- Geografía: en script, distinguir explícitamente error Photon vs pipe (ya parcialmente hecho).

---

## 4. Cómo re-verificar en 5 minutos

```powershell
# API arriba + migracion 084 aplicada
.\scripts\verificar-bn-pipe-forbid.ps1
.\scripts\verificar-bn-dto-query.ps1
.\scripts\verificar-bn-dto-fcm.ps1
.\scripts\verificar-bn-ctrl-usuarios.ps1
.\scripts\verificar-auth-flow.ps1
.\scripts\verificar-usuarios-editar.ps1
```

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-07 | Residuales BN-DTO-28/33 · MOD-03 · PIPE-04; `verificar-bn-residuales.ps1` |
| 2026-08-07 | BN-DTO-24…27 ✅ `verificar-bn-dto-query-rest.ps1` |
| 2026-08-07 | BN-DTO-23 ✅ + BN-EXC-03/04 ✅; scripts auditoria |
| 2026-08-07 | Creación: cerrado BN/AUTH, evidencia scripts, gaps QA, lista a pulir |
| 2026-08-07 | Añadidos BN-EXC-03/04 + BN-CTRL-04…12 en §3.1; DX CI orquestación; sync MASTER/AVANCE/AUTH/CI_E2E |
