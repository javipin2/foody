# Foody — Checklist QA manual por rol

> **Roadmap:** P3-02 + P3-10 · **Automatizado previo:** `scripts/verificar-flutter-ui.ps1`  
> **API por rol (sin UI):** `scripts/verificar-qa-roles-api.ps1` — 37 pasos OK  
> **Cierre completo sin VPS:** `scripts/verificar-cierre-sin-vps.ps1 -SinDocker`

> **Flavors:** Cliente/mesa QR → `-Flavor cliente` puerto **8081**. Staff → `-Flavor equipo` puerto **8080**.

Mismo checklist sirve en **PC local**, **túnel Cloudflare** (`foodyy.store`) y **futuro VPS** — solo cambian las URLs base.

---

## 1. Antes de cada sesión QA

### 1.1 Encender stack

| Paso | Local (PC) | Túnel / demo externa | VPS (futuro P0-05) |
|------|------------|----------------------|---------------------|
| Base de datos | Docker + Supabase verde | Igual (PC o VPS) | `docker compose` Supabase en VPS |
| API | `scripts\iniciar-backend-wsl.bat` | `:3000` detrás del túnel | `docker-compose.prod.yml` backend |
| Cliente web | `flutter-run-flavor.ps1 -Flavor cliente -WebPort 8081` | `https://foodyy.store` | `https://tu-dominio` |
| Staff web | `flutter-run-flavor.ps1 -Flavor equipo -WebPort 8080` | staff detrás del túnel | build estático + Nginx |
| API pública | `http://localhost:3000/api/v1` | `https://api.foodyy.store/api/v1` | `https://api.tu-dominio/api/v1` |

### 1.2 Puerta automática (obligatoria)

```powershell
.\scripts\verificar-flutter-ui.ps1
```

Ejecuta `flutter analyze` + `verificar-ci.ps1` (rápido). Si falla, **no** marques UI hasta corregir API/BD o errores Dart.

Contraseña demo staff: **`123456`**

---

## 2. Resumen por rol

| Rol | Acceso | Ruta Flutter | Usuario demo |
|-----|--------|--------------|--------------|
| **Cliente** | Sin login | `/cliente` → ciudad → menú | — |
| **Cliente mesa QR** | Sin login | `/mesa/demo-mesa-1` | token `demo-mesa-1` |
| **Dueño / admin sede** | Staff | `/admin/login` → `/admin/panel` | `admin@foody.demo` |
| **Gerente cadena** | Staff | `/admin/panel` + selector sedes | `gerente@foody.demo` |
| **Cajero** | Staff | `/admin/cajero` | `cajero.test@foody.demo` |
| **Mesero** | Staff | `/admin/mesero` | `mesero@foody.com` |
| **Cocina** | Staff | `/admin/cocina` | `cocina@foody.demo` |
| **Domiciliario planta** | Staff | `/admin/domiciliario` | `domi@foody.demo` |
| **Repartidor independiente** | Login propio | `/domiciliario/login` | `repartidor@foody.demo` |
| **Super admin Foody** | Staff | `/admin/foody-control` | `super@foody.demo` |

APK staff: flavor **`equipo`** · OAuth Google en móvil: deep link `foody://login`.

**Facturación electrónica DIAN:** 🚫 pausada — `docs/FACTURACION_ELECTRONICA_PAUSADA.md` (borrador HTML sigue disponible).

---

## 3. Checklists detallados

Marca `[x]` al probar en navegador. Anota fecha y entorno (local / túnel / VPS).

### 3.1 Cliente (sin login) — ☑ API · ☑ UI (2026-07-02)

**Ruta:** `/cliente` (flavor **cliente**) · **Escenarios:** PED-001, QR-001

- [x] Elegir ciudad → lista restaurantes carga (sin slug técnico en UI)
- [x] Bottom nav: Inicio · Pedidos · QR mesa
- [x] Menú: AppBar blanco + estados vacío/carga unificados
- [x] Abrir menú sucursal → categorías y precios visibles
- [x] Añadir al carrito → badge cantidad
- [x] Checkout **para llevar** → pedido creado → pantalla seguimiento
- [x] Checkout **domicilio** → mapa/zona → costo envío en total (backend)
- [x] **Mis pedidos** (`/cliente/mis-pedidos`) lista el pedido por `device_id`
- [x] Cancelar pedido (confirmado ≤ 2 min) — UI valida `created_at` del API
- [x] Botón «Llamar mesera» en seguimiento (mesa) — requiere `mesa_id`

### 3.2 Cliente mesa QR — ☑ API · 🟡 UI pulido 2026-07-02

**Ruta:** `/mesa/demo-mesa-1` (flavor **cliente**) · **Escenarios:** QR-001–006

- [x] Menú scoped a mesa (sin salir a ciudad; sin mis-pedidos global)
- [x] Pedido queda `pendiente_aprobacion`
- [x] Tras aprobar mesero → confirmado → cocina recibe ítems
- [x] Segundo pedido: banner **cuenta unificada** + total pendiente mesa

### 3.3 Dueño / admin sede — ☑ API

**Login:** `admin@foody.demo` · **Ruta:** `/admin/panel`

