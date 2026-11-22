# Auditoría — Configuración del restaurante (Prompt 22)

> **Fecha:** 2026-08-06  
> **Alcance:** opciones de config en BD vs pantallas del panel; propagación a módulos; visibilidad multi-rol.  
> **Incluye:** config de restaurante/sucursal + nota de `configuracion_global_foody` (super).  
> **Verificación:** `scripts/verificar-config-restaurante.ps1` (OK, exit 0).  
> Relacionados: [`AUDITORIA_FACTURACION.md`](archivo/auditorias-prompts/AUDITORIA_FACTURACION.md) · [`AUDITORIA_REPORTES.md`](archivo/auditorias-prompts/AUDITORIA_REPORTES.md) (umbrales) · [`MULTI_SUCURSAL.md`](../../MULTI_SUCURSAL.md).

Leyenda: 🟣 abierto · 🟡 aceptado/parcial · ✅ cerrado / comprobado OK

---

## Resumen ejecutivo

| Pregunta | Respuesta |
|----------|-----------|
| ¿Cada opción de BD tiene pantalla en el panel? | **No.** Core operativa sí (horarios, zonas, fiscal*, cocinas/impresoras, marca parcial, fiado/caja-domi). **Faltan:** editar perfil sede tras crear, nombre/teléfono marca, márgenes sede, polígono zona. |
| ¿Los cambios se propagan solos? | **Sin reinicio de API.** Sin Realtime de config. Depende del caso: horario invalida cache menú; zona/fiscal/fiado = siguiente HTTP/acción; plan API lee BD en vivo, UI sidebar necesita `perfil`. |
| ¿Todos los roles ven el cambio a la vez? | **No push.** Cada cliente ve el cambio en su próximo fetch/acción. Pedido create (horario/IVA) usa BD en vivo; menú cliente puede quedar stale en memoria hasta refetch. |

\*Fiscal: UI + API existen; módulo plan **enterprise** (demo admin → 403 en smoke).

---

## A) Inventario BD ↔ UI ↔ API

| Campo / recurso | Tabla | API | Pantalla panel | UI |
|-----------------|-------|-----|----------------|-----|
| Logo / banner / descripción | `restaurantes` | `GET/PATCH /sucursales/marca` | Mis sucursales | ✅ |
| Nombre / teléfono restaurante | `restaurantes` | — (admin) | — | ❌ |
| Crear sede | `sucursales` | `POST /sucursales` | Mis sucursales | ✅ |
| Editar nombre/dir/tel/`activa` sede | `sucursales` | **sin PATCH** | solo crear | ❌ |
| Lat/lng sede | `sucursales` | `PATCH /zonas/sucursal/:id/ubicacion` | Zonas | ✅ |
| Horarios | `horarios_sucursal` | `GET …/horarios`, `PATCH …/horarios/:id` | Horarios | ✅ |
| Zonas costo/km/activa | `zonas_cobertura` | CRUD `/zonas` | Zonas | ✅ |
| `poligono` | `zonas_cobertura` | no usado | — | ❌ |
| Fiscal NIT/IVA/DIAN/prefijo | `configuracion_fiscal_sucursal` | `GET/POST /facturacion/config` | Facturación | ✅ (plan) |
| Cocinas / impresoras | `cocinas` / `impresoras` | CRUD | Config. cocinas | ✅ |
| `permite_fiado_domiciliario` | `sucursales` | `PATCH …/config-fiado` (lectura vía liquidación) | Domiciliarios | ✅ |
| `domicilio_ingresa_a_caja` | `sucursales` | `PATCH …/config-domicilio-caja` (lectura vía domicilios) | Domiciliarios | ✅ |
| `margen_objetivo_default` | `sucursales` | solo lectura costeo | — | ❌ |
| `umbral_alerta_margen` | `sucursales` | solo lectura costeo | — | ❌ |
| Plan / módulos | `suscripciones_restaurante` | login + `perfil`; guard lee BD | Plan y pagos | 🟡 |
| Propina % default | — | por cobro | — | N/A |
| Claves globales Foody | `configuracion_global_foody` | `GET/PATCH /super/configuracion` | Foody Control | 🟡 UI sí / runtime casi no |

Menú admin: `menu_admin_item.dart` (sucursales, zonas, horarios, cocinas, facturación, domiciliarios).

---

## B) Propagación (sin reinicio Nest)

| Cambio | Módulos afectados | Mecanismo | ¿Reinicio? |
|--------|-------------------|-----------|------------|
| Horario | Menú `horario_activo`; create pedido | **Invalida** `MenuCache` + SQL vivo en create | No |
| Zona / GPS | Cotizar domicilio, costo pedido | Siguiente `GET cotizar` / create | No |
| Fiscal IVA | Nuevos pedidos / mutaciones ítem | `FacturacionService` lee config en vivo; pedidos viejos = snapshot | No |
| Marca | Listado ciudad cliente | Siguiente HTTP listado; menú no embebe logo | No |
| Fiado / domi→caja | Entrega planta, caja | Siguiente acción / payload pedido | No |
| Cocinas / impresoras | KDS, cola print | Siguiente list/job; `cocina_id` JWT hasta re-login | No |
| Plan | Guards + sidebar | Guard: **BD en vivo**; Flutter: `_recargarPerfilTrasPago` | No |
| Umbrales en `configuracion_global_foody` | Alertas / dispatch (esperado) | **Casi no leídos** — ver CFG-GLOBAL-DEAD | N/A |

