# Foody — Análisis de mercado y negocio (uso interno)

> Documento **solo para ti**. Cifras de mercado reales (Colombia/LATAM 2025–2026) + proyecciones ficticias pero calibradas a tu caso: **desarrollador solo**, SaaS de bajo soporte, cobro dentro de la app, crecimiento por publicidad.
> Moneda: COP. SMMLV usado de referencia: **$1.500.000** (para traducir montos de Fondo Emprender).
> Idea de negocio para Fondo Emprender: **empresa de desarrollo de software SaaS**, con dos productos iniciales: **Foody** (POS restaurantes) y **Tu Cancha Fácil** (reservas de canchas). Este documento se centra en Foody.

---

## 0. Resumen ejecutivo (lo que importa en 1 minuto)

- **Producto:** Foody, POS/gestión todo-en-uno para restaurantes, cocinas ocultas y emprendimientos de comida. Ya tienes construido lo difícil: pedidos, mesas/QR, caja, cocina/KDS, inventario, **costeo industrial**, domiciliarios, analítica, multi-sucursal y **cobro self-service** (freemium + Wompi).
- **Modelo:** Freemium. Gratis (limitado) → **Pro $50.000/mes** (gancho: **$25.000 el 1er mes**) → **Premium/Plus $100.000/mes**.
- **Mercado Colombia:** ~90.000 restaurantes formales + cientos de miles de informales/emprendimientos → mercado alcanzable realista **~120.000 negocios**.
- **Ventaja de tu modelo:** margen bruto SaaS **~80–90%**, casi sin soporte, casi sin costo marginal por cliente. El gasto real es **publicidad** e infraestructura.
- **Proyección conservadora (solo tú):** ~**250 clientes de pago** fin de año 1, ~**900** año 2, ~**2.000** año 3.
- **MRR objetivo:** ~$14M/mes fin de año 1 → ~$50M/mes año 2 → ~$115M/mes año 3.
- **Riesgo #1 de margen:** si cobras *dentro* de la app por Play/App Store, Google/Apple se llevan **15–30%**. Solución: cobrar como SaaS web (Wompi ~2,65%) y que la app solo enlace. (Ver §5).
- **Fondo Emprender:** encaja como creación de empresa de base tecnológica; pero **exige generar empleo formal** y viabilidad. "Trabajar solo" hay que replantearlo como "eres el primer empleado de la empresa y contratas 1–2 personas con el capital semilla". (Ver §9).

---

## 1. El mercado (tamaño y por qué es grande)

### 1.1 Cifras base (Colombia)
| Dato | Valor aprox. | Fuente/lógica |
|---|---:|---|
| Restaurantes formales | ~90.000 | ACODRES/Fenalco (rango 80k–93k citado 2023–2025) |
| Gasto de hogares en comida fuera | ~$40 billones/año | Sector food service Colombia |
| Negocios de comida totales (formal + informal + cocinas ocultas + emprendimientos) | **250.000–300.000** | Informalidad ~60% del sector |
| Crecimiento cocinas ocultas / dark kitchens | Doble dígito anual | Boom post-domicilios (Rappi/DiDi/iFood) |
| Penetración de smartphone en dueños | Muy alta | Todos gestionan por celular |

### 1.2 Embudo de mercado (TAM / SAM / SOM)
- **TAM (todo el que podría usar un POS de comida en Colombia):** ~250.000 negocios.
- **SAM (los que puedes servir hoy: hispanohablantes, con celular, dispuestos a pagar un SaaS barato, inician en Colombia):** **~120.000 negocios**.
- **SOM (lo que realmente capturas tú solo en 3 años):** 0,5%–2% del SAM = **600 a 2.400 clientes de pago**. Trabajamos con ~2.000 como meta año 3.

> **Conclusión:** no necesitas "todo el mercado". Con **capturar el 1–2% ya tienes un negocio muy rentable** siendo una sola persona, porque el software se replica sin costo.

### 1.3 Por qué este mercado es ideal para un solo dev
1. **Enorme y fragmentado** → nadie lo domina en el segmento micro/pequeño.
2. **Dolor real y diario:** cuadre de caja, robo de inventario, no saber si ganan, domicilios desordenados. Foody lo resuelve.
3. **Bajo poder de negociación individual** → precio fijo, autoservicio, sin vendedores.
4. **Viralidad natural:** un dueño con 2 sedes, o que recomienda a otro dueño amigo.

---

## 2. Competencia directa

