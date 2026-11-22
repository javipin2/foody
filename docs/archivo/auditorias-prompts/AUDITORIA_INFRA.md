# Foody — Auditoría Infraestructura Hetzner / Nginx / Cloudflare (Prompt 09)

> **Fecha:** 2026-08-06  
> **Alcance:** docs/scripts de Tunnel, VPS, R2, Storage; ausencia de Nginx/Caddy en repo; proyección disco.  
> **Método:** lectura estática. **VPS Hetzner aún no desplegado** (P0-05 abierto) — Fase 0 = PC + Cloudflare Tunnel.  
> **Predecesoras:** … · [`AUDITORIA_DOCKER_ENV.md`](AUDITORIA_DOCKER_ENV.md) (DK-\*) · [`AUDITORIA_BD_SUPABASE.md`](AUDITORIA_BD_SUPABASE.md).  
> **Estado oficial:** [`MASTER_STATUS.md`](MASTER_STATUS.md) § Infra Cloudflare/VPS (INF-\*).  
> **Al cerrar un INF-\*:** marcar ✅ aquí + MASTER + viñeta en `AVANCE_PROYECTO.md`.  
> **Solapes:** logs ≡ DK-LOG; backups ≡ BD-BKP/OPS-02; Storage público ≡ BD-RLS-04.

---

## Veredicto

| Dimensión | Nota | Una línea |
|-----------|------|-----------|
| Nginx | N/A → D | **No hay** config Nginx/Caddy en repo; edge = Cloudflare Tunnel |
| Timeouts / body / headers | D | No hay reverse-proxy local; límites solo Multer Nest (5–20 MB) |
| Cloudflare R2 backups | C | Script rclone listo; **no activado**; bucket backups debe ser privado |
| Storage menú (`foody-assets`) | C+ | **Público lectura** (intencional); policies write sin `auth.role()` explícito |
| Tunnel reconexión / WiFi | C− | `cloudflared` reintenta si el proceso vive; en PC es proceso foreground — WiFi/apagado = caída pública |
| SSL | B | HTTPS en edge Cloudflare (renovación **de ellos**); sin certbot local |
| Disco VPS proyección | C | Sin presupuesto GB; logs sin tope (DK) + backups 14d + Storage ilimitado en disco VPS |

**Global Prompt 09:** ~**48 / 100** infra prod (Fase 0 usable; Hetzner/Nginx/R2 = deuda OPS-01/02).

**Qué ya está bien:**

- Túnel `foodyy.store` / `equipo` / `api` / `sb` documentado y operativo en PC.
- Edge HTTPS sin abrir puertos ni certbot (Cloudflare).
- Scripts `iniciar-cloudflare-tunnel.ps1`, `verificar-tunel-foodyy.ps1`, cutover VPS documentado.
- Bucket menú público = correcto para cliente sin login.
- Backup script con hook R2 (`R2_REMOTE`).

---

## Índice de hallazgos

| Prefijo | Tema | Abiertos |
|---------|------|--------:|
| INF-NGX-* | Nginx / proxy | 4 |
| INF-R2-* | R2 + Storage buckets | 4 |
| INF-TUN-* | Tunnel / WiFi / reconnect | 4 |
| INF-SSL-* | Certificados | 2 |
| INF-DISK-* | Espacio disco | 4 |
| INF-FIX-* | Remediaciones | 7 |

---

## 1. Nginx — timeouts, body, headers (INF-NGX)

**Hallazgo raíz:** no existe `nginx.conf` / `Caddyfile` / site-enabled en el repo.

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **INF-NGX-01** | 🟣 | Alta | Nginx **no implementado** — docs lo mencionan como opción VPS (`PREPARACION_VPS`, OPS-01) | |
| **INF-NGX-02** | 🟣 | Media | Sin `client_max_body_size` en edge — uploads dependen de Multer (5 MB imagen / 20 MB video) y de límites Cloudflare Tunnel (~100 MB típico CF) | Si se añade Nginx sin `client_max_body_size ≥ 25m`, uploads fallarán 413 |
| **INF-NGX-03** | 🟣 | Media | Sin timeouts proxy (`proxy_read_timeout`, etc.) documentados/configurados | Pedidos/reportes largos podrían cortarse tras añadir Nginx |
| **INF-NGX-04** | 🟣 | Media | Sin headers seguridad locales (`X-Frame-Options`, `HSTS`, `CSP`, `X-Content-Type-Options`) | Cloudflare aporta algo en edge; origen HTTP localhost no añade headers Nest globales de seguridad HTTP |

**Arquitectura actual (Fase 0):**

```
Internet → Cloudflare (HTTPS, WAF parcial) → cloudflared → http://localhost:{3000,8080,8081,8000}
```

No hay capa Nginx entre túnel y apps.

