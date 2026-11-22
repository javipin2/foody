# Impresión cocina — guía Foody

> Tickets de cocina: **NestJS encola** → **agente Python** en PC del restaurante → impresora térmica **o archivo** (sin hardware).

**Última actualización:** 2026-08-08

> **Piloto sin térmica (waiver founder 2026-08-08):** modo `archivo` es válido. El día que compres la impresora **no reescribes Foody** — solo IP en admin + cambiar el modo del agente (abajo).

---

## Flujo

```
Pedido → en_cocina (o aprobar QR mesa)
    ↓
ImpresionService.encolarPorPedido()
    ↓
Tabla impresion_cocina_jobs (estado pendiente)
    ↓
Cron cada 5 s → WebSocket → foody_python_printer
    ↓
python-escpos (red :9100)  O  carpeta tickets/ (sin impresora)
```

Flutter **nunca** imprime. Solo NestJS + agente Python.

---

## Desarrollo sin impresora térmica (tu caso actual)

### 1. Variables backend (`foody_backend/.env`)

```env
FOODY_PRINTER_WS=ws://127.0.0.1:8765
```

### 2. Agente Python

```powershell
cd foody_python_printer
pip install -r requirements.txt
$env:FOODY_PRINTER_MODE = "archivo"
python main.py
```

Con `FOODY_PRINTER_MODE=archivo` **siempre** guarda en `foody_python_printer/tickets/` aunque haya IP en BD.

### 3. Migración BD

```powershell
.\scripts\aplicar-migracion-supabase.ps1 foody_supabase\migrations\058_impresion_jobs_detalle.sql
```

### 4. Verificar

```powershell
.\scripts\verificar-impresion.ps1
```

Debe mostrar: job `enviado`, `simulado=true`, y archivos `.txt` en `tickets/`.

### 5. Health check

`GET /api/v1/health/impresion` — indica si el agente WebSocket responde.

---

## Producción con impresora de red

1. Admin → **Cocinas e impresoras** → crear impresora con `ip_local` (ej. `192.168.1.50`).
2. Puerto ESC/POS estándar: **9100** (`FOODY_PRINTER_PORT_NET`).
3. En PC del restaurante:

```powershell
$env:FOODY_PRINTER_MODE = "auto"
python main.py
```

4. Al confirmar pedido, NestJS envía ticket + IP al agente.

| Modo | Comportamiento |
|------|----------------|
| `auto` | Red si hay IP; si falla o no hay IP → archivo |
| `archivo` | Solo archivo (dev / pruebas) |
| `red` | Solo red; error si no hay IP o falla impresora |

---

## API staff (debug)

| Método | Ruta | Uso |
|--------|------|-----|
| GET | `/impresion/jobs?sucursal_id=` | Últimos jobs (estado, simulado, error) |
| POST | `/impresion/procesar-cola` | Forzar procesamiento (dev) |
| GET | `/health/impresion` | Ping al agente Python |

Permiso: `ver_cocina`, módulo plan `cocina`.

---

## Cuándo se encola impresión

- Pedido pasa a `en_cocina` (Kanban, aprobar mesa QR, crear staff en cocina).
- Pedido creado ya en `confirmado` o `en_cocina`.
- Ítems agregados a pedido activo (`notificarCocinasPorPedido`).

Un job **por cocina** distinta en el pedido.

---

## Reintentos y errores

- Si el agente no está encendido: job queda `pendiente`, reintenta hasta **10** veces.
- Tras 10 fallos: `estado=error`, `ultimo_error` guardado.
- Si imprime en archivo: `simulado=true`, `estado=enviado`.

---

## Cuando tengas impresora física (checklist de 5 min)

1. Misma Wi‑Fi que el PC donde corre `foody_python_printer`.
2. Admin → **Cocinas e impresoras** → `ip_local` (ej. `192.168.1.50`) · puerto **9100**.
3. En la PC del agente:

```powershell
$env:FOODY_PRINTER_MODE = "auto"   # o "red" si quieres fallar en vez de archivo
python main.py
```

4. Pedido → cocina → mirar papel (y `GET /impresion/jobs` si algo falla).
5. `simulado` debe pasar a `false` en jobs enviados.
6. Marcar **P0-01** en `docs/ROADMAP_TERMINAR_FOODY.md` / PRIORIDADES cuando el papel salga OK.

No hace falta tocar Nest, Flutter ni el túnel.

---

## Archivos clave

| Componente | Ruta |
|------------|------|
| Cola NestJS | `foody_backend/src/core/impresion/impresion.service.ts` |
| Agente Python | `foody_python_printer/main.py`, `impresor.py` |
| Jobs BD | `impresion_cocina_jobs` (migr. 047 + 058) |
| Script QA | `scripts/verificar-impresion.ps1` |

---

## Variables de entorno (resumen)

| Variable | Dónde | Default |
|----------|-------|---------|
| `FOODY_PRINTER_WS` | backend `.env` | `ws://127.0.0.1:8765` |
| `FOODY_PRINTER_MODE` | agente Python | `auto` |
| `FOODY_PRINTER_PORT` | agente Python | `8765` |
| `FOODY_PRINTER_PORT_NET` | agente Python | `9100` |
| `FOODY_PRINTER_LOG_DIR` | agente Python | `./tickets` |