### 2.1 Competidores reales
| Competidor | Origen | Precio aprox. (COP/mes) | Fortaleza | Debilidad frente a Foody |
|---|---|---:|---|---|
| **Loyverse** | Global | Gratis + ~$100k (add-ons) | POS gratis muy pulido, marca | No pensado para restaurante LATAM completo (sin costeo, sin domicilios propios, sin cocina KDS integrada fuerte) |
| **Fudo** | Argentina/LATAM | ~$120k–$250k | Muy fuerte en restaurantes, KDS, comandas | Más caro; enfoque restaurante formal, no micro/emprendedor |
| **Alegra POS** | Colombia/LATAM | ~$50k–$150k | Integra contabilidad/facturación DIAN | POS más simple; menos operación de cocina/domicilios |
| **Siigo** | Colombia | ~$70k–$200k+ | Contabilidad líder, marca, DIAN | Pesado, contable-first, no operación restaurante fina |
| **Wilpos / Simo / Bepos / Nube** | Colombia | Gratis–$120k | Baratos, locales | UX floja, poco todo-en-uno, poco domicilio/cocina |
| **Toteat / Maxirest / ICG** | LATAM/España | $200k+ | Robustos restaurante grande | Caros, complejos, requieren instalación/soporte |
| **Rappi / DiDi Food / iFood** | Marketplace | Comisión 12–30% por pedido | Tráfico masivo | **No son POS**: te cobran comisión por venta, no te dan gestión interna. Son complementarios, no sustitutos |
| **Square / Toast** | EE.UU. | — | Referentes mundiales | Casi sin presencia/soporte Colombia |

### 2.2 Mapa de posicionamiento
- **Eje precio:** Foody ($50k) queda **por debajo de Fudo/Siigo/Toteat** y **al nivel de Alegra**, pero ofreciendo **más operación** (cocina, domicilios propios estilo inDriver, costeo industrial).
- **Eje "todo-en-uno":** casi nadie junta en un solo producto barato: **POS + mesas/QR + cocina/KDS + inventario + costeo + domiciliarios + analítica + multi-sede**. Ese es tu **foso**.

### 2.3 Tu ventaja competitiva (lo que dirás en la propuesta)
1. **Todo-en-uno real** a precio de POS básico.
2. **Costeo industrial (KYG):** le dice al dueño cuánto gana por plato. Loyverse/Wilpos no lo hacen. Enorme diferenciador.
3. **Domicilios propios** (planta + independientes tipo inDriver, GPS, ofertas 60s) → **evita pagar 20–30% a Rappi**. Argumento de venta brutal.
4. **Autoservicio 100%:** descarga, prueba gratis, paga en la app. Sin vendedor, sin instalación → **escalable por una persona**.
5. **Precio en COP, español, hecho para el micro-negocio LATAM.**
6. **Multi-sucursal** desde el mismo plan → crece con el cliente (cadenas).

---

## 3. Modelo de negocio y precios

### 3.1 Planes
| Plan | Precio | Para quién | Qué incluye (resumen) |
|---|---:|---|---|
| **Gratis** | $0 | Prueba / negocio muy pequeño | Menú, pedidos básicos, límites (1 sede, pocos productos/usuarios). Anzuelo de adquisición. |
| **Pro** | **$50.000/mes** (gancho **$25.000 1er mes**) | El grueso del mercado | Costeo, inventario, caja completa, cocina/KDS, reportes, analítica básica, promociones. |
| **Premium/Plus** | **$100.000/mes** | Negocios serios / varias sedes | Multi-sucursal, analítica avanzada (BI), domiciliarios avanzado, soporte prioritario, sin límites. |

### 3.2 Palancas de ingreso extra (opcionales, futuro)
- **Anual con descuento:** paga 10 meses, usa 12 → mejora caja y baja churn.
- **Add-ons:** sedes adicionales, usuarios extra, módulo de facturación DIAN (cuando exista), impresión.
- **Comisión de domicilios** propios muy baja (ej. $200–$500/pedido) como upsell.

### 3.3 Por qué el gancho de $25.000 funciona
- Baja la barrera de entrada psicológica.
- El costeo/inventario **engancha con datos**: cuando el dueño ya metió su menú y su inventario, cambiar de sistema duele → **retención por dato cargado** (switching cost).

---

## 4. Unit economics (la parte que decide todo)

> Clave del SaaS: **cuesta casi lo mismo tener 100 o 10.000 clientes**. El costo marginal por cliente tiende a $0.

