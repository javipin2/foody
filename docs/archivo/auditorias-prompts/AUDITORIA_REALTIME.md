# Auditoría Realtime y sincronización (Prompt 10 — Bloque C)

**Fecha:** 2026-08-06 · **Alcance:** eventos broadcast backend ↔ Flutter, reconexión, fallbacks, consistencia multi-dispositivo.

**Resultado:** 1 bug crítico **corregido y verificado** (`RT-CHAN-01`), 1 fuga de confidencialidad **abierta** (`RT-SEC-01`) y 7 hallazgos más (resiliencia, fuga de canales, configuración, tooling). Sin eventos huérfanos reales.

| ID | Sev | Hallazgo | Estado |
|----|-----|----------|--------|
| `RT-CHAN-01` | Crítica | Menú cliente y POS con suscripción muerta al canal de catálogo | ✅ Corregido |
| `RT-SEC-01` | Alta | Canales broadcast no privados: anon key escucha la caja | ✅ HMAC topics 2026-08-08 |
| `RT-RECON-01` | Alta | Reconecta bien, pero sin replay ni refetch tras el corte | 🟣 |
| `RT-POLL-01` | Media-Alta | Intervalo de poll fijado una sola vez al abrir la pantalla | 🟣 |
| `RT-FALL-01` | Media | 4 pantallas realtime sin poll de respaldo | 🟣 |
| `RT-LIFE-01` | Media | Sin refetch al volver de segundo plano | 🟣 |
| `RT-LEAK-01` | Media | 9 pantallas con `unsubscribe` sin `removeChannel` | 🟣 |
| `RT-ENV-01` | Media | `SUPABASE_URL` duplicada y activa en `.env` | 🟣 |
| `RT-SCRIPT-01` | Baja | `verificar-realtime.ps1` lee un campo de salud inexistente | ✅ |
| `RT-ORPH-01` | — | Sin eventos huérfanos ni oyentes sin emisor | ✅ |

> Estrategia oficial: [`ESTRATEGIA_REALTIME_FOODY.md`](ESTRATEGIA_REALTIME_FOODY.md) · QA: [`CHECKLIST_QA_REALTIME.md`](CHECKLIST_QA_REALTIME.md)

---

## 0. Arquitectura confirmada

No existe WebSocket ni SSE del backend hacia las apps. Toda la salida realtime es **Supabase broadcast**:

| Capa | Archivo | Rol |
|------|---------|-----|
| Emisor | `foody_backend/src/core/realtime/realtime-broadcast.service.ts` | 16 eventos, service key, `ack: false`, post-commit |
| Receptor | `lib/core/realtime/foody_realtime.dart` | 7 tipos de canal, solo broadcast (nunca `postgres_changes`) |
| Respaldo | `lib/core/realtime/poll_realtime_respaldo.dart` | Poll 45 s / 90 s según salud RT |
| Dedup | `lib/core/realtime/evento_dedup.dart` | Por `event_id`, ventana 12 s |

El WebSocket de impresión (`impresion.service.ts` → agente Python `:8765`) es un bus **separado**: NestJS actúa de cliente, no llega a Flutter.

A nivel BD **no hay** `ALTER PUBLICATION supabase_realtime` ni `REPLICA IDENTITY FULL`, y RLS es deny-all en las 73 tablas — coherente con el diseño, porque ningún cliente usa CDC.

---

## 1. Mapa de eventos: emisor → oyente

Los 16 pares emisor/oyente están verificados en ejecución por `scripts/verificar-realtime-canales.js`.

| Evento | Canal | Pantallas que lo consumen |
|--------|-------|---------------------------|
| `pedido_actualizado` | `sucursal_{id}` | Kanban, grid mesas, sheet mesa, domiciliarios admin |
| `mesas_actualizadas` | `sucursal_{id}` | Grid mesas, sheet mesa |
| `caja_movimiento` | `sucursal_{id}` | Caja admin |
| `alerta_nueva` | `sucursal_{id}` | Alertas admin |
| `qr_aprobacion_urgente` | `sucursal_{id}` | Grid mesero |
| `llamar_mesera` | `sucursal_{id}` | Grid mesero |
| `catalogo_disponibilidad` | `sucursal_{id}` **+** `sucursal_{id}_catalogo` | Paneles staff **+** menú cliente / POS cajero |
| `estado_actualizado` | `pedido_{id}_{token}` | Seguimiento cliente |
| `ubicacion_repartidor` | `pedido_{id}_{token}` | Seguimiento cliente (mapa) |
| `cocina_actualizada` | `cocina_{id}` | KDS |
| `suscripcion_actualizada` | `restaurante_{id}` | Panel restaurante |
| `pedido_asignado` / `pedido_desasignado` | `domiciliario_{usuario_id}` | Dashboard domiciliario planta |
| `oferta_nueva` / `oferta_expirada` | `domiciliario_indep_{id}` | Dashboard domiciliario independiente |
| `ping` | `foody_health_check` | Healthcheck interno del backend (sin oyente Flutter, correcto) |

