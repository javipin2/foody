# Foody — Self-service, plan gratis y cobro automático (spec)

> **Documento de planificación (2026-06-24).** Estrategia + arquitectura para que un restaurante se registre, use y pague **solo**, sin intervención manual del dueño de Foody.
> Relacionado: `docs/PLANES_SUSCRIPCION.md` (brecha plan↔módulos), `docs/MODULO_ANALITICA_BI.md`, `docs/MULTI_SUCURSAL.md`.
> Estado vivo: `docs/AVANCE_PROYECTO.md` · Mapa módulos: `docs/MODULOS_ESTADO.md`.

---

## 1. Objetivo (el ciclo que queremos)

Que cualquier restaurante pequeño pueda: **descargar → registrarse → usar gratis → pagar solo cuando quiera más → si no paga, sentir que le hace falta y volver**, todo sin que el equipo de Foody toque nada.

```
Descarga (Play Store / web)
   ↓
Crea cuenta (Google o correo)  →  se crea SU restaurante automáticamente
   ↓
Rol DUEÑO (admin) + plan GRATIS
   ↓
Usa: menú, pedidos, caja básica  →  ve valor (márgenes, análisis al probar)
   ↓
Quiere más (inventario, costeo, KDS, domicilios)  o se le vence prueba
   ↓
Botón «Mejorar plan» → Wompi (pago recurrente) → webhook → plan activo al instante
   ↓
Si no paga: estado `bloqueada` (NO se borra, datos 30 días) → siente el vacío → reactiva
```

**Principio comercial:** el gancho de pago es el **costeo + Centro de Análisis** (`docs/MODULO_ANALITICA_BI.md`), no “más botones”. El gratis trae volumen y boca a boca; el dolor de no ver márgenes empuja al pago.

---

## 2. Estado actual vs objetivo

| Pieza | Hoy en código | Falta para self-service |
|-------|---------------|--------------------------|
| Tabla `suscripciones_restaurante` (estado/plan/vencimiento) | ✅ `011_super_admin.sql` | Añadir plan `gratis` al CHECK |
| Onboarding restaurante (crea rest + sucursal + cocina + horarios + suscripción + usuario) | ✅ `super-admin.service.ts → crearRestaurante()` **solo lo ejecuta super_admin** | Endpoint **público** que reutilice esa lógica |
| Login | ✅ correo/clave (`auth.service.ts → login`) | Login con **Google (OAuth)** |
| Plan en JWT + módulos | ✅ `PlanFeaturesService`, `plan-features.config.ts` | Añadir tier `gratis` con sus límites/módulos |
| Guard de módulos por plan | ✅ `PlanFeaturesGuard` + `@RequiereModulo` | — (ya sirve; solo definir matriz `gratis`) |
| Límites numéricos (sucursales/usuarios) | ✅ `LIMITES_POR_PLAN` | Fila `gratis` |
| Vencimiento automático | ✅ existe (`suscripciones-cron.service.ts`, cada hora `activa`/`prueba`→`vencida`) | Solo faltan **avisos previos** (3 días antes) y bloqueo-no-borra a 30 días |
| Cobro / upgrade solo | ❌ | Pasarela **Wompi** + webhook + tabla de pagos |
| UI registro / upgrade / candados | ❌ | Pantallas Flutter |

**Resumen:** la base operativa, de planes y el **cron de vencimiento ya existen**. Faltan **3 piezas nuevas**: auto-registro público, login Google, y cobro Wompi (+ avisos de vencimiento).

---

## 3. Roles y autenticación

### Rol del que se registra

- El que crea la cuenta queda como **dueño del restaurante**. En el código actual ese rol se llama **`admin`** (ver `crearRestaurante()` → `rol = 'admin'`). Es el rol más alto dentro del restaurante (no `super_admin`, que es solo Foody).
- Desde ahí el dueño invita staff (cajero, mesero, cocina, domiciliario) según límite del plan (`assertLimiteUsuariosStaff`).

### Auth recomendada

| Método | Por qué |
|--------|---------|
| **Google OAuth** (vía Supabase Auth) | Mínima fricción: un toque, sin recordar clave. Ideal para dueños no técnicos. |
| Correo + contraseña | Alternativa; ya implementado (`bcrypt` + `usuarios.hash_contrasena`). |

**Implementación Google:** Supabase Auth ya está en el stack. El flujo:
1. Flutter inicia OAuth Google (Supabase) → obtiene `id_token` / sesión Supabase.
2. Backend valida el token, busca `usuarios` por email; si no existe y viene de registro, dispara el **auto-registro** (sección 4).
3. Backend emite **su propio JWT** (el mismo `JwtPayload` actual con `plan`, `permisos`, `rol`) para no cambiar los guards.