### 4.1 Ingreso promedio por cuenta (ARPU)
Supongamos mezcla: 75% Pro ($50k) + 25% Premium ($100k) → **ARPU ≈ $62.500/mes**.
(Conservador, usaremos **$55.000** para dejar colchón por el mes-gancho y anuales.)

### 4.2 Costos por cliente
| Concepto | Costo | Nota |
|---|---:|---|
| Infraestructura (VPS, Supabase, storage) | ~$1.000–$3.000/mes por cliente al inicio; **cae con escala** | Un VPS sirve a cientos de tenants |
| Pasarela de pago (Wompi) | ~2,65% + ~$700 por cobro | Sobre $50k ≈ **$2.000/cobro** |
| Soporte | ~$0 (autoservicio) | Tu gran ventaja |
| **Costo total variable/cliente/mes** | **~$3.000–$5.000** | |

→ **Margen bruto ≈ 85–90%.** Esto es lo que hace atractivo el negocio.

### 4.3 CAC (costo de adquirir un cliente que paga)
- Canal principal: **publicidad** (Meta/Instagram, TikTok, Google) + contenido.
- Embudo: Anuncio → descarga → crea negocio (free) → convierte a Pro.
- Estimación realista Colombia:
  - Costo por descarga: ~$1.500–$4.000
  - Free que crea negocio: ~40% de descargas
  - Conversión free→pago: ~4–8%
- **CAC resultante estimado: $40.000–$90.000 por cliente de pago.** Usaremos **$60.000**.

### 4.4 LTV (valor de vida del cliente)
- Churn mensual SMB comida: ~5–7% → **vida promedio ~15–18 meses**.
- LTV = ARPU × margen × vida = $55.000 × 0,87 × 16 ≈ **$765.000**.
- **LTV/CAC = 765.000 / 60.000 ≈ 12,7×.** (Sano es >3×). **Excelente.**
- **Payback del CAC:** ~1,3 meses de suscripción. Recuperas la inversión publicitaria rapidísimo.

> **Traducción:** por cada $60.000 que gastas en publicidad bien hecha, recuperas ~$765.000 en el tiempo de vida del cliente. Ese es el corazón de tu propuesta.

---

## 5. ⚠️ Alerta de margen: cómo cobrar dentro de la app

Dijiste "se paga desde la misma app, en Play Store / App Store". Ojo con esto:

| Vía de cobro | Comisión | Efecto |
|---|---:|---|
| Compra dentro de la app (In-App Purchase de Google/Apple) | **15–30%** | Te comes hasta $15.000 de cada $50.000. **Mata margen.** |
| Pago SaaS web (Wompi/PSE/tarjeta) enlazado desde la app | **~2,65%** | Conservas ~97% del ingreso. |

**Recomendación:** cobra como **suscripción SaaS web** (ya tienes Wompi integrado). La app puede llevar al usuario a completar el pago (o pagar por PSE/tarjeta vía Wompi). Muchos SaaS B2B (Netflix histórico, Spotify) evitan el pago in-app justo por esto. Google/Apple permiten apps de negocio (B2B) que cobran servicios por fuera. **Esto solo lo tienes que tener claro tú**, no cambia tu producto, solo protege tu plata.

---

## 6. Proyección financiera (3 años, conservadora, tú solo)

> Supuestos: publicidad constante y creciente, conversión mejorando con el tiempo, ARPU $55.000, margen 87%.

### 6.1 Clientes y MRR
| Periodo | Descargas acum. | Negocios free | **Clientes de pago (fin)** | **MRR (fin)** | ARR aprox. |
|---|---:|---:|---:|---:|---:|
| Fin Año 1 | ~8.000 | ~3.000 | **~250** | **~$13,8M/mes** | ~$165M |
| Fin Año 2 | ~25.000 | ~9.000 | **~900** | **~$49,5M/mes** | ~$594M |
| Fin Año 3 | ~55.000 | ~20.000 | **~2.000** | **~$110M/mes** | ~$1.320M |