---

## 2. Hallazgos

### RT-CHAN-01 — Crítico — ✅ CORREGIDO

`catalogo_disponibilidad` se emitía **solo** en `sucursal_{id}`, pero `FoodyRealtime.suscribirCatalogo` escucha `sucursal_{id}_catalogo`. El menú del cliente (`menu_screen_foody.dart:69`) y el POS cajero (`pedido_cajero_screen.dart:104`) tenían una **suscripción muerta**: agotar un producto nunca refrescaba los menús abiertos, así que los clientes seguían pidiendo productos sin stock hasta recargar a mano.

Los paneles de staff sí lo recibían (`suscribirSucursal` escucha el mismo evento en el canal correcto), lo que ocultó el fallo.

**Corrección:** `catalogoDisponibilidad()` emite ahora en ambos topics. Se mantienen dos canales a propósito — ver `RT-SEC-01`: los dispositivos de cliente anónimo no deben recibir los payloads de staff del canal de sucursal. Cada envío lleva su propio `event_id`, necesario porque `EventoDedup` es global y un id compartido haría que la segunda entrega se descartara.

Por qué no lo detectó `verificar-realtime.ps1`: solo hace grep del **nombre del evento** en ambos lados, nunca compara **topics**. Cubierto ahora por `scripts/verificar-realtime-canales.js`.

### RT-SEC-01 — Alta — ✅ Cerrado 2026-08-08 (HMAC topics)

**Mitigación piloto (sin Realtime Authorization nativo en self-hosted):**

- Nest firma topics staff: `sucursal_{id}_{hmac16}` (`realtime-topics.ts` + `RealtimeBroadcastService`).
- Login / refresh / `GET /auth/realtime-canales` entregan `realtime_canales` al cliente.
- Flutter `FoodyRealtime` solo se une a topics firmados para staff; `*_catalogo` y `pedido_*_*` siguen públicos.
- Anon + UUID de QR **ya no** alcanza: el backend no emite en `sucursal_{uuid}` plano.

**Check:** `scripts/verificar-rt-sec.ps1` + `verificar-realtime-canales.js` (leak anon = OK no recibe).

**Upgrade futuro:** `private: true` + RLS `realtime.messages` + JWT Supabase cuando el stack self-hosted lo soporte de forma estable.

Corresponde a **OPS-07 / P0-09** — cerrado a nivel leak tenant para piloto.

### RT-RECON-01 — Alta — 🟣 Abierta

**La reconexión sí funciona a nivel de transporte.** `realtime_client 2.7.1` reconecta con backoff (1 s → 10 s tope, `retry_timer.dart:51-60`) y cada canal se re-une con su mismo topic vía `_rejoinTimer` (`realtime_channel.dart:55`). No hay riesgo de re-suscribirse al canal equivocado.

El problema es lo que pasa **después**: broadcast no tiene replay ni buffer, y `ack: false`. Los eventos emitidos durante el corte se pierden definitivamente, y nada dispara un refetch al reconectar. La pantalla queda silenciosamente desincronizada hasta el siguiente tick de poll (hasta 90 s) o un pull-to-refresh.

Agrava: `enviarBroadcast` (`realtime-broadcast.service.ts:324-326`) traga los fallos con un `logger.warn` y sin reintento; con `ack: false` el backend tampoco sabe si el evento se entregó.

**Fix propuesto:** pasar el callback de estado a `subscribe()` en `FoodyRealtime` y, al recibir `subscribed` tras un `channelError`/`timedOut`, invocar el mismo `onEvento` de recarga.

### RT-POLL-01 — Media-Alta — 🟣 Abierta

