# Fondo Emprender (CREAR 2026) — ¿Foody es viable? + Guía de llenado

> Uso interno. Analicé tu plantilla `CREAR_ESP_PROYECTO_2026 06032026.xls` (estaba con el cifrado por defecto de Excel; abre normal). Reconstruí su modelo financiero y lo corrí con números Foody realistas.

---

## ¿Cambia algo lo de escala / usuarios / VPS / NOC? (2026-08)

**Veredicto: NO hay que rearmar la postulación ni el Excel por “50.000–100.000 concurrentes”.**

| Tema | ¿Tocar Excel? | Qué hacer |
|------|---------------|-----------|
| Proyección de ventas Año 1–5 (centenas → miles de suscripciones) | **No** | Ya es realista y pasa TIR/VPN |
| Monto $73,5M / 1 empleo / Individual | **No** | Sigue siendo el bracket correcto |
| Costos VPS ~$600.000/mes | **Opcional** | Sigue OK (cubre VPS 16–32 slices + holgura); no bajes a “casi cero” |
| Rubro nube/APIs $8M | **No** | Encaja con escalar infra cuando crezcas |
| Texto “capacidad ilimitada / 5.000+ simultáneas” | **Sí (texto)** | Suavizar → ver `PROYECTO_…COMPLETO.md` §6 |
| Nombres Pro / Ultra vs Premium | **Opcional** | Mismo precio; alinea si aún no pegaste en Excel |
| Plan Gratis + cupos / Centro de Operaciones | **Solo narrativa** | En canales/proceso: freemium controlado; no inventes filas de producto $0 |
| Arquitectura tipo Mercado Libre | **No en Excel** | Es roadmap técnico futuro; el Fondo evalúa negocio Año 1–5, no Temu |

**Ayuda para la postulación:** hablar de SaaS escalable por etapas + freemium + VPS en costos **refuerza** que sabes operar. Inventar “aguanto 100k simultáneos día 1” **resta** credibilidad ante evaluador técnico.

---

## ✅ VEREDICTO: SÍ ES VIABLE (y con mucho margen)

La herramienta mide viabilidad con **TIR** (Tasa Interna de Retorno) y **VPN** (Valor Presente Neto), comparados contra la **tasa de descuento** (celda gris en hoja *Modelo Financiero*, por defecto **10%**).

- **Es viable si:** `TIR > tasa de descuento` **y** `VPN > 0`.
- **Resultado Foody (escenario conservador):**
  - **TIR ≈ 77%** (muy por encima del 10%) ✅
  - **VPN ≈ +$413 millones** ✅
- **Escenario moderado:** TIR ≈ 115%, VPN ≈ +$825M ✅

> Traducción: el proyecto **pasa el filtro financiero con holgura**. Un SaaS tiene inversión baja e ingresos recurrentes de alto margen, así que la TIR sale alta casi sin importar el escenario. Lo que debes cuidar NO es la viabilidad (sobra), sino la **coherencia** entre las hojas y **cumplir las reglas de monto/empleos** (ver abajo).

---

## 🔑 Reglas clave que trae tu plantilla (hoja "Topes Montos")

- **SMMLV usado:** $1.750.905.
- **Proyecto INDIVIDUAL (tú solo):**

| Monto solicitado | SMMLV | **Empleos mínimos** |
|---|---|---|
| Hasta **$73.538.010** | 0–42 | **1** ← tu caso ideal |
| $75.288.915 – $98.050.680 | 43–56 | 3 |
| $99.801.585 – $122.563.350 | 57–70 | 5 |

- **Asociativo** empieza en 5 integrantes (no aplica a ti).

👉 **Recomendación:** pide **$73.538.010 (42 SMMLV)** en modalidad **Individual**. Es el máximo que puedes pedir **comprometiendo solo 1 empleo (tú)**. Encaja perfecto con "trabajo solo".

> Si quisieras pedir más ($98M o $122M), estarías **obligado a crear 3 o 5 empleos**. No lo hagas salvo que de verdad vayas a contratar.

---

## 📄 Cómo se llena (solo celdas GRISES). Valores sugeridos para Foody