### 6.2 Estado de resultados simplificado (anual)
| Concepto | Año 1 | Año 2 | Año 3 |
|---|---:|---:|---:|
| Ingresos | ~$90M | ~$360M | ~$800M |
| Costos variables (infra + pasarela, ~13%) | ~$12M | ~$47M | ~$104M |
| **Margen bruto (~87%)** | **~$78M** | **~$313M** | **~$696M** |
| Publicidad/marketing | ~$40M | ~$120M | ~$220M |
| Infra base + herramientas + software | ~$8M | ~$15M | ~$25M |
| Tu salario (1 persona) | ~$36M | ~$48M | ~$60M |
| Empleado(s) nuevos (soporte/marketing/dev) | $0–$18M | ~$60M | ~$140M |
| Legal/contable/constitución | ~$6M | ~$8M | ~$10M |
| **Utilidad operativa aprox.** | **~ -$12M a $0** | **~$62M** | **~$241M** |

> Año 1 puede quedar en **punto de equilibrio o leve pérdida** (normal, estás invirtiendo en adquirir clientes). Desde año 2 el modelo **se vuelve muy rentable** porque la base de suscriptores paga mes a mes y el costo de servirlos no crece igual.

### 6.3 Punto de equilibrio operativo
- Costos fijos mensuales base (tu salario + infra + herramientas) ≈ **$4M–$5M/mes**.
- Con ARPU $55.000 y margen 87% (~$48.000 neto/cliente): **equilibrio ≈ 90–105 clientes de pago.**
- **Lo cruzas dentro del año 1.** Todo cliente por encima de ~100 es utilidad.

---

## 7. Ciclos de caja y flujo (cómo se mueve la plata)

1. **Adquisición:** gastas en publicidad HOY → el cliente convierte a pago en días/semanas.
2. **Cobro recurrente:** Wompi cobra automático cada mes (ya lo tienes: cron de renovación). **Ingreso predecible = lo que aman los inversores/Fondo.**
3. **Payback rápido:** recuperas el CAC en ~1,3 meses.
4. **Efecto bola de nieve (MRR):** cada mes empiezas con los clientes del mes anterior + los nuevos − los que se van (churn). Por eso el MRR crece "solo" si mantienes bajo el churn.
5. **Estacionalidad:** picos en fin de año y mitad de año (más restaurantes activos, más aperturas). Ajusta publicidad a esos picos.
6. **Riesgo de caja año 1:** la publicidad se paga por adelantado y el ingreso llega diferido → **por eso pides capital semilla** (Fondo Emprender) para financiar ese arranque sin ahogarte.

---

## 8. Inversión necesaria (para arrancar bien)

| Rubro | Año 1 (estimado) | Para qué |
|---|---:|---|
| **Publicidad / marketing** | $30M–$50M | Lo más importante: llenar el embudo. |
| **Infraestructura** (VPS, dominios, Supabase, storage, FCM) | $6M–$10M | Servidores prod, backups, monitoreo. |
| **Cuentas de tienda** | ~$0,5M | Google Play ($20k una vez), Apple ($400k/año aprox). |
| **Legal / constitución empresa / contador** | $4M–$8M | SAS, RUT, cámara de comercio, contabilidad. |
| **Equipo/portátil, herramientas, licencias** | $4M–$8M | Tu herramienta de trabajo + diseño/ads tools. |
| **Tu salario (fundador-dev)** | $30M–$40M | Sostenerte para dedicarte full-time. |
| **1 persona de apoyo** (marketing o soporte medio tiempo) | $0–$18M | Requisito de empleo Fondo Emprender (ver §9). |
| **Contingencia (10–15%)** | $8M–$15M | Imprevistos. |
| **TOTAL orientativo Año 1** | **~$90M–$150M** | ≈ **60–100 SMMLV** |

> Este total (~60–100 SMMLV) **encaja dentro de lo que financia Fondo Emprender** (hasta 180 SMMLV). No pidas el máximo si no lo justificas; pide lo que el plan sustenta.

---

## 9. Encaje con Fondo Emprender (SENA) — lo que debes saber

### 9.1 Qué es (para tu propuesta)
- Capital semilla **condonable** (no lo devuelves si cumples metas de empleo y ejecución) de **hasta 180 SMMLV** (~$270M con SMMLV $1,5M).
- Ideal para **empresa de base tecnológica** como la tuya (desarrollo de software SaaS).

### 9.2 El punto crítico: "trabajo solo"
Fondo Emprender **financia creación de empresa con generación de empleo formal**, no un freelance individual. Cómo lo resuelves sin traicionar tu realidad:
- Tú te conviertes en el **primer empleado formal** de tu propia SAS (fundador que se contrata).
- El plan **debe crear al menos 1–2 empleos formales adicionales** (ej.: 1 persona de marketing/growth y/o 1 de soporte-QA). Encaja perfecto: tú sigues siendo el que desarrolla, pero delegas publicidad y atención mínima.
- Esto **fortalece la propuesta** (más empleo = más puntaje) y **libera tu tiempo** para lo que solo tú puedes hacer: el producto.

