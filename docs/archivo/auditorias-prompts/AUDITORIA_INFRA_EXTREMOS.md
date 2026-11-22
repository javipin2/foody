# Foody — Casos extremos de infraestructura · Prompt 34

> **Fecha:** 2026-08-06  
> **Perspectiva:** red lenta, doble submit, API caída, reconexión.  
> **Base:** Dio + Nest TX + Realtime (reusa RT-\* / API-IDEM-\*).  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § Infra extremos (INFRA-EXT-\*).

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ OK

---

## Veredicto

| Escenario | Qué pasa hoy | Riesgo ops |
|-----------|--------------|------------|
| Internet lento / timeout mid-TX | Cliente corta a **15s connect / 45s receive**; Nest puede **COMMIT igual** tras el timeout | Alta — usuario reintenta con UX confusa |
| Doble clic cobrar | Backend **seguro** (`FOR UPDATE` + `PEDIDO_CERRADO`/`SIN_SALDO`); UI mesa/kanban **sin busy** en cobro | Media — 2º click error, no doble venta |
| Doble clic crear pedido | Checkout/POS: `_enviando` + `idempotency_key` (UUID fijo en pantalla) | Bajo |
| Backend caído | Mensaje claro vía `mensajeErrorHttp` / `mensajeErrorCliente`; hang hasta timeout | Media — hasta **45 s** de spinner |
| Reconexión Realtime | Socket re-une; **sin refetch** ni replay (≡ **RT-RECON-01**) | Alta — UI desfasada |

---

## Verificación en vivo (esta sesión)

| Check | Resultado |
|-------|-----------|
| `GET /salud` | ✅ |
| Host muerto `:3999` | ✅ falla ~2 s |
| 2× `POST …/cobrar` paralelo | ✅ **1 OK + 1 rechazado** |
| Timeouts Dio en `Configuracion` | ✅ 15s / 45s |
| Guards UI checkout/POS | ✅ `_enviando` + idempotency |
| Gaps UI cobro mesa/kanban/KDS | 🟣 NOTE (script) |

Script: `scripts/verificar-infra-extremos.ps1`.

---

## 1. Internet lento / timeout parcial mid-TX

### Cliente (Dio)

| Constante | Valor | Archivo |
|-----------|------:|---------|
| `timeoutConexion` | 15 s | `lib/core/constantes/configuracion.dart` |
| `timeoutRespuesta` | 45 s | idem |
| `sendTimeout` | **no definido** | `cliente_dio.dart` solo connect+receive |

Mensajes: `mensaje_error_http.dart` mapea `connectionTimeout` / `receiveTimeout` / `connectionError` → «Sin conexión con el servidor…»; cliente final → «No pudimos conectar…».

### Servidor (Nest + Postgres)

Operaciones críticas (crear pedido, cobrar, cambiar estado, KDS ítem) usan `database.enTransaccion` + a menudo `FOR UPDATE`.

**Hallazgo INFRA-EXT-TO-01 (Alta):** si el cliente hace **timeout** mientras la TX sigue en el servidor:

1. Nest puede **COMMIT** igual (el abort del HTTP no cancela la TX PG ya en curso).
2. Flutter muestra error de red.
3. Usuario reintenta → cobro: 2º intento → `PEDIDO_CERRADO` / `SIN_SALDO` (no doble venta, pero UX «falló» cuando sí cobró).
4. Crear pedido **con** `idempotency_key` (checkout): 2º intento devuelve el mismo pedido ✅.
5. Crear pedido **sin** clave (algunos staff paths): riesgo de **duplicar** pedido si el 1º llegó a COMMIT.

**Hallazgo INFRA-EXT-TO-02 (Media):** no hay `sendTimeout`; en uplink muy lento el request puede colgar más tiempo del esperado antes del receive.

**Mitigación existente:** `FOR UPDATE` en cobro (API-IDEM-02); idempotencia fuerte solo en crear pedido público/checkout.

**Fix sugerido:** clave idempotencia en cobro (API-FIX-03); tras timeout de cobro, UI hace `GET detalle` antes de reintentar; opcional `sendTimeout` ~30 s.

---

## 2. Doble clic / doble submit

| Acción | UI guard | Backend | ID |
|--------|----------|---------|-----|
| Checkout cliente confirmar | `_enviando` + botón null; `idempotency_key` estable | `pedidos_idempotencia` | ✅ |
| POS cajero confirmar | `_enviando` | crear staff (idempotency opcional) | 🟡 |
| Cobrar mesa (`mesa_pedidos_sheet`) | Diálogo; **sin** `_cobrando` durante await | `FOR UPDATE` + cerrado | **INFRA-EXT-UI-01** 🟣 |
| Cobrar kanban para llevar | Diálogo; **sin** busy post-confirm | idem | **INFRA-EXT-UI-02** 🟣 |
| KDS cambiar ítem | `_itemsEnVuelo` + `_conLockItem` | UPDATE + FOR UPDATE pedido | **INFRA-EXT-UI-03** ✅ |
| KDS marcar todo listo | `_marcandoTodo` Set | idempotente en práctica (ya listo skip) | ✅ parcial |