**Realtime:** no hay canal de config. Banner RT del panel no aplica a estos cambios.

**Cache menú TTL:** ~5 min; horario PATCH lo invalida (`restaurantes.service.ts` ~160–161).

---

## C) Multi-rol (¿ven el cambio al mismo tiempo?)

| Actor | Horario | Zona/costo | IVA fiscal | Fiado | Plan UI |
|-------|---------|------------|------------|-------|---------|
| Cliente con menú abierto | Tras refetch menú (cache bust ayuda) | Tras cotizar de nuevo | N/A en UI; create usa BD | N/A | N/A |
| Mesero / cajero | Create pedido = BD **inmediato**; badge menú puede lag | Create con coords = vivo | Totales nuevos = vivo | — | Sidebar tras perfil |
| Admin otra pestaña | Refresh sección | Refresh | Refresh facturación | Toggle local + PATCH | Perfil post-pago |
| Domiciliario planta | — | — | — | Flag en próximo payload | — |

**Conclusión:** no hay sincronización simultánea push. Consistencia = eventual por pull. Reglas de negocio críticas (abrir/cerrar, IVA, create) están en servidor y no dependen de que la UI de otro rol se haya refrescado.

---

## D) Hallazgos

| ID | Estado | Sev | Hallazgo | Evidencia |
|----|--------|-----|----------|-----------|
| **CFG-PATCH-SUCURSAL-01** | ✅ | Media | `PATCH /sucursales/:id` + UI Editar sede | `verificar-cons-promo-cfg-patch.ps1` · `actualizar-sucursal.dto.ts` |
| **CFG-MARGEN-UI-02** | 🟣 | Media | `margen_objetivo_default` / `umbral_alerta_margen` en BD y leídos por costeo; sin API/UI admin | `032`/`040` · `costeo.service.ts` |
| **CFG-POLIGONO-03** | 🟡 | Baja | `COMMENT` mig 088: DEPRECATED; cobertura = `distancia_max_km` Haversine | `088_deprecar_poligono_zonas.sql` |
| **CFG-NOMBRE-MARCA-07** | ✅ | Baja | `PATCH /sucursales/marca` + UI Nombre/tel | `verificar-cfg-nombre-marca.ps1` |
| **CFG-GLOBAL-DEAD** | ✅ | **Alta** | Runtime lee `configuracion_global_foody` (umbrales + oferta/comisión/radios); `recargar()` tras PATCH super | `configuracion-global.module.ts` · `verificar-f3-confianza.ps1` |
| **CFG-HORARIO-CACHE-08** | ✅ | — | PATCH horario invalida menú cache | `restaurantes.service.ts:160-161` + script |
| **CFG-IVA-PEDIDO-09** | ✅ | — | IVA desde config fiscal en create; sin JWT | Facturación / pedidos-crear |
| **CFG-REALTIME-06** | 🟡 | Info | Sin RT para config; by design pull | — |
| **CFG-PLAN-API-10** | ✅ | — | `PlanFeaturesGuard` lee plan en BD (no solo JWT) | `plan-features.guard.ts:38-41` |
| **CFG-PLAN-UI-11** | 🟡 | Baja | Sidebar Flutter usa `modulos` de sesión; tras upgrade llama `_recargarPerfilTrasPago` | `panel_restaurante_screen.dart` |
| **CFG-PLAN-FACT** | 🟡 | Info | Facturación config 403 en plan demo (enterprise); pantalla existe | Script 403 · `plan-features.config.ts` |
| **CFG-CACHE-MARCA-04** | 🟡 | Baja | Sin caché Nest de listado ciudad (SQL vivo); nada que invalidar | `ciudades.service.ts` |
| **CFG-PROPINA-11** | 🟡 | Info | No hay tip % a nivel sede | — |

---

## E) Backlog sugerido

1. **CFG-FIX-01** — Cablear lectura de `configuracion_global_foody` en alertas/dispatch **o** quitar/editar UI super para no mentir (cerrar CFG-GLOBAL-DEAD). Prod-risk de ops: admin cree que cambió umbrales.
2. **CFG-FIX-02** — `PATCH /sucursales/:id` + UI editar/desactivar sede.
3. **CFG-FIX-03** — Exponer márgenes sede en Costos o Sucursales.
4. **CFG-FIX-04** — Marca: permitir nombre/teléfono o documentar solo vía super.
5. **CFG-FIX-05** — Decidir polígono: implementar o dropear columna.

---

## Verificación

```text
.\scripts\verificar-config-restaurante.ps1
→ Verificacion config-restaurante OK (exit 0)

Evidencia:
- PATCH /sucursales/:id → 404
- Horarios 7, zonas 4, cocinas/impresoras OK
- Fiscal 403 plan (esperado demo)
- Fiado/caja flags vía liquidacion/domicilios
- 12 claves globales listadas; runtime hardcode documentado
- PATCH horario smoke OK
```

Gaps: no se midió TTL menú cliente en dispositivo tras cambio horario; no se forzó upgrade de plan E2E en esta pasada.