La hoja **Proyecto** alimenta sola a *Modelo Financiero* y *Resumen*. Lo único que se toca en *Modelo Financiero* es la **tasa de descuento (déjala en 10%)**.

### Datos generales
- **Líder:** tú (CC).
- **Nombre iniciativa:** Foody (o el nombre de tu empresa de software SaaS).
- **Categoría / Sector:** Todos los sectores → actividad de **desarrollo de software / servicios TI** (código CIIU 6201 - Desarrollo de sistemas informáticos).
- **Tipo de proyecto:** Individual.
- **Registro formal (punto 7):** **S.A.S (1 solo socio)** ← marca esta. Es la mejor figura para software.
- **Lugar de operación:** sí (tu casa/oficina; luego toca acreditar uso de suelo).

### 5. Productos o servicios (máximo 3) → usa los planes
| # | Producto (servicio) | Unidad | Precio Año 1 |
|---|---|---|---|
| 1 | **Suscripción Foody Pro** | suscripción/mes | **$50.000** |
| 2 | **Suscripción Foody Premium** | suscripción/mes | **$100.000** |
| 3 | **Suscripción Tu Cancha Fácil Pro** | suscripción/mes | **$50.000** |

> "Unidades vendidas" = número de suscripciones activas que pagan ese mes. Ingresos = unidades × precio. Así el modelo captura tu MRR.
> Incremento de precio anual: deja **10%** (ya viene por defecto).

### 9. Proyección de ventas — unidades (suscripciones activas) mes a mes, Año 1
| Mes | Pro | Premium | TCF |
|---|---|---|---|
| 1 | 5 | 0 | 0 |
| 2 | 12 | 1 | 2 |
| 3 | 22 | 2 | 4 |
| 4 | 35 | 4 | 6 |
| 5 | 50 | 6 | 9 |
| 6 | 70 | 9 | 12 |
| 7 | 95 | 12 | 15 |
| 8 | 120 | 16 | 19 |
| 9 | 150 | 20 | 23 |
| 10 | 180 | 25 | 27 |
| 11 | 210 | 30 | 32 |
| 12 | 245 | 36 | 38 |

Años 2–5 (suscripción-meses del año = promedio activos × 12), escenario **conservador**:

| Producto | Año 2 | Año 3 | Año 4 | Año 5 |
|---|---|---|---|---|
| Pro | 2.400 | 4.000 | 5.800 | 7.400 |
| Premium | 600 | 1.000 | 1.500 | 1.900 |
| TCF | 900 | 1.600 | 2.300 | 3.000 |

*(Estas cifras dan ventas ~$180M / $320M / $480M / $650M en A2–A5.)*

### 10. Costos y gastos
- **Costos fijos (mensual):** servidores/VPS + dominios + herramientas + contador ≈ **$1.500.000/mes**.
- **Costos variables (materia prima) por suscripción/mes:** pasarela de pago (Wompi ~2,65%) + infraestructura variable ≈ **$3.000** (Pro/TCF) y ≈ **$4.500** (Premium). ≈ 6% de las ventas.
- **% participación en ventas:** Pro ~65%, Premium ~20%, TCF ~15% (ajústalo a las cifras).

### 11. Equipo de trabajo (define el indicador "Empleos a crear")
| Rol | Vinculación | Asignación mensual | Meses Año 1 |
|---|---|---|---|
| **Desarrollador / Fundador (tú)** | Contrato laboral término indefinido | **$2.500.000** | 12 |

> El factor prestacional (**53,76%**) lo agrega la hoja sola. **Con 1 cargo cumples el mínimo del bracket de 42 SMMLV.**

### 8. Canales / Publicidad (define indicador "Eventos de mercadeo")
- Redes sociales (Meta/TikTok/Google Ads), landing web, video promocional. Asígnale valor (ej. Año 1 ~$24M en *Gastos de administración y ventas → Publicidad*).

### 12. Necesidades y requerimientos (esto = lo que pides al Fondo, ≤ $73.538.010)
Reparte el monto en rubros **financiables** (software SÍ es financiable):