> Mantener un solo modelo de sesión: Supabase solo para identidad; **el JWT de NestJS sigue siendo la autoridad** de permisos/plan (no romper guards existentes).

---

## 4. Auto-registro público (la pieza que más libera trabajo)

### Endpoint nuevo

```
POST /auth/registro-restaurante      (público, sin JWT)
```

Body (borrador):
```json
{
  "nombre_restaurante": "Sazón de la 8",
  "ciudad_id": "uuid",
  "nombre_sucursal": "Sede principal",
  "direccion_sucursal": "opcional",
  "dueno_nombre": "Javier",
  "email": "javier@correo.com",
  "contrasena": "opcional si viene de Google",
  "proveedor_auth": "google | correo"
}
```

### Lógica

Reutilizar **la misma transacción** de `super-admin.service.ts → crearRestaurante()`, que ya crea en bloque atómico:
- `restaurantes` → `sucursales` → `cocinas` (Cocina principal) → `horarios_sucursal` (08:00–22:00) → `suscripciones_restaurante` → `usuarios` (rol `admin`).

Cambios respecto al onboarding del super admin:
1. **Plan inicial = `gratis`** (o `prueba` 14 días — ver sección 6, decisión recomendada: **gratis permanente**).
2. Si `proveedor_auth = google`, no exigir contraseña (vincular identidad Supabase).
3. **Rate limit + validación anti-spam** (un email = un restaurante; captcha o verificación email).
4. Devolver JWT listo para entrar directo (no obligar segundo login).

### Seguridad

- Validar `ciudad_id` activa (ya lo hace).
- Email único (ya lo valida con `ConflictException`).
- Throttling del endpoint (es público).
- Verificación de email (link) antes de permitir operar, o permitir uso inmediato y verificar en background.

---

## 5. Planes (incluyendo el nuevo GRATIS)

### Matriz objetivo

| Módulo / feature | **Gratis** | Básico | Pro | Enterprise |
|------------------|:---:|:---:|:---:|:---:|
| Menú + pedidos + caja básica | ✅ | ✅ | ✅ | ✅ |
| Mesas QR | ✅ | ✅ | ✅ | ✅ |
| Inventario + **costeo** | ❌ | ❌ | ✅ | ✅ |
| **Centro de Análisis (BI)** | ❌ (demo limitada) | 🟡 básico | ✅ | ✅ |
| Cocina / KDS / impresoras | ❌ | ❌ | ✅ | ✅ |
| Domiciliarios | ❌ | ❌ | ✅ | ✅ |
| Facturación electrónica (DIAN) | ❌ | ❌ | ❌ | ✅ |
| Multi-sucursal | 1 | 1 | hasta 3 | ilimitado |

> El **costeo y el análisis** (la joya) viven de Pro hacia arriba. El gratis deja **probar el dolor** (registra recetas pero ve el análisis bloqueado con candado y un “preview” de lo que vería).

### Cambios en código de planes

`plan-features.config.ts`:
- Añadir `'gratis'` a `PlanComercial` y `PLAN_NIVEL` (nivel 0).
- Fila en `LIMITES_POR_PLAN`: `gratis: { max_sucursales: 1, max_usuarios_staff: 3 }` (borrador).
- `normalizarPlan`: default razonable (si plan desconocido → `gratis`, no `basico`).

`suscripciones_restaurante` (migración nueva): ampliar CHECK de `plan` para aceptar `gratis`.

### Precios propuestos (referencia, COP/mes)

| Plan | Precio | Idea |
|------|--------|------|
| Gratis | $0 | Enganche / volumen / boca a boca |
| Básico | ~$50.000 | Menú+pedidos+caja para quien no necesita cocina/inventario |
| Pro | ~$100.000 | Inventario, costeo, KDS, domicilios, análisis |
| Enterprise | ~$130.000 | + facturación DIAN, multi-sucursal ilimitada |

---

## 6. ¿Gratis permanente o prueba 14 días?

**Recomendado: plan GRATIS permanente muy limitado** (en vez de “todo gratis 14 días y se corta”).

| | Gratis permanente | Prueba 14 días |
|--|-------------------|----------------|
| Restaurante chico (decide lento) | ✅ se queda, se acostumbra | ❌ no alcanza a enamorarse |
| Volumen / boca a boca | ✅ alto | medio |
| Conversión a pago | por **dolor de feature** (no ve márgenes) | por corte abrupto |

Se puede combinar: gratis permanente **+** “14 días Pro de regalo al registrarse” para que pruebe la joya y luego caiga a gratis (sintiendo la falta).

---

## 7. Pasarela de pago — Wompi (Colombia)

### Por qué Wompi

Colombiana (Bancolombia), soporta tarjetas, **PSE**, Nequi. Para LATAM amplio considerar Mercado Pago (suscripciones/preapproval). Empezar con **una** y modo **recurrente**.