`PollRealtimeRespaldo.iniciar()` (`poll_realtime_respaldo.dart:18-38`) consulta la salud de Realtime **una sola vez** y fija el intervalo para toda la vida de la pantalla. Si Realtime estaba sano al abrir (90 s) y cae después, el respaldo sigue a 90 s — justo el escenario para el que existe el respaldo.

Además el intervalo real (45–90 s) no coincide con el contrato documentado en `ESTRATEGIA_REALTIME_FOODY.md:327-334`, que promete 5–10 s en modo degradado.

### RT-FALL-01 — Media — 🟣 Abierta

Pantallas que dependen de realtime **sin** poll de respaldo:

| Pantalla | Situación |
|----------|-----------|
| `menu_screen_foody.dart` | Menú cliente: solo `RefreshIndicator` |
| `pedido_cajero_screen.dart` | POS cajero: solo `RefreshIndicator` |
| `panel_restaurante_screen.dart` | Suscripción/plan: sin poll (solo sync Wompi al volver de background) |
| `dashboard_domiciliario_screen.dart` | `Timer.periodic` fijo de 60 s propio, no usa `PollRealtimeRespaldo` ni se adapta a la salud RT |

Las dos primeras son las más expuestas: son precisamente las que dependen de `catalogo_disponibilidad`, así que con `RT-CHAN-01` no tenían ni realtime ni poll.

### RT-LIFE-01 — Media — 🟣 Abierta

Ningún canal operativo reacciona a `AppLifecycleState.resumed`. Solo `panel_restaurante_screen.dart:144` y `mejorar_plan_screen.dart:78` lo implementan, y únicamente para sincronizar el pago Wompi.

En móvil el sistema operativo cierra el socket en segundo plano. Al volver a la app, el usuario ve datos viejos hasta que el poll dispare. Para un mesero o un cajero que alterna entre apps, esto es el caso frecuente, no el borde.

### RT-LEAK-01 — Media — 🟣 Abierta (confirma `FL-LEAK-02`)

Inventario exacto de la limpieza de canales, que hasta ahora estaba estimado en «~9 pantallas»:

| Limpieza | Pantallas |
|----------|-----------|
| `removeChannel` (correcto) | `kds_screen.dart:76,119` · `dashboard_domiciliario_screen.dart:88` · `dashboard_domiciliario_independiente_screen.dart:65` · `panel_restaurante_screen.dart:138,175` |
| Solo `unsubscribe()` (fuga) | `pedidos_kanban_widget.dart:160,180` · `mesas_grid_widget.dart:104,115` · `mesa_pedidos_sheet.dart:78` · `caja_admin_screen.dart:94` · `alertas_admin_screen.dart:69` · `domiciliarios_admin_screen.dart:78` · `seguimiento_pedido_screen.dart:72,139` · `menu_screen_foody.dart:148` · `pedido_cajero_screen.dart:115` |

`unsubscribe()` deja el canal dentro de la lista `channels` del cliente Supabase. Importa más de lo que parecía por su interacción con `RT-RECON-01`: al reconectar, `_triggerChanError` recorre **todos** los canales registrados y sus `_rejoinTimer` siguen intentando re-unirse. En una sesión larga de staff que navega entre paneles, los canales abandonados se acumulan y consumen el cupo por conexión de Supabase (≡ `AQ-SCALE-06`).

Son 9 pantallas exactas, y las 5 con limpieza correcta demuestran que el patrón bueno ya existe en el repo — es inconsistencia, no falta de solución.

### RT-ENV-01 — Media — 🟣 Abierta

`foody_backend/.env` define **`SUPABASE_URL` dos veces**, ambas activas (ninguna comentada). `dotenv` construye el objeto recorriendo el archivo de arriba abajo, así que **gana la última** y la primera se ignora en silencio.

El riesgo no es la configuración actual (`GET /health/realtime` responde `conectado: true`, así que la que gana es válida), sino el mantenimiento: quien edite la primera definición —la que se encuentra al abrir el archivo— no verá ningún efecto y perseguirá un fantasma. Si una apunta a `localhost:8000` y la otra al túnel público, un despliegue puede acabar emitiendo broadcast contra la instancia equivocada sin ningún error visible.

**Fix:** dejar una sola definición y, si se necesitan dos entornos, separarlos en `.env` distintos. Relacionado con `DK-SEC-*` de la auditoría Prompt 08.

### RT-SCRIPT-01 — Baja — ✅ Corregida (2026-08-07)

