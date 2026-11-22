# Centro de Operaciones Foody (NOC)

> **Nombre de producto:** Centro de Operaciones / Foody NOC  
> **UI actual (legacy name):** Foody Control — `panel_foody_control_screen.dart`  
> **Fecha:** 2026-08-06  
> **Pregunta que debe responder en &lt; 5 s:** *«¿Cómo está Foody en este momento?»*  
> **Relacionados:** [`PLANES_SUSCRIPCION.md`](PLANES_SUSCRIPCION.md) · [`MONITOREO_SALUD.md`](MONITOREO_SALUD.md) · [`AUDITORIA_PERF_BACKEND.md`](archivo/auditorias-prompts/AUDITORIA_PERF_BACKEND.md) · [`OPTIMIZACION_ESCALABILIDAD_FOODY.md`](OPTIMIZACION_ESCALABILIDAD_FOODY.md) · [`ALERTAS_AUTOMATICAS.md`](ALERTAS_AUTOMATICAS.md)

**Estado:** 📅 Visión completa · ✅ **Fase A = esencial (ahora)** · 📅 B/C después del go-live.  
**IDs:** `NOC-*` (visión) · `SAC-*` (ítems de implementación Fase A).

---

## Principio

No es “una sesión de superadmin para editar restaurantes”.  
Es el **panel interno de plataforma** (estilo Shopify/Stripe/Notion ops): salud, crecimiento, planes, errores, uso, alertas e **interpretación** — no métricas crudas sin contexto.

Flutter solo pinta. Nest calcula, agrupa, recomienda y audita.

**No implementar todo de golpe.** La visión (§2) orienta; el backlog ejecutable es **Fase A** (§3).

---

## 1. Planes comerciales (Gratis / Pro / Ultra)

| Comercial | Rol | Precio ref. COP/mes | Código hoy (hasta migrar) |
|-----------|-----|--------------------:|---------------------------|
| **Gratis** | Captura / prueba | 0 | `gratis` |
| **Pro** | Plan mínimo de pago | **50.000** | `basico` |
| **Ultra** | Cadena / premium | ~100–130k | `pro` / `enterprise` (unificar TBD) |

Límites Gratis (ya en código): 1 sede · 2 staff · 2 mesas · **5 productos** · 5 ingredientes.  
**SAC-PLAN-01:** etiquetas comerciales en UI ya; migración de slugs BD en sprint aparte (no bloquea Fase A).

---

## 2. Visión completa — 10 módulos (norte)

### 2.1 Dashboard ejecutivo

Tarjetas y gráficos:

| Bloque | Contenido |
|--------|-----------|
| Restaurantes | Total · activos · suspendidos · eliminados · en prueba · inactivos |
| Planes | Gratis / Pro / Ultra: cantidad · % · ingresos · conversión Gratis→Pro · Pro→Ultra |
| Clientes nuevos | Hoy · semana · mes · año |
| Ingresos SaaS | MRR · ARR · mes · año · proyección próximo mes |
| Crecimiento | Altas · bajas · cancelaciones · renovaciones (gráfico) |

### 2.2 Centro de salud del sistema (interpreta)

No solo CPU/RAM. Frases con semáforo:

- 🟢 Plataforma estable / latencia excelente  
- 🟡 Restaurantes +35 % esta semana / RAM 72 %  
- 🟠 Inventario más lento de lo habitual  
- 🔴 Tiempo de respuesta subió en 2 h / ampliar infra antes de 30 días  

### 2.3 Predicción de escalabilidad (módulo estrella — Fase B+)

Si todo sigue igual: ¿días hasta saturar? ¿restaurantes/usuarios más? ¿cuándo RAM/CPU/DB dedicada/caché/arquitectura distribuida? + explicación sencilla.

### 2.4 Centro de errores inteligente

Agrupa y prioriza (no stack traces):

- 🔴 `/pedidos` falló N veces en 1 h  
- 🟠 Lentitud en analítica  
- 🟡 Un restaurante con errores de impresión repetidos  
- 🟡 Intentos fallidos de auth  
- Tendencias y agrupación de errores iguales  

### 2.5 Monitor de rendimiento

API p50/p95 · queries lentas · endpoints top · errores/min · CPU · RAM · disco · red · latencia BD · WebSockets/Realtime — **siempre traducido** a estado amigable.

### 2.6 Administración de restaurantes

Por cliente: estado, alta, último acceso, plan, historial, vencimiento, pago, #usuarios/#productos/#pedidos, espacio, notas.  
Acciones: cambiar plan, extender, suspender, reactivar, bloquear, reset config, notificar.

### 2.7 Inteligencia comercial

Candidatos a upgrade (cerca del límite Gratis) · uso alto en free · inactivos · crecimiento acelerado · riesgo de cancelación.

### 2.8 Alertas inteligentes

Umbrales + anomalías vs promedio (crecimiento +40 %, memoria en ~15 días, storage, costos vs ingresos, conversión ↑).