### Flujo de cobro automático

```
Admin pulsa «Mejorar a Pro»
   ↓
Backend crea intención de pago / fuente de pago recurrente (API Wompi)
   ↓
Cliente paga (tarjeta/PSE/Nequi) en checkout Wompi
   ↓
Wompi → POST webhook a NUESTRO backend  (evento transaction.updated APPROVED)
   ↓
Backend valida firma del webhook → actualiza suscripciones_restaurante:
   estado='activa', plan='pro', fecha_vencimiento = now()+1 mes
   ↓
PlanFeaturesGuard desbloquea módulos al instante (próximo login/refresh token)
```

### Endpoints nuevos (borrador)

| Método | Ruta | Uso |
|--------|------|-----|
| POST | `/pagos/checkout` | Crea intención/fuente de pago para el restaurante (requiere JWT dueño) |
| POST | `/pagos/webhook-wompi` | **Público**, recibe eventos Wompi; valida firma `events` secret |
| GET | `/pagos/estado` | Estado de suscripción/último pago del restaurante |

### Recurrencia

- Wompi: guardar **fuente de pago** (token de tarjeta) y cobrar cada mes desde un cron, **o** notificar al cliente para re-pagar (más simple, menos riesgo PCI).
- Registrar cada cobro en tabla nueva `pagos_suscripcion` (auditoría).

### Seguridad del webhook (crítico)

- Validar **firma** del evento (secret de integridad Wompi). Nunca confiar en el body sin verificar.
- Idempotencia: un mismo evento no debe activar dos veces.
- El webhook es **público** (sin JWT) → solo se fía de la firma.

---

## 8. Base de datos — cambios necesarios

| Cambio | Tabla | Detalle |
|--------|-------|---------|
| Ampliar CHECK `plan` | `suscripciones_restaurante` | aceptar `gratis` |
| Identidad OAuth | `usuarios` | columnas `proveedor_auth` (`correo`/`google`), `proveedor_id` (sub de Google), `email_verificado` |
| Pagos | **nueva** `pagos_suscripcion` | `id, restaurante_id, monto, plan, metodo, referencia_wompi, estado, creado_at` |
| Fuente de pago recurrente | **nueva** `fuentes_pago` (opcional) | token/`payment_source_id` Wompi por restaurante |
| Origen del registro | `restaurantes` | `origen` (`self_service`/`manual`) para métricas |

> Toda migración nueva va en `foody_supabase/migrations/` con número siguiente, y se documenta aquí + en `AVANCE_PROYECTO.md`.

---

## 9. Vencimiento automático (cron) — YA EXISTE, solo extender

**Ya implementado:** `foody_backend/src/core/suscripciones/suscripciones-cron.service.ts` corre cada hora y hace:
```sql
UPDATE suscripciones_restaurante SET estado='vencida'
WHERE estado IN ('activa','prueba') AND fecha_vencimiento < now()
```

Lo que **falta agregar**:
- **Avisos previos**: notificación/FCM **3 días antes** y el día del vencimiento (hoy el cron no avisa, solo marca).
- **Bloqueo escalonado**: tras `vencida`, conservar datos **30 días** (`dias_datos_restaurante_bloqueado`), luego pasar a `bloqueada`.
- Que el cron **no** afecte super_admin ni domiciliario_independiente (ya solo toca `suscripciones_restaurante`, OK).

---

## 10. Bloquear, no borrar (psicología de retención)

El diseño ya conserva datos 30 días al bloquear — **aprovecharlo**:

- Al vencer: el dueño entra y ve **todo su menú/recetas/historial con candado** + botón “Reactivar”.
- El dolor de “ya tenía todo montado” > empezar de cero → vuelve a pagar.
- Mostrar **un número de valor** al usarlo: “este mes evitaste perder $X gracias al control de margen”. Ese número es lo que no quiere perder.
- Email/push de reactivación con ese dato concreto.

---

## 11. UI / UX (Flutter)

### Pantallas nuevas

| Pantalla | Contenido |
|----------|-----------|
| **Bienvenida / registro** | Botón «Continuar con Google» + «Usar correo»; un solo paso para crear restaurante (nombre, ciudad). |
| **Selección de plan** | Tarjetas Gratis/Básico/Pro/Enterprise con qué incluye cada una; CTA «Empezar gratis». |
| **Mejorar plan (upgrade)** | Comparativa + botón pago Wompi; muestra qué se desbloquea. |
| **Módulo bloqueado (candado)** | En vez de ocultar, mostrar el módulo en gris con candado + «Requiere plan Pro» + preview del beneficio. |
| **Banner vencimiento** | Aviso “Tu prueba termina en X días” / “Plan vencido — reactiva”. |
| **Estado de suscripción** | En ajustes del dueño: plan actual, vencimiento, historial de pagos, cambiar plan. |

