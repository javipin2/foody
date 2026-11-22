# Módulo Finanzas — control de egresos + rentabilidad (P&L)

> **Estado global:** ✅ ~90% usable en demo (API + UI + script QA) — pack «Finanzas claro» 2026-08-06  
> **Fecha:** 2026-08-06  
> **Fuente de verdad de estado:** `docs/MASTER_STATUS.md` §23  
> **Spec BD histórica:** `INFRAESTRUCTURA/esquema_maestro_bd_v3.md` (costos fijos, fórmulas ganancia neta / punto de equilibrio)  
> **Relacionado:** Caja (`§5`), Analítica (`§21` + `MODULO_ANALITICA_BI.md`), Costeo (`MODULO_COSTEO.md`)

---

## 1. Resumen de 1 minuto

El dueño/gerente registra **en qué se gasta el local** (arriendo, servicios, publicidad, nómina simple) y ve si el mes da **ganancia o pérdida**.

| Pieza | Dónde vive |
|-------|------------|
| Captura de gastos fijos, empleados y egresos | Sidebar **Finanzas → Gastos y nómina** (`?seccion=finanzas`) |
| Estado de resultados + gráficas | **Análisis → tab Rentabilidad** |
| Gastos que salen del cajón del turno | Sigue en **Caja** (`POST /caja/gastos`) — distinto |

**Regla no negociable:** Flutter solo muestra; NestJS calcula. Un pago de arriendo/nómina/transferencia **no** descuenta el arqueo del cajero.

---

## 2. Decisiones de producto (cerradas 2026-08-06)

| Tema | Decisión |
|------|----------|
| Nombre en UI | «Gastos y nómina» (captura) + tab «Rentabilidad» (P&L) |
| Ubicación | Mixto: captura en módulo Finanzas; P&L dentro de Analítica |
| Costo de comida en el P&L | **COGS** = snapshot `pedido_items.costo_unitario` al vender (no compras del periodo) |
| Compras a proveedores | **No** restan del P&L (evitar doble conteo); se muestran como referencia |
| Libro de egresos | Una sola tabla `gastos` con `origen` ∈ `caja` \| `manual` \| `fijo` \| `nomina` |
| Costos fijos / empleados | Plantillas; al «Pagar» insertan fila en `gastos` con `caja_id = NULL` |
| Nómina | **Simple**: sueldo base + frecuencia + registrar pago. Sin SSS / deducciones / horas |
| Quién ve sueldos | Permiso `ver_finanzas`: `admin`, `gerente`, `gerente_cadena`. **No** cajero |
| Quién escribe | Permiso `gestionar_finanzas` (mig `087`): mismos roles; lecturas siguen con `ver_finanzas` |
| Plan SaaS | Sin candado de plan propio (mismo acceso que admin con permiso) |

---

## 3. Estado por bloque

### 3.1 Hecho ✅

| Bloque | Evidencia |
|--------|-----------|
| Migración `080_finanzas_control.sql` | `gastos.origen/fecha/FKs`, `empleados`, columnas en `costos_operativos_fijos`, RLS empleados, permiso `ver_finanzas` |
| `FinanzasModule` NestJS | CRUD costos fijos + pagar; CRUD empleados + pagar; listar/crear gastos manuales |
| Caja escribe `origen='caja'` | `caja.service.ts` al registrar gasto de turno |
| `GET /analitica/rentabilidad` | Ventas − COGS − gastos; utilidad bruta/neta; punto equilibrio; cobertura costo; compras ref. |
| Flutter captura | `lib/features/finanzas/` — resumen mes + pendientes + consejos + 3 tabs + pago editable |
| Flutter P&L | Tab Rentabilidad: consejos + Δ utilidad; CTA desde Finanzas |
| API resumen dueño | `GET /finanzas/resumen/:sucursal_id` — P&L mes vs anterior, por pagar, consejos |
| Sidebar | `menu_admin_item` + grupo `finanzas` + `case 'finanzas'` en panel |
| QA automatizado | `scripts/verificar-finanzas.ps1` — happy path, resumen, monto editable, 403 rol, arqueo intacto |
| Docs status | MASTER §23, MODULOS §5b, AVANCE changelog + endpoints |

### 3.2 Parcial 🟡