### 2.9 Costos de infraestructura

VPS · storage · BD · CDN · externos · dominio · vs ingresos SaaS → margen.

### 2.10 Auditoría de plataforma

Toda acción del superadmin: plan, suspensión, config, límites — fecha, actor, motivo.

### 2.11 Asistente de recomendaciones (no chatbot)

Motor de tips en el home, p. ej.:

- “5 restaurantes a 1 producto del límite Gratis → campaña upgrade.”  
- “API +18 % latencia esta semana → revisar consultas frecuentes.”  
- “Hay margen de servidor; no hace falta ampliar ahora.”  
- “MRR cubre el VPS varias veces → reinvertir en ads o producto.”  

---

## 3. Fase A — Esencial (implementar ahora)

Responde *«¿Cómo está Foody?»* y protege el día del anuncio freemium. **No** incluye predicción ML, costos infra, ni churn scoring.

### 3.1 Alcance Fase A

| # | Entrega | ID |
|---|---------|-----|
| 1 | **Home NOC:** semáforo global + frase + 2–5 recomendaciones (reglas) | SAC-CAP-02 |
| 2 | **KPI planes:** Gratis / Pro / Ultra (cantidad + %) siempre visibles | SAC-KPI-01 |
| 3 | **Altas:** hoy / 7d / 30d + conversión Gratis→pago (simple) | SAC-KPI-02 |
| 4 | **Ingresos básicos:** aprobados 30d + pendientes (ya parcial en `metricasSelfService`) | SAC-KPI-03 |
| 5 | **Restaurantes:** lista rica + cambiar plan / suspender / extender con **motivo + auditoría** | SAC-PLAN-02 |
| 6 | **Freemium:** cupo blando/duro + kill switch (pausa altas) | SAC-FREE-01 |
| 7 | **Salud operativa API:** latencia menú/API + tasa 5xx/timeout → semáforo | SAC-CAP-01 |
| 8 | **Errores agrupados (mínimo):** top rutas con fallos 1 h (tarjetas humanas) | SAC-INC-01 |
| 9 | **Asistente mínimo:** 3–8 tips fijos por reglas (§2.11 subset) | SAC-ASIST-01 |
| 10 | Etiquetas UI **Gratis/Pro/Ultra** (sin migrar BD aún) | SAC-PLAN-01 parcial |

### 3.2 Fuera de Fase A (explícito)

| Módulo visión | Fase |
|---------------|------|
| Predicción “días hasta llenar servidor” / DB dedicada / distribuido | **B** |
| MRR/ARR formales + proyección + gráfico altas/bajas | **B** |
| Inteligencia comercial / churn | **B** |
| Costos infra vs ingresos | **B** |
| Agente host RAM/disco/CPU continuo | **B** (A puede omitir o stub) |
| Anomalías vs baseline 7 días | **B** |
| Asistente rico + FCM críticos | **B** (A = tips in-app) |
| Lista de espera freemium UX completa | **B** (A = bloquear con mensaje) |
| Migración slugs `basico`→`pro` | **B/C** |

### 3.3 Semáforo Fase A (lenguaje dueño)

| Color | Frase ejemplo |
|-------|----------------|
| 🟢 | “Plataforma estable. No hace falta subir el servidor.” |
| 🟡 | “Hay demoras o muchos registros gratis. Revisa cupos o prepara slices.” |
| 🔴 | “Los usuarios sienten lentitud o fallos. Escala YA o pausa altas Gratis.” |

### 3.4 Reglas del asistente (Fase A)

Orden de prioridad:

1. Health crítico / 5xx altos → “Sistema en problemas; revisa incidentes.”  
2. Cupo duro freemium → “Pausa o sube cupo; demasiadas cuentas gratis.”  
3. Latencia menú/API alta + pico uso → “Escala VPS (añade slices).”  
4. Muchas altas gratis + conversión baja → “No pagues más servidor solo por curiosos; mantén límites.”  
5. Restaurantes gratis cerca de 5 productos → “Candidatos a campaña Pro.”  
6. Todo verde → “Hay margen; puedes publicitar con el cupo actual.”

### 3.5 Controles freemium (config global — deben aplicarse en runtime)

| Clave | Default | Efecto |
|-------|--------:|--------|
| `freemium_cupo_blando` | 50 | Aviso 🟡 |
| `freemium_cupo_duro` | 100 | Bloquea altas gratis |
| `freemium_registros_por_hora` | 20 | Rate limit |
| `freemium_pausado` | false | Kill switch |

**Obligatorio:** al implementar SAC-FREE-01, el onboarding self-service **lee** estas claves (hoy hay riesgo **CFG-GLOBAL-DEAD** — UI edita pero runtime ignora).

### 3.6 API Fase A

#### `GET /super/noc/resumen` (o ampliar `GET /super/estadisticas`)