### 9.3 Qué valoran y cómo lo tienes cubierto
| Criterio Fondo Emprender | Cómo lo cumple Foody |
|---|---|
| Innovación / base tecnológica | SaaS propio, costeo industrial, domicilios propios, multi-sede. |
| Mercado y demanda | 250k+ negocios de comida; dolor validado. (§1) |
| Viabilidad financiera | Márgenes 85–90%, LTV/CAC ~12×, MRR recurrente. (§4, §6) |
| Generación de empleo | 1 (tú) + 1–2 nuevos con el capital. (§8, §9.2) |
| Uso claro de recursos | Desglose de inversión. (§8) |
| Escalabilidad | Costo marginal ~$0; mismo producto sirve a miles. |
| Sostenibilidad | Ingreso recurrente, no depende de un solo cliente. |

### 9.4 Dos productos en la misma empresa
- La empresa es la **software factory SaaS**; Foody y Tu Cancha Fácil son **líneas de producto**.
- Ventaja para la propuesta: **diversificación de riesgo** (dos mercados: comida y deporte) con **misma infraestructura y mismo dueño-desarrollador** → eficiencia de costos.
- Sugerencia: en la propuesta, **Foody como producto ancla** (mercado más grande) y Tu Cancha Fácil como segunda línea/expansión.

---

## 10. Plan de publicidad (barata, llamativa, para este mercado)

1. **Video corto vertical** (TikTok/Reels): "Cuánto ganas REALMENTE por hamburguesa" → muestra el costeo. Duele y engancha al dueño.
2. **Antes/después:** cuaderno y calculadora vs. Foody. Nostalgia + solución.
3. **Ángulo anti-Rappi:** "Deja de regalar el 30% de tus ventas. Ten tus propios domiciliarios." Muy compartible.
4. **Prueba gratis + gancho $25.000:** CTA claro, sin fricción, sin vendedor.
5. **Segmentación:** dueños de restaurantes, emprendedores de comida, cocinas ocultas, foodtrucks; intereses en Rappi, Fudo, cocina, emprendimiento.
6. **Contenido orgánico** (educativo sobre costos/inventario) para bajar el CAC con el tiempo.
7. **Referidos:** un mes gratis por traer a otro dueño → crecimiento viral barato.

**Regla de oro:** mide **CAC por canal** y mata lo que no convierte. Con LTV ~$765k y CAC ~$60k tienes muchísimo margen para experimentar.

---

## 11. Riesgos y cómo los mitigas

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Comisión in-app 15–30% | Alto (margen) | Cobrar SaaS web vía Wompi. (§5) |
| Churn alto (negocios que cierran) | Medio | Enganche por datos cargados, anual con descuento, valor en costeo. |
| Depender solo de ti (bus factor) | Alto | Contratar 1–2 con capital semilla; documentar (ya lo haces). |
| Competidor gratis (Loyverse) | Medio | Diferenciar por costeo + domicilios + todo-en-uno LATAM. |
| Soporte creciente pese a "autoservicio" | Medio | Onboarding guiado en app, tutoriales, FAQ, chatbot básico. |
| Impresión física / DIAN pendientes | Medio | Ya identificados en MASTER_STATUS; no bloquean el cobro SaaS. |
| Publicidad se encarece | Medio | Contenido orgánico + referidos para bajar CAC. |

---

## 12. Números para memorizar (tu "pitch")

- Mercado alcanzable: **~120.000 negocios de comida** en Colombia.
- Con **2%** capturado en 3 años = **~2.000 clientes** → **~$110M/mes** de ingreso recurrente.
- Margen bruto: **~87%**.
- **LTV/CAC ≈ 12×**, payback **~1,3 meses**.
- Punto de equilibrio: **~100 clientes de pago** (alcanzable en año 1).
- Inversión de arranque: **~60–100 SMMLV** (dentro de Fondo Emprender).
- Empleo generado: **1 (tú) + 1–2 nuevos**.

---

*Documento interno de trabajo. Cifras de proyección son estimaciones calibradas, no garantías. Actualízalo cuando tengas datos reales de descargas, conversión y CAC (esos tres números lo cambian todo).*
