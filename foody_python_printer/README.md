# foody_python_printer

Agente **Python** en la PC del restaurante. NestJS envía tickets por WebSocket; imprime en térmica de red o guarda en archivo (dev sin hardware).

**Guía completa:** `docs/IMPRESION_RESTAURANTE.md`

## Inicio rápido (sin impresora)

```powershell
cd foody_python_printer
pip install -r requirements.txt
$env:FOODY_PRINTER_MODE = "archivo"
python main.py
```

En `foody_backend/.env`: `FOODY_PRINTER_WS=ws://127.0.0.1:8765`

Verificar: `.\scripts\verificar-impresion.ps1`

## Impresora de red (producción)

1. Admin → Cocinas e impresoras → `ip_local` por cocina (puerto **9100**).
2. `$env:FOODY_PRINTER_MODE = "auto"`
3. Pedido a `en_cocina` → ticket en impresora.

## Variables

| Variable | Default | Uso |
|----------|---------|-----|
| `FOODY_PRINTER_MODE` | `auto` | `archivo` / `auto` / `red` |
| `FOODY_PRINTER_HOST` | `0.0.0.0` | Bind WebSocket |
| `FOODY_PRINTER_PORT` | `8765` | Puerto WebSocket |
| `FOODY_PRINTER_PORT_NET` | `9100` | Puerto impresora red |
| `FOODY_PRINTER_LOG_DIR` | `./tickets` | Tickets simulados |

Flutter **nunca** imprime; solo NestJS + este agente.