- [x] Dashboard: tarjetas + gráficos cargan
- [x] **Kanban:** confirmar pedido → columna correcta; Realtime actualiza
- [x] **Mesas:** grid colores; abrir mesa → POS; cobrar cuenta mesa
- [x] **Caja:** abrir turno → venta registrada; cierre con arqueo
- [x] **Menú:** CRUD producto; toggle disponible
- [x] **Inventario:** lista insumos; banner bajo stock si aplica
- [x] **Reportes:** export PDF/CSV
- [x] **Alertas:** listar y marcar revisada; tap referencia → módulo/mesa
- [x] **Búsqueda** (ícono lupa): pedido #, mesa o módulo
- [x] Multi-sucursal (si `gerente` o permiso): selector sede + copiar menú / traslados

### 3.4 Cajero — ☑ API · 🟡 UI pulido

**Ruta:** `/admin/cajero` · `cajero.test@foody.demo`

- [x] Sin caja abierta → bloqueo POS/Mesas + snackbar al cambiar tab
- [x] Abrir caja → tab POS habilitado
- [x] Nuevo pedido para llevar → confirmar → movimiento caja
- [x] Tab caja: movimientos del turno
- [x] Cierre caja con arqueo (modo ciego si gerente)

### 3.5 Mesero — ☑ API · 🟡 UI pulido

**Ruta:** `/admin/mesero`

- [x] Grid mesas: libre / ocupada / QR pendiente visible
- [x] Aprobar o rechazar pedido QR con motivo
- [x] Mesa ocupada → sheet pedidos → agregar ítem
- [x] Transferir mesa a otra libre
- [x] Cobro parcial / split por comensal (`mesa_pedidos_sheet` — long-press ítem)
- [x] Banner QR pendientes (tab Mesas y tab Pedidos)

### 3.6 Cocina (KDS) — ☑ API · código listo

**Login:** `cocina@foody.demo` · **Ruta:** `/admin/cocina`  
**Nota:** en **Usuarios** puedes crear más cuentas con rol **Cocina (KDS)** y asignar estación (p. ej. asados). Cada login solo ve su cocina.

- [x] Tickets aparecen al confirmar pedido
- [x] Marcar ítem **en preparación** → **listo**
- [x] Ítem **no disponible** → mesero notificado (Realtime)
- [x] Ticket con demora > 20 min resalta (alerta visual)
- [ ] Sonido en web Chrome (limitación plataforma; vibración sí en móvil)

### 3.7 Domiciliario planta — ☑ API · ☑ UI mapa

**Login:** `domi@foody.demo` · **Ruta:** `/admin/domiciliario`

- [x] Lista pedidos asignados / en camino
- [x] Cambiar estado entrega coherente con Kanban admin
- [x] Tab Activos: mapa de fondo + panel inferior (dirección, teléfono, navegar, cobro)
- [x] Chip GPS en AppBar cuando pedido en_camino

### 3.8 Repartidor independiente — ☑ API · ☑ UI inDriver

**Login:** `repartidor@foody.demo` · **Ruta:** `/domiciliario/login`

- [x] Ofertas activas cargan (tras «Conectarme»)
- [x] Mapa fondo + tarjeta oferta (countdown 60s, sin teléfono en oferta)
- [x] Ver ubicación (inactivo sin GPS cliente)
- [x] Varias ofertas: flechas ← →
- [x] Desconectar turno / sesión persiste al recargar (`GET sesion/estado`)
- [x] Aceptar oferta → pedido asignado + teléfono para llamar
- [x] GPS / tracking — chip «GPS» cuando pedido en_camino
- [x] E2E API: `.\scripts\verificar-ofertas-independiente.ps1`

### 3.9 Super admin Foody — ☑ API · código listo

**Login:** `super@foody.demo` · **Ruta:** `/admin/foody-control`

- [x] Estadísticas self-service cargan
- [x] Onboarding restaurante (diálogo crear en sección Restaurantes)
- [x] Revisar documentos domiciliario (sidebar **Repartidores**)
- [x] **Config global:** editar clave → snackbar éxito
- [x] Crear usuario staff (sidebar **Usuarios**, FAB)

---

## 4. Flujo cruzado E2E (todos los roles)

**Estado 2026-07-02:** flujo cruzado API **12/12 OK**.

```powershell
.\scripts\verificar-qa-manual.ps1 -FlujoApi
```

Validación UI manual recomendada una vez por release (15–25 min) con flavors correctos.

---

## 5. Registro de sesión

| Campo | Valor |
|-------|--------|
| Fecha | 2026-07-26 |
| Entorno | local |
| `verificar-flutter-ui.ps1` | OK |
| Roles UI probados en navegador | Staff `:8080` parcial · Cliente ⏳ |
| API Flujo / Roles | 12/12 · 38/38 |
| Incidencias | Overflow Mesas (mitigado Wrap); cola impresión error; FCM timeout web |
| Detalle | `docs/archivo/qa-sesiones/2026-07-26.md` |

Plantilla: `docs/archivo/qa-sesiones/YYYY-MM-DD.md`

---

## 6. Referencias

- Estrategia UI: `docs/ESTRATEGIA_BACKEND_PRIMERO.md`
- Escenarios negocio: `docs/ESCENARIOS_NEGOCIO_FOODY.md`
- Auditoría botones: `docs/archivo/auditorias-prompts/AUDITORIA_PANTALLAS_BOTONES.md`
- DIAN pausada: `docs/FACTURACION_ELECTRONICA_PAUSADA.md`