| Rubro financiable | Valor sugerido |
|---|---|
| Adquisición de maquinaria, **equipos y software** (equipo de cómputo dev + licencias/herramientas) | $18.000.000 |
| Insumos para el ciclo productivo (créditos de nube/infra prepago, APIs) | $8.000.000 |
| **Pago de salarios** (tuyo; el Fondo cubre mín. 4 meses por empleo) | $18.500.000 |
| Adquisición/arriendo de bienes muebles (muebles y enseres, ≤15%) | $6.000.000 |
| Permisos, licencias y registros | $3.000.000 |
| Tasas registro **propiedad intelectual/industrial** (marca + software, ≤20%) | $4.000.000 |
| Publicidad de lanzamiento / estrategia de comunicación (preoperativo) | $16.000.000 |
| **TOTAL SOLICITADO** | **≈ $73.500.000** ✅ dentro del tope |

> ⚠️ La **constitución legal de la SAS NO es financiable** — la asumes tú (aparte).
> ⚠️ Cada rubro tiene un **límite %** (ej. muebles ≤15%, adecuaciones ≤20%, adecuaciones técnicas ≤50%). Respeta esos topes o la hoja marca error.

### 15. Plan operativo
Distribuye ese monto por meses (los recursos deben ejecutarse **máx. hasta el mes 9**). Ej.: equipos/software y publicidad en meses 1–2; salarios repartidos meses 1–9.

### Modelo Financiero
- **Solo** llenas la **tasa de descuento** → déjala en **10%** (0,10).

---

## 📊 Estado de resultados que resulta (escenario conservador, millones COP)

| Concepto | Año 1 | Año 2 | Año 3 | Año 4 | Año 5 |
|---|---:|---:|---:|---:|---:|
| Ventas | 85 | 180 | 320 | 480 | 650 |
| − Materia prima (~6%) | 5 | 11 | 19 | 29 | 39 |
| − Mano de obra (tú, +10%/año) | 46 | 51 | 56 | 61 | 67 |
| − Costos fijos | 18 | 20 | 22 | 24 | 26 |
| − Permisos (única vez) | 2 | — | — | — | — |
| **= Utilidad bruta** | 14 | 99 | 224 | 366 | 517 |
| − Gastos admin/ventas (publicidad) | 24 | 55 | 95 | 140 | 180 |
| **= Utilidad neta** (individual, **sin impuesto de renta**) | **−10** | **44** | **128** | **226** | **337** |

**Flujo de caja para evaluación:** Año 0 = −$73,5M (inversión) · luego −10 / 44 / 128 / 226 / 337.
→ **VPN ≈ +$413M · TIR ≈ 77%.** ✅ Viable.

> Nota: como el proyecto es **individual, la hoja NO calcula impuesto de renta** (lo dice la propia plantilla). Eso sube la utilidad neta.

---

## ⚠️ Por qué "llenarlo automáticamente" no conviene

La plantilla pide **no tocar fórmulas, formatos ni estructura** (y está protegida). Si un script escribe dentro del `.xls`, **rompe las fórmulas** que calculan TIR/VPN y la invalida para evaluación. Por eso te doy los **valores exactos por sección** para que tú los escribas en las **celdas grises** dentro de Excel: así la herramienta recalcula sola y conserva su integridad.

---

## 🎯 Lo que sí debes cuidar (no es la viabilidad, sobra)

1. **Coherencia entre hojas:** unidades × precio = ingresos que ves reflejados; empleos del punto 11 = indicador; monto del punto 12 = valor solicitado.
2. **Monto ≤ $73.538.010** con **1 empleo** (Individual).
3. **Constitución SAS** aparte (no financiable).
4. **Acompañamiento del SENA** (Centro de Desarrollo Empresarial) — es obligatorio para formular; ellos revisan la coherencia.
5. Justificar la **proyección de ventas** (por qué crece): mercado de 250.000+ negocios de comida, freemium + publicidad, bajo costo marginal. (Ver `docs/ANALISIS_MERCADO_FOODY.md`.)

---

*Resumen: financieramente Foody pasa de sobra (TIR 77–115% vs 10% exigido). El trabajo real es diligenciar bien las celdas grises con estos números y mantener la coherencia. Pide 42 SMMLV en modalidad individual con 1 empleo.*