```json
{
  "exito": true,
  "datos": {
    "pregunta": "¿Cómo está Foody?",
    "semaforo": "verde",
    "frase": "Plataforma estable. No hace falta subir el servidor.",
    "recomendaciones": ["Hay margen; puedes publicitar con el cupo actual."],
    "planes": {
      "gratis": { "cantidad": 87, "pct": 85.3 },
      "pro": { "cantidad": 12, "pct": 11.8 },
      "ultra": { "cantidad": 3, "pct": 2.9 }
    },
    "altas": { "hoy": 4, "d7": 22, "d30": 61 },
    "conversion_gratis_a_pago_30d_pct": 8.2,
    "ingresos_cop_30d": 600000,
    "pagos_pendientes": 2,
    "capacidad": {
      "menu_p95_ms": 120,
      "api_p95_ms": 180,
      "errores_5xx_5m": 0,
      "cuentas_gratis": 87,
      "freemium_pausado": false
    },
    "incidentes_abiertos": 0,
    "errores_agrupados": []
  }
}
```

#### `PATCH /super/suscripciones/:id`

Extender: `motivo` **requerido** si cambia `plan` o `estado` → `auditoria_logs`.

#### Errores agrupados

Incluidos en resumen o `GET /super/noc/errores?ventana=1h` — título humano, ruta, count, severidad.

### 3.7 Criterios de aceptación Fase A

1. Home responde *cómo está Foody* con semáforo + frase + tips.  
2. Se ven conteos **Gratis / Pro / Ultra** sin abrir otra sección.  
3. Cambio de plan con motivo queda auditado.  
4. `freemium_pausado` o cupo duro **impide** alta gratis real.  
5. Con carga/lenta simulada, semáforo deja de ser verde.  
6. Al menos una tarjeta de error agrupado cuando hay 5xx repetidos.  
7. Sin Grafana obligatorio; sin predicción de “15 días de RAM” inventada.

### 3.8 Orden de build Fase A

1. SAC-KPI-01 + etiquetas Pro/Ultra en UI  
2. SAC-PLAN-02 (motivo + auditoría)  
3. SAC-FREE-01 (kill switch + cupo — **priorizar si hay anuncio**)  
4. SAC-CAP-01 middleware latencia/errores + `noc/resumen`  
5. SAC-CAP-02 + SAC-ASIST-01 UI home  
6. SAC-INC-01 errores agrupados mínimos  

### 3.9 Base ya existente

| Capacidad | Dónde |
|-----------|--------|
| Panel 7 secciones | `panel_foody_control_screen.dart` |
| Estadísticas + `suscripciones_por_plan` | `GET /super/estadisticas` |
| PATCH plan/estado | `PATCH /super/suscripciones/:id` |
| Health | `/salud`, `/health` |
| Límites Gratis | `plan-features.config.ts` |
| Guard | `SuperAdminGuard` |

---

## 4. Fase B — Tras piloto con clientes de pago

- Predicción de escala (reglas + tendencias 7–30 d; agente RAM/disco)  
- MRR/ARR + gráficos crecimiento  
- Inteligencia comercial (cerca de límite, inactivos)  
- Costos infra (entrada manual o config) vs ingresos  
- FCM crítico al superadmin  
- Baseline / anomalías  
- Lista de espera freemium  

## 5. Fase C — Escala

- Recomendaciones de arquitectura (DB dedicada, caché Redis, multi-nodo)  
- Asistente más rico  
- Migración definitiva de slugs de plan  
- Integraciones opcionales (UptimeRobot → incidentes NOC)

---

## 6. UI — mapa de navegación objetivo

| Nav | Fase A | Visión |
|-----|--------|--------|
| **Inicio (¿Cómo está Foody?)** | ✅ | ✅ |
| Salud / capacidad | ✅ embebido en inicio | ✅ sección propia |
| Errores | ✅ top N en inicio | ✅ centro completo |
| Restaurantes | ✅ | ✅ + historial/notas |
| Planes / suscripciones | ✅ | ✅ |
| Controles freemium | ✅ | ✅ |
| Inteligencia comercial | — | B |
| Costos | — | B |
| Predicción escala | — | B |
| Auditoría | ✅ al cambiar plan | ✅ bitácora completa |
| Ciudades / usuarios / repartidores | ✅ (ya hay) | ✅ |

---

## 7. Fuera de alcance permanente (o muy tarde)

- Grafana/Prometheus como UI principal del dueño (sí como fuente interna).  
- Auto-compra de slices VPS.  
- Chatbot LLM obligatorio (el asistente es **reglas + datos**; LLM opcional mucho después).

---

## Changelog

| Fecha | Cambio |
|-------|--------|
| 2026-08-06 | Elevación a **Centro de Operaciones (NOC)**; 10 módulos visión; **Fase A esencial** acotada; B/C diferidas. |
| 2026-08-06 | Spec inicial Foody Control (SAC-*). |