| Ítem | Qué hay | Qué falta para ✅ |
|------|---------|------------------|
| UX de pago | ✅ Diálogo monto + periodo (API + UI) | — |
| Categorías | Enum backend + dropdown UI | Etiquetas amigables (“Servicios públicos”) y validación uniforme en gastos de caja |
| Cobertura de costo | KPI + aviso + consejo regla | Deep-link a Costos/márgenes |
| Comparativa temporal | ✅ Δ% utilidad en resumen + tab Rentabilidad | — |
| Multi-sucursal | Scope por `sucursal_id` | Vista consolidada cadena (P&L por sede) — no existe |
| Nav / docs frontend | Ruta + CTA Finanzas→Rentabilidad | Mapas FRONTEND_NAV opcional |
| Smoke UI | Contrato API + analyze | Click-through real en dispositivo/web |

### 3.3 Pendiente / fuera de alcance ⏳ 🚫

| Ítem | Prioridad | Notas |
|------|-----------|-------|
| Click-through QA manual dispositivo | Alta (QA) | Checklist humano post-deploy local |
| Export CSV/PDF del P&L | Media | Extender `/analitica/export` o botón en tab |
| Recordatorio / vencimientos (`dia_pago`) | Media | Columna existe; no hay job ni badge «por pagar» |
| Comprobante (foto recibo) | Baja | Columna `comprobante_url`; sin upload Storage |
| Enlace empleado ↔ `usuarios` | Baja | Campo `usuario_id` opcional; UI no lo usa |
| Soft-delete UI empleados | Baja | Solo desactivar; sin listado «inactivos» filtrable amigable |
| Entidad `proveedores` | Baja | Sigue texto libre en inventario/compras |
| Nómina formal (SSS, prestaciones, horas) | 🚫 | Explícito en `multinegocio/01_VISION_Y_PRINCIPIOS.md` |
| Contabilidad PUC / bancos conciliados | 🚫 | Fuera de Foody (Siigo/Alegra) |
| Impuestos / DIAN en el P&L | 🚫 | Módulo facturación separado |

---

## 4. Modelo de datos

```
costos_operativos_fijos (plantilla mensual)
  id, sucursal_id, concepto, monto_mensual, categoria, dia_pago, notas, activo

empleados (plantilla nómina)
  id, sucursal_id, nombre, cargo, sueldo_base, frecuencia_pago, usuario_id?, activo

gastos (libro único de egresos)
  id, sucursal_id, caja_id?, concepto, monto, categoria,
  origen ('caja'|'manual'|'fijo'|'nomina'), fecha,
  empleado_id?, costo_fijo_id?, periodo_desde?, periodo_hasta?,
  registrado_por?, comprobante_url?, usuario_id, created_at
```

**Flujo de pago (fijo / nómina / manual):** `INSERT gastos` con `caja_id = NULL` → **no** llama a `CajaMovimientosService`.

**Flujo gasto de caja:** `INSERT gastos` + `INSERT movimientos_caja` tipo `gasto` → sí afecta arqueo.

---

## 5. API (prefijo `/api/v1`)

| Método | Ruta | Permiso | Notas |
|--------|------|---------|-------|
| GET | `/finanzas/costos-fijos/:sucursal_id` | `ver_finanzas` | `?incluir_inactivos=` |
| POST | `/finanzas/costos-fijos` | idem | |
| PATCH | `/finanzas/costos-fijos/:id` | idem | `?sucursal_id=` |
| DELETE | `/finanzas/costos-fijos/:id` | idem | soft (`activo=false`) |
| POST | `/finanzas/costos-fijos/:id/pagar` | idem | body opcional `monto`, `fecha`, periodos |
| GET | `/finanzas/empleados/:sucursal_id` | idem | |
| POST | `/finanzas/empleados` | idem | |
| PATCH | `/finanzas/empleados/:id` | idem | |
| POST | `/finanzas/empleados/:id/pagar` | idem | |
| GET | `/finanzas/gastos/:sucursal_id` | idem | `?desde&hasta` |
| POST | `/finanzas/gastos` | idem | gasto manual (no caja) |
| GET | `/analitica/rentabilidad` | `ver_finanzas` | mismos presets/filtros de Analítica |

### Fórmula P&L (backend)

```
ventas_netas          ← pedidos del periodo (misma lógica que KPIs analítica)
− costo_ventas        ← Σ(cantidad × costo_unitario) en pedido_items
= utilidad_bruta
− total_gastos        ← Σ gastos.fecha en [desde, hasta] (todos los orígenes)
= utilidad_neta
punto_equilibrio      ← total_gastos / (utilidad_bruta / ventas_netas)  si margen > 0
```