### Reglas UI (alineadas a reglas Foody)

- Flutter **solo muestra**; el backend decide plan/estado/desbloqueo.
- El candado y los textos de upgrade son **gancho de venta**, no decoración → mostrar el beneficio concreto (ej. “verías el margen real de cada plato”).
- Colores Foody (`#FF6B35`, `#2EC4B6`, `#FFE66D`), Poppins/Inter.
- Responsive: el registro debe funcionar bien en móvil (es Play Store).

---

## 12. Rentabilidad (referencia rápida)

Con **Wompi por tarjeta** (~2,65% + $700 + IVA 19% sobre comisión):

| Escenario | Bruto/mes | Comisión Wompi | **Neto/mes** (antes de servidor e impuestos) |
|-----------|-----------|----------------|------|
| 10 rest. × $50.000 | $500.000 | ~$24.100 | ~$475.900 |
| 50 rest. × $50.000 | $2.500.000 | ~$120.500 | ~$2.379.500 |
| 100 rest. × $50.000 | $5.000.000 | ~$241.000 | ~$4.759.000 |

Notas:
- Por **PSE** la comisión es casi fija (~$1.500–1.800), más barata en tickets de $50.000 → conviene promover PSE.
- Al neto aún hay que restar: VPS/Supabase (~$100k–300k/mes), Play Store, dominios, e **impuestos de renta**.
- **El churn importa más que el 4,8% de comisión.** Prioridad: que NO se vayan (por eso el valor del análisis debe ser evidente).

---

## 13. Fases de ejecución recomendadas

| Fase | Entregable | Por qué primero |
|------|-----------|-----------------|
| **F1** | **Auto-registro público** (`POST /auth/registro-restaurante`) reutilizando onboarding | Lo que más te quita trabajo manual; ya tienes la transacción |
| **F2** | **Login con Google** (Supabase OAuth → JWT propio) | Baja fricción de entrada |
| **F3** | **Plan `gratis`** en config + BD + matriz módulos + límites | Habilita el modelo freemium |
| **F4** | **Avisos de vencimiento** (3 días antes / día) + bloqueo escalonado a 30 días | El cron de vencer ya existe; falta avisar y bloquear-no-borrar |
| **F5** | **Wompi**: checkout + webhook firmado + `pagos_suscripcion` | El cobro automático |
| **F6** | **UI**: registro, selección plan, upgrade, candados, banner vencimiento | Cierra el ciclo visible |
| **F7** | Métricas self-service (registros, conversión, churn) en Centro de Análisis | Para optimizar el embudo |

---

## 14. Checklist “no fallar”

- [ ] Auto-registro es **atómico** (transacción): si algo falla, no quedan restaurantes a medias.
- [ ] Endpoint público con **rate limit** + verificación email (anti-spam).
- [ ] Webhook Wompi valida **firma** e **idempotencia** (no doble activación).
- [ ] JWT sigue siendo la autoridad de plan/permisos (no romper guards).
- [ ] Plan `gratis` no expone módulos de pago (probar con guard: gratis no puede POST inventario/costeo).
- [ ] Vencimiento **no borra datos**: pasa a bloqueada, conserva 30 días.
- [ ] Cron no bloquea super_admin ni domiciliario_independiente.
- [ ] Pagos registrados en auditoría (`pagos_suscripcion`).
- [ ] Pruebas: registro → uso gratis → upgrade simulado → desbloqueo → vencimiento → reactivación.

---

## 15. Archivos de referencia

| Área | Ruta |
|------|------|
| Onboarding a reutilizar | `foody_backend/src/modulos/super-admin/super-admin.service.ts → crearRestaurante()` |
| Login / JWT | `foody_backend/src/core/auth/auth.service.ts`, `auth.controller.ts` |
| Plan → módulos / límites | `foody_backend/src/core/auth/plan-features.config.ts`, `plan-features.service.ts` |
| Guard suscripción (estado) | `foody_backend/src/core/auth/guards/suscripcion-activa.guard.ts` |
| Guard features por plan | `foody_backend/src/core/auth/guards/plan-features.guard.ts` |
| Esquema suscripciones | `foody_supabase/migrations/011_super_admin.sql` |
| Brecha de planes | `docs/PLANES_SUSCRIPCION.md` |
| Análisis / gancho de pago | `docs/MODULO_ANALITICA_BI.md` |
| UI Foody Control | `lib/features/admin/presentation/panel_foody_control_screen.dart` |

---

## 16. Próximo paso recomendado

Empezar por **F1 (auto-registro público)**: es lo que elimina tu cuello de botella manual y reutiliza la transacción de onboarding que ya está probada. Luego F2 (Google) y F3 (plan gratis) para tener el freemium completo antes de tocar Wompi.