---

## 2. Cloudflare R2 y buckets (INF-R2)

### Dos usos distintos

| Uso | Dónde | ¿Público? | Estado |
|-----|-------|-----------|--------|
| **Backups PG** | R2 vía rclone (`foody-backups`) | Debe ser **privado** | Script OK; **no activado** en VPS |
| **Imágenes menú** | Supabase Storage `foody-assets` (no R2 aún) | **Público lectura** | Implementado migr. 057/077 |
| **CDN R2 imágenes** | Doc `OPTIMIZACION_…` | Público URL | Solo planificado |

### Hallazgos

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **INF-R2-01** | 🟡 | — | Lectura pública de `foody-assets` es **intencional** (menú cliente sin login) — no es “secreto expuesto” |
| **INF-R2-02** | 🟣 | Media | Policies INSERT/UPDATE/DELETE solo chequean `bucket_id` — **no** `auth.role() = 'service_role'` en el SQL | Riesgo si `authenticated` puede pegarle al Storage API self-hosted |
| **INF-R2-03** | 🟣 | Alta | Bucket R2 de **backups** aún no existe/activado — cuando se cree, verificar **acceso privado** (sin URL pública) | Checklist OPS-02 |
| **INF-R2-04** | 🟣 | Media | Pipeline imágenes → R2 CDN no existe; Storage crece en disco del host Supabase (PC hoy / VPS mañana) | |

**Respuesta corta:** lo público que **debe** serlo = fotos de menú. Lo que **no** debe ser público = dumps SQL en R2 (aún no cableado). Endurecer policies de escritura Storage.

---

## 3. Cloudflare Tunnel — reconexión / WiFi (INF-TUN)

### Comportamiento esperado de `cloudflared`

| Escenario | Si el proceso sigue corriendo | Si el proceso muere / ventana cerrada |
|-----------|------------------------------|--------------------------------------|
| WiFi cae segundos | Suele **reintentar** QUIC/HTTP2 solo | No hay conector → 502/522 públicos |
| PC suspende / adaptador USB WiFi flaky | Reconnect con backoff | Mismo — SaaS caído |
| Doble conector PC+VPS | Conflictos / 502 | Doc: no hacerlo |

### Cómo corre hoy (Fase 0)

- Script `iniciar-cloudflare-tunnel.ps1` → `cloudflared tunnel run --token=…` en **foreground** (o vía bat subdominios).
- **No** es servicio Windows con recovery.
- VPS: `setup-ubuntu-vps.sh` solo **imprime** “instalar service”; no genera unit systemd.

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **INF-TUN-01** | 🟣 **prod-risk (Fase 0)** | Alta | WiFi del adaptador / PC sleep → riesgo real; **no** hay auto-recovery de proceso si se cierra la ventana | Mitigar: servicio Windows o mover a VPS (OPS-01) |
| **INF-TUN-02** | 🟡 | Media | Con proceso vivo, `cloudflared` **sí** intenta reconectar tras corte de red (comportamiento del binario) — no está verificado con test documentado en Foody | Añadir prueba: cortar WiFi 30s + `verificar-tunel` |
| **INF-TUN-03** | 🟣 | Alta | VPS aún sin `cloudflared service install` automatizado | Bloquea criterio “PC apagado no tumba SaaS” |
| **INF-TUN-04** | 🟡 | Baja | Runbook WiFi/reconnect **no** está en `ACCIONES_HUMANAS_TUNEL` (solo Uptime/Wompi/VPS) | |

**Respuesta corta:** el túnel **puede** auto-recuperar la red si el proceso no muere. El riesgo del adaptador WiFi es que el **PC/proceso** caiga o quede zombie — no hay supervisor. En VPS con systemd = recuperación real.

---

## 4. Certificados SSL (INF-SSL)

| ID | Estado | Hallazgo |
|----|--------|----------|
| **INF-SSL-01** | ✅ | HTTPS público vía **Cloudflare** en `*.foodyy.store` — renovación automática **en Cloudflare** (no certbot local) |
| **INF-SSL-02** | 🟡 | Si se elige Nginx+TLS en VPS (alternativa OPS-01), **no hay** certbot/cron — habría que añadirlo; hoy no aplica |

Origen del túnel = HTTP plano a localhost (correcto). No hay evidencia de certificados Let’s Encrypt en el host.

---

## 5. Espacio en disco VPS — proyección (INF-DISK)

Supuesto VPS típico Hetzner CX22/CX32: **40–80 GB** SSD.