**Evidencia vivo:** 2 cobros paralelos → exactamente 1 éxito (script B).

**INFRA-EXT-DBL-01 (Media):** backend evita doble cargo; UI puede mostrar 2 spinners / 2 snackbars error. No es pérdida de dinero si cobro total; abonos parciales concurrentes quedan serializados por lock (segundo ve saldo actualizado).

---

## 3. Backend caído — ¿estado claro o colgado?

| Capa | Comportamiento |
|------|----------------|
| Dio | Espera connect ≤15 s / receive ≤45 s → `DioException` |
| `mensajeErrorHttp` | Texto explícito (API apagada / sin conexión) |
| `mensajeErrorCliente` | Suaviza jerga infra |
| Splash staff | Timeout 8 s en sync permisos → **entra al panel con sesión local** (offline parcial) |
| Pantallas con `_error` | Muchas muestran botón Reintentar (caja, KDS, seguimiento, etc.) |

**INFRA-EXT-DOWN-01 (Media):** no hay banner global «API offline»; cada pantalla depende de su `catch`. Usuario puede ver spinner hasta **45 s**.

**INFRA-EXT-DOWN-02 (Media):** splash equipo con API caída **sigue al dashboard** con JWT local — pantallas posteriores fallan una a una (no hay modo offline tipado).

**INFRA-EXT-DOWN-03 (Baja):** host muerto falla ~2 s (probe); peor caso = timeout Dio completo.

---

## 4. Reconexión automática / re-sync

Reusa auditoría Realtime ([`AUDITORIA_REALTIME.md`](AUDITORIA_REALTIME.md)):

| ID previo | Relevancia Prompt 34 |
|-----------|----------------------|
| **RT-RECON-01** | Reconecta canal; **sin refetch** → UI desfasada |
| **RT-POLL-01** | Intervalo poll fijo al abrir |
| **RT-FALL-01** | Menú/POS sin poll |
| **RT-LIFE-01** | Sin refetch en `AppLifecycleState.resumed` |
| **VIE-12** | Mismo síntoma viernes (Wi‑Fi vuelve, datos viejos) |

**INFRA-EXT-SYNC-01:** alias de producto para RT-RECON + RT-LIFE en contexto «caída de API/red» (no solo Realtime). Tras Nest restart: pedidos viven en PG ✅ (VIE-11); Flutter **no** se entera hasta poll/pull-to-refresh.

No hay interceptor Dio que, al recuperar conectividad, dispare refresh global de pantallas abiertas.

---

## Matriz de hallazgos Prompt 34

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| **INFRA-EXT-TO-01** | Alta | Timeout cliente mid-TX: COMMIT posible + retry confuso | 🟣 |
| **INFRA-EXT-TO-02** | Media | Sin `sendTimeout` Dio | 🟣 |
| **INFRA-EXT-UI-01** | Media | Cobro mesa sin flag `_cobrando` | 🟣 |
| **INFRA-EXT-UI-02** | Media | Cobro kanban sin busy | 🟣 |
| **INFRA-EXT-UI-03** | Baja | KDS `_itemsEnVuelo` + `_conLockItem` | ✅ |
| **INFRA-EXT-DBL-01** | — | Doble cobro paralelo: 1 OK / 1 reject (backend OK) | ✅ |
| **INFRA-EXT-DOWN-01** | Media | `ApiOfflineBanner` en panel (poll `/salud` 20s) | ✅ |
| **INFRA-EXT-DOWN-02** | Media | Splash staff: diálogo Reintentar/Login si sync permisos falla (no entra a panel) | ✅ |
| **INFRA-EXT-SYNC-01** | Alta | Post-caída sin re-sync (= RT-RECON / RT-LIFE / VIE-12) | 🟣 |
| **INFRA-EXT-MSG-01** | — | Mensajes timeout/conexión presentes | ✅ |

---

## Backlog fix (prioridad)

1. **INFRA-EXT-FIX-01** — Tras error de red en cobro: `GET` estado antes de reintentar + snackbar «Verificando cobro…» (TO-01).
2. **INFRA-EXT-FIX-02** — `_cobrando` / busy en mesa + kanban (UI-01/02); disable botón KDS por ítem (UI-03).
3. **API-FIX-03** — Idempotency key en cobro (ya en AUDITORIA_APIS_REST).
4. **RT-FIX-02/05** — Refetch al reconnect + `resumed` (SYNC-01).
5. **INFRA-EXT-FIX-03** — Banner/connectivity listener opcional; splash no navegar a panel si `/salud` falla (DOWN-02).
6. **INFRA-EXT-FIX-04** — `sendTimeout` Dio ~30 s (TO-02).

---

## Relación con prompts previos

| Prompt | Solape |
|--------|--------|
| 04 APIs | API-IDEM-02 cobro sin clave |
| 10 Realtime | RT-RECON / POLL / LIFE / FALL |
| 26 Concurrencia | FOR UPDATE cobro/pedido |
| 30 Viernes | VIE-11 restart PG · VIE-12 reconnect |
| 33 E2E | No cubre timeouts; sí cobro happy path |