---

## 6. Flutter (solo UI)

| Archivo | Rol |
|---------|-----|
| `lib/features/finanzas/data/finanzas_repository.dart` | Dio → `/finanzas/*` |
| `lib/features/finanzas/presentation/finanzas_admin_screen.dart` | 3 tabs |
| `lib/features/analitica/.../analitica_screen.dart` | Tab índice 7 «Rentabilidad» |
| `lib/features/admin/domain/menu_admin_*.dart` | Ítem + grupo |
| `panel_restaurante_screen.dart` | `case 'finanzas'` |

**Cómo abrir:** login `admin@foody.demo` → panel → **Finanzas → Gastos y nómina** o **Análisis → Rentabilidad**.

---

## 7. Verificación

```powershell
# Migración (si falta)
.\scripts\aplicar-migracion-supabase.ps1 080_finanzas_control.sql

# API con dist reciente
cd foody_backend; npm run build; node dist/main.js

# E2E
.\scripts\verificar-finanzas.ps1
```

Criterios del script:

1. Crear + pagar costo fijo (`origen=fijo`)
2. Crear + pagar empleado (`origen=nomina`)
3. Gasto manual **no** cambia `saldo_sistema` de caja abierta
4. `utilidad_neta ≈ utilidad_bruta − total_gastos`
5. Rol sin permiso (cajero.test / mesero) → **403**

`dart analyze` en paths tocados: sin **errors** (2026-08-06).

**No verificado aún:** click-through UI en Chrome/APK.

---

## 8. Recomendaciones (orden sugerido)

### P0 — calidad / confianza

1. **QA manual 15 min** con `admin@foody.demo`: crear arriendo, pagar, ver tab Rentabilidad; confirmar que caja abierta no cambia.
2. Si el P&L sale «siempre en pérdida» tras muchas corridas de `verificar-finanzas.ps1`, limpiar filas `gastos` con concepto `QA-%` (el script deja datos de prueba).

### P1 — producto cercano

3. ~~Diálogo de pago con **monto editable** + periodo~~ ✅  
4. ~~CTA en Gastos y nómina → «Ver rentabilidad»~~ ✅  
5. Incluir rentabilidad en **export** CSV de Analítica.  
6. ~~Badge «por pagar este mes»~~ ✅ (conteo en tabs + panel resumen)  

### P2 — escala / pulido

7. ~~Comparativa Δ% utilidad~~ ✅ (resumen + tab Rentabilidad)  
8. P&L consolidado multi-sede para `gerente_cadena`.
9. Subir comprobante a Storage (`comprobante_url`).
10. Candado de plan (`reportes`/`analitica`) solo si el negocio lo pide.

### No hacer (ahora)

- Nómina legal colombiana / SSS.
- Contabilidad de doble partida.
- Meter compras de inventario como “gasto” del P&L.

---

## 9. Relación con otros módulos

| Módulo | Relación |
|--------|----------|
| **Caja** | Gastos de turno (`origen=caja`) entran al mismo libro y al arqueo |
| **Analítica** | Tab Rentabilidad; resto de tabs siguen con `ver_analitica` |
| **Costeo / inventario** | Alimentan `costo_unitario` al vender → calidad del COGS |
| **Reportes** | Financiero operativo (sin P&L completo); no reemplaza este módulo |
| **Usuarios** | Staff ≠ empleados de nómina (enlace opcional `usuario_id`) |

---

## 10. Checklist de cierre de sesión (agente)

- [x] Migración 080 aplicada en local
- [x] `npm run build` + API viva
- [x] `verificar-finanzas.ps1` OK
- [x] MASTER / AVANCE / MODULOS actualizados
- [x] Este `MODULO_FINANZAS.md` + entrada en `docs/README.md`
- [ ] Click-through UI (humano / siguiente sesión)

---

## 11. Archivos clave

```
foody_supabase/migrations/080_finanzas_control.sql
foody_backend/src/modulos/finanzas/
foody_backend/src/modulos/analitica/analitica.controller.ts  # GET rentabilidad
foody_backend/src/modulos/analitica/analitica.service.ts     # rentabilidad()
lib/features/finanzas/
lib/features/analitica/presentation/analitica_screen.dart
scripts/verificar-finanzas.ps1
docs/MASTER_STATUS.md §23
```