| Componente | Estimación crecimiento | Tope / retención hoy |
|------------|------------------------|----------------------|
| SO + Docker images | ~8–15 GB fijo | — |
| Postgres (datos Foody) | ~0.5–2 GB piloto → **5–20 GB**/año multi-sede (pedidos, auditoría) | Sin partición dedicada doc |
| Backups locales `pg_dump` | 1 dump ≈ tamaño DB comprimido; **×14 días** | `RETENCION_DIAS=14` |
| Docker logs (sin rotación) | **Ilimitado** (DK-LOG-01) — puede comer decenas de GB | **Sin tope** |
| Supabase Storage imágenes | N productos × ~200 KB–2 MB; videos hasta 20 MB | Crece en disco del contenedor Storage |
| R2 offsite | No cuenta disco VPS (cuando esté) | Lifecycle 30d recomendado |

### Proyección grosera (piloto 5–20 sedes, 1 año)

| Escenario | Disco usado aprox. | Riesgo |
|-----------|-------------------|--------|
| Conservador (logs rotados, R2 on, Storage moderado) | **25–40 GB** | OK en 40 GB |
| Sin rotación logs + backups 14d + muchas fotos | **60–100+ GB** | **Llena** CX22 |

| ID | Estado | Sev | Hallazgo |
|----|--------|-----|----------|
| **INF-DISK-01** | 🟣 **prod-risk** | Alta | Sin presupuesto de disco documentado ni alertas (`df` / Uptime) | |
| **INF-DISK-02** | 🟣 | Alta | Logs Docker sin `max-size` (≡ DK-LOG-01) = principal amenaza de llenado | |
| **INF-DISK-03** | 🟣 | Media | Storage en disco VPS sin cuota/alerta ni offload R2 imágenes | |
| **INF-DISK-04** | 🟡 | Baja | Backups 14d locales OK si DB &lt; ~1 GB; reevaluar retención si DB crece | |

---

## 6. Backlog remediación (INF-FIX)

| ID | Prioridad | Acción | Cierra | Depende |
|----|-----------|--------|--------|---------|
| **INF-FIX-01** | P0 | Comprar/desplegar VPS + `cloudflared` **como servicio** (systemd) + apagar PC | INF-TUN-01/03, OPS-01, P0-05 | Humano |
| **INF-FIX-02** | P0 | Rotación logs Docker (≡ DK-FIX-01) + alerta disco | INF-DISK-01/02 | DK |
| **INF-FIX-03** | P1 | Activar R2 backups **privado** + lifecycle 30d (≡ BD-FIX-01) | INF-R2-03, OPS-02 | |
| **INF-FIX-04** | P1 | Si se usa Nginx: plantilla con `client_max_body_size 25m`, timeouts 60s, headers seguridad | INF-NGX-* | |
| **INF-FIX-05** | P1 | Endurecer Storage policies (`auth.role() = 'service_role'`) | INF-R2-02 | |
| **INF-FIX-06** | P2 | Test documentado reconnect WiFi 30s + runbook en `ACCIONES_HUMANAS_TUNEL` | INF-TUN-02/04 | |
| **INF-FIX-07** | P2 | Doc presupuesto disco GB + monitor `df -h` en cron | INF-DISK-* | |

**Nginx:** no es obligatorio si el túnel apunta directo a contenedores en `127.0.0.1`. Solo hace falta plantilla cuando se sirva estático Flutter o se deje de usar Tunnel.

---

## 7. Matriz de conteo

| Grupo | 🟣 | 🟡 | ✅ |
|-------|---:|---:|---:|
| INF-NGX | 4 | 0 | 0 |
| INF-R2 | 3 | 1 | 0 |
| INF-TUN | 2 | 2 | 0 |
| INF-SSL | 0 | 1 | 1 |
| INF-DISK | 3 | 1 | 0 |
| **Total** | **12** | **5** | **1** |
| INF-FIX | 7 | | |

---

## 8. Cómo verificar al remediar

| Fix | Evidencia |
|-----|-----------|
| INF-FIX-01 VPS+tunnel service | PC apagado; `https://api.foodyy.store/api/v1/salud` → 200 |
| INF-FIX-02 logs | `docker inspect` LogConfig MaxSize; `df -h` estable 7 días |
| INF-FIX-03 R2 | Dump en bucket **sin** listado público; restore test |
| INF-FIX-04 Nginx | Upload 15 MB OK; `curl -I` muestra headers |
| INF-FIX-05 Storage | Upload con anon key → denegado; Nest service key → OK |
| INF-FIX-06 WiFi | Cortar red 30s; túnel vuelve sin reiniciar a mano (servicio) |

---

## Changelog de este documento

| Fecha | Cambio |
|-------|--------|
| 2026-08-06 | **Creación** Prompt 09 — INF-NGX/R2/TUN/SSL/DISK + INF-FIX-01…07; Fase 0 vs VPS explícito |

---

*Fin — Auditoría Infraestructura Hetzner/Nginx/Cloudflare (Prompt 09).*