`scripts/verificar-realtime.ps1` ahora consulta `GET /health` (`verificarCompleto` → `datos.realtime.conectado`). `/salud` sigue siendo liviano (sin realtime); no es un bug de API.

### RT-ORPH-01 — Informativa — ✅ Sin huérfanos

No hay eventos emitidos sin consumidor ni oyentes sin emisor (tras `RT-CHAN-01`). `ping` en `foody_health_check` es interno del propio healthcheck y no necesita oyente Flutter.

Observación menor: `cocina_actualizada` viaja con `accion` (`item_estado`, `observaciones`, `item_eliminado`, `item_actualizado`) e `item_id`, pero el KDS ignora el payload y recarga todos los tickets. No es un huérfano, pero el payload se desaprovecha.

---

## 3. Consistencia entre dos dispositivos en el mismo pedido

**En base de datos: sí convergen.** Las transiciones de estado usan `SELECT ... FOR UPDATE` (`pedidos-estado.service.ts:93,481,637,737`) y la máquina de estados `TRANSICIONES_PEDIDO` (`pedido-estados.ts:16-30`) rechaza transiciones inválidas. Dos dispositivos no pueden dejar el pedido en estados divergentes; el segundo en llegar recibe el rechazo.

**En pantalla: no en todo momento.** La igualdad visual depende de que ambos reciban el broadcast, y no está garantizada:

1. Broadcast es fire-and-forget (`ack: false`) y sin replay: el dispositivo que estuviera reconectando pierde el evento (`RT-RECON-01`).
2. Un fallo de emisión se traga en un `warn`, sin reintento.
3. La ventana de divergencia se cierra solo con el poll de respaldo: hasta 90 s, y hasta ∞ en las pantallas de `RT-FALL-01`.
4. El payload no lleva versión ni `updated_at`; cada evento dispara un GET completo, así que gana el último GET en responder. Con el debounce de 300 ms el riesgo de pintar un estado viejo es bajo, pero no nulo.

En resumen: **convergencia eventual**, no consistencia instantánea. Para caja y KDS —donde dos personas actúan sobre el mismo pedido a la vez— la ventana de hasta 90 s es el riesgo operativo real.

---

## 4. Backlog de remediación

| ID | Acción | Prioridad |
|----|--------|-----------|
| **RT-FIX-01** | Realtime Authorization (canales privados + JWT por rol/sucursal) — cierra `RT-SEC-01` / OPS-07 | P0 |
| **RT-FIX-02** | Callback de estado en `subscribe()` + refetch al reconectar — `RT-RECON-01` | P1 |
| **RT-FIX-03** | Re-evaluar salud RT en cada tick del poll — `RT-POLL-01` | P1 |
| **RT-FIX-04** | `PollRealtimeRespaldo` en menú cliente, POS y panel restaurante; unificar domi planta — `RT-FALL-01` | P2 |
| **RT-FIX-05** | Refetch en `AppLifecycleState.resumed` en pantallas operativas — `RT-LIFE-01` | P2 |
| **RT-FIX-06** | `removeChannel` en las 9 pantallas que solo hacen `unsubscribe` — `RT-LEAK-01` / `FL-FIX-02` | P2 |
| **RT-FIX-07** | Dejar una sola `SUPABASE_URL` en `.env` — `RT-ENV-01` | P2 |
| **RT-FIX-08** | ~~Corregir el campo de salud que lee `verificar-realtime.ps1`~~ ✅ → `/health` | — |
| **RT-FIX-09** | Aprovechar `accion`/`item_id` de `cocina_actualizada` para refresco incremental en KDS | P3 |

---

## 5. Verificación ejecutada (2026-08-06)

| Comando | Resultado |
|---------|-----------|
| `npm run build` (foody_backend) | OK, sin errores TS |
| API `node dist/main` + `GET /api/v1/salud` | `exito: true` |
| `GET /api/v1/health/realtime` | `configurado: true, conectado: true` |
| `node scripts/verificar-realtime-canales.js` | **16/16 OK** (antes del fix: `catalogo_disponibilidad` cliente FALLO) |
| E2E `PATCH /productos/:id/disponibilidad` con oyentes en ambos canales | 200; canal staff **y** canal cliente reciben el payload |
| `scripts/verificar-realtime.ps1` | 20/20 OK (sin regresión) |

**Sin probar:** click-through en dispositivo real, y corte de red físico para observar el rejoin (se verificó por código de `realtime_client`, no en ejecución).
