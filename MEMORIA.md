# MEMORIA DEL PROYECTO — FOODY
## Contexto permanente para agentes de Cursor

> **Copia activa en la raíz del repo.** Fuente editable: `INFRAESTRUCTURA/memoria_foody.md` (sincronizar si actualizas allí).
> Entorno VPS/Supabase: `docs/ENTORNO_LOCAL.md`

> Este archivo se adjunta SIEMPRE al inicio de cualquier sesión con Cursor.
> Contiene las conexiones críticas, variables globales y decisiones irreversibles del sistema.
> Cuando hagas un cambio importante, actualiza la sección correspondiente.

---

## IDENTIDAD DEL PROYECTO

```
Nombre: Foody
Tipo: SaaS POS multi-restaurante
Mercado: LATAM (Colombia primero)
Modelo de negocio: Suscripción mensual por restaurante + comisión domiciliarios
Stack: Flutter + NestJS + Supabase self-hosted + FCM + Python printer server
```

---

## LA COLUMNA VERTEBRAL — sucursal_id

**Esta es la columna más importante de TODO el sistema.**

```
REGLA ABSOLUTA: Casi toda tabla tiene sucursal_id.
Sin sucursal_id en un query, los datos de un restaurante se mezclan con otro.
Nunca omitir sucursal_id en ningún SELECT, INSERT, UPDATE o DELETE.
```

Tablas que tienen sucursal_id obligatorio:
- categorias, productos, toppings, bebidas, combos
- inventario_items, compras_inventario, movimientos_inventario, costos_producto
- cocinas, impresoras, horarios_sucursal
- mesas, pedidos, pedido_items
- cajas, movimientos_caja, cortes_caja, gastos, cuentas_por_cobrar
- domiciliarios_planta, domiciliarios_sesiones
- estados_promociones, alertas_riesgo, auditoria_logs
- configuracion_fiscal_sucursal, facturas
- zonas_cobertura, ofertas_pedido

---

## JERARQUÍA DE DATOS

```
ciudades
  └── restaurantes (un restaurante puede estar en varias ciudades)
        └── sucursales (la unidad operativa real, todo vive aquí)
              ├── usuarios (personal interno)
              ├── cocinas → impresoras
              ├── categorias → productos → producto_ingredientes → inventario_items
              ├── mesas (con qr_token único)
              ├── pedidos → pedido_items → pedido_item_toppings / pedido_item_bebidas
              ├── cajas → movimientos_caja
              └── facturas
```

---

## CONEXIONES CRÍTICAS ENTRE TABLAS

### Cadena del pedido (la más importante)
```
dispositivos_cliente (device_id)
  └── pedidos (device_id FK)
        ├── pedido_items (pedido_id FK)
        │     ├── pedido_item_toppings (pedido_item_id FK)
        │     ├── pedido_item_bebidas (pedido_item_id FK)
        │     └── pedido_combo_selecciones (pedido_item_id FK)
        ├── asignaciones_domicilio (pedido_id FK)
        ├── margenes_historicos (pedido_item_id FK → pedido_items)
        └── facturas (pedido_id FK)
```

### Cadena del inventario (segunda más importante)
```
inventario_items (el ingrediente físico)
  ├── producto_ingredientes (cuánto usa cada producto)
  │     └── productos (el plato del menú)
  ├── movimientos_inventario (toda entrada/salida)
  │     └── pedidos (FK opcional, si es por venta)
  └── compras_inventario (cuando entra mercancía)
        └── costos_producto (se recalcula automáticamente)
```

### Cadena financiera
```
pedidos (total, metodo_pago)
  ├── movimientos_caja (se inserta automáticamente al confirmar pedido con pago)
  │     └── cajas (caja_id FK)
  ├── margenes_historicos (costo_al_momento)
  └── gastos (independientes de pedidos, afectan resultado financiero)
```

### Cadena de cocina → impresión
```
productos (cocina_id FK)
  └── pedido_items (cocina_id FK, copiado del producto)
        └── [backend separa por cocina_id]
              └── cocinas (nombre, sucursal_id)
                    └── impresoras (ip_local, tipo)
                          └── [servidor Python imprime automáticamente]
```

### Cadena QR → mesa → pedido
```
mesas (qr_token único)
  └── [cliente escanea URL /mesa/{qr_token}]
        └── [backend busca mesa por qr_token]
              └── pedidos (mesa_id FK, tipo='mesa', estado='pendiente_aprobacion')
                    └── [mesera aprueba → pedido pasa a 'confirmado']
                          └── transferencias_mesa (si cambia de mesa, auditado)
```

### Cadena de domiciliarios independientes
```
domiciliarios_independientes (estado_cuenta='activo')
  └── domiciliarios_sesiones (activa=true, disponible=true)
        └── [backend calcula distancia a sucursal]
              └── ofertas_pedido (radio_busqueda_km, tiempo_expiracion)
                    ├── respuestas_oferta (cada domiciliario que respondió)
                    └── asignaciones_domicilio (el que aceptó)
                          ├── domiciliarios_ubicaciones_historial (tracking durante entrega)
                          └── ganancias_domiciliario (comisión para domiciliario y Foody)
```

---

## VARIABLES GLOBALES DEL SISTEMA

### Colores Foody
```dart
// lib/core/constantes/colores.dart
colorPrimario = #FF6B35      // naranja vibrante
colorSecundario = #2EC4B6    // turquesa
colorAcento = #FFE66D        // amarillo
colorFondo = #FAFAFA
colorTexto = #1A1A2E
colorError = #E63946
colorExito = #2DC653
```

### URLs base
```dart
// Desarrollo local
urlBackend = 'http://localhost:3000/api/v1'
urlSupabase = 'http://localhost:8000'

// Producción (cambiar al pasar a VPS)
urlBackend = 'https://api.foody.com/api/v1'
urlSupabase = 'https://supabase.foody.com'
```

### Timeouts
```dart
timeoutConexion = 10 segundos
timeoutRespuesta = 30 segundos
actualizacionGPSDomiciliario = 30 segundos
```

### Umbrales de negocio
```
tiempoAprobacionMesera = 3 minutos
tiempoExpiracionOfertaDomicilio = 60 segundos
domiciliariosNotificadosSimultaneo = 5
radioInicialBusquedaKm = 3
ampliacionRadioPorIntento = 2 km
intentosMaximosBusqueda = 3
comisionFoodyDomicilio = 15%
umbralAlertaCuadreCaja = $5.000 COP
umbralAlertaDescuento = 30%
umbralAlertaMargenBajo = 20%
umbralAlertaCostoSube = 15%
umbralCaidasVentas = 40%
diasAlertaMargenBajo = 7 días consecutivos
```

---

## REGLAS QUE NUNCA SE ROMPEN

```
1. Flutter NUNCA calcula totales, precios, descuentos ni IVA.
   → Solo el backend NestJS calcula y valida.

2. Flutter NUNCA escribe directamente a Supabase para operaciones críticas.
   → Toda escritura pasa por el backend (excepto Storage para imágenes).

3. Toda confirmación de pedido es una transacción PostgreSQL atómica.
   → Si un solo paso falla, TODO se revierte (BEGIN/COMMIT/ROLLBACK).

4. El stock se descuenta SIEMPRE al confirmar el pedido, no al entregarlo.
   → En la misma transacción, nunca separado.

5. auditoria_logs es inmutable.
   → Solo INSERT. Nunca UPDATE ni DELETE sobre esta tabla.

6. Las impresoras NUNCA reciben órdenes desde Flutter o desde el navegador.
   → Solo el servidor Python local que está en la red del negocio.

7. Cada query de datos de una sucursal DEBE incluir WHERE sucursal_id = X.
   → Sin excepción. Aunque el usuario sea admin de un solo restaurante.

8. Los precios en pedido_items se copian al momento del pedido.
   → No se referencian del producto original. Si el precio cambia, los pedidos
      históricos mantienen el precio original de cuando se hicieron.

9. Los clientes consumidores NO tienen fila en la tabla usuarios.
   → Están en dispositivos_cliente identificados por device_id.

10. El IVA va incluido en el precio del menú. El cliente ve precio final.
    → El desglose solo aparece en la factura electrónica cuando se solicita.
```

---

## ESTADOS DEL PEDIDO (en orden)

```
pendiente_aprobacion  → Solo pedidos de mesa por QR. Mesera debe aprobar.
pendiente             → Pedido recibido, espera confirmación del restaurante.
confirmado            → Restaurante aceptó. En espera de preparación.
en_cocina             → Al menos un ítem está siendo preparado.
listo                 → Todos los ítems de todas las cocinas están listos.
en_camino             → Solo domicilios. Domiciliario salió.
entregado             → Cliente recibió el pedido.
pagado                → Pago procesado y registrado en caja.
cancelado             → Cancelado. Siempre con motivo registrado.
```

---

## ROLES Y QUÉ VE CADA UNO

> **Multi-sucursal (Alitas House Norte / Sur):** cada sucursal es operación aislada. Spec: `docs/MULTI_SUCURSAL.md`.

```
super_admin           → Todo el sistema (Foody Control)
gerente_cadena        → Todas las sucursales de SU restaurante (corporativo; futuro explícito)
admin / gerente       → SU sucursal asignada (sucursal_id en JWT); ver inventario otras sedes = solo lectura con permiso
cajero                → Caja + pedidos — solo su sucursal
mesero                → Mesas + pedidos — solo su sucursal
cocina_[nombre]       → Tickets de su cocina — solo su sucursal
domiciliario_planta   → Pedidos asignados — solo su sucursal
inventario            → Inventario y compras — solo su sucursal (lectura hermanas con permiso)
```

**No mezclar** menú, stock, pedidos, caja ni staff entre sucursales. Excepción: **consultar** inventario de otra sede del mismo restaurante (sin editar).

---

## APPS FLUTTER (entry points separados)

```
main_cliente.dart      → App pública. Sin login. Ciudad → Restaurante → Menú → Carrito → Pedido
main_admin.dart        → Panel interno. Con login. Admin/Cajero/Mesero (redirige según rol)
main_cocina.dart       → Pantalla cocina. Con login. Solo tickets de su cocina.
main_domiciliario.dart → App domiciliarios independientes. Login propio.
```

---

## FLUJO DE CONFIRMACIÓN DE PEDIDO (18 pasos en una transacción)

```
1.  Validar sucursal activa y en horario
2.  Validar productos: existen y disponible=true
3.  Validar precios: coinciden con BD (Flutter no dicta precios)
4.  Verificar stock de ingredientes por producto_ingredientes
5.  Calcular subtotal, IVA, costo domicilio, descuento, total
6.  INSERT en pedidos
7.  INSERT en pedido_items (con cocina_id copiado del producto)
8.  INSERT en pedido_item_toppings
9.  INSERT en pedido_item_bebidas
10. INSERT en pedido_combo_selecciones (si hay combos)
11. UPDATE inventario_items: descontar stock por ingrediente
12. INSERT en movimientos_inventario tipo='venta' por cada ingrediente
13. CHECK: stock <= stock_minimo → INSERT alerta stock_minimo_alcanzado
14. CHECK: stock = 0 → UPDATE productos SET disponible=false
15. INSERT en margenes_historicos (precio_venta y costo_al_momento)
16. Si tiene metodo_pago → INSERT movimiento_caja automático
17. Si requiere_factura → CREATE borrador en facturas
18. INSERT en auditoria_logs
→ COMMIT (si todo OK) o ROLLBACK (si cualquier paso falla)

POST-TRANSACCIÓN (en paralelo, fuera del COMMIT):
- Supabase Realtime: broadcast al canal de la sucursal
- WebSocket → servidor Python → impresión automática por cocina
- FCM: push a roles de cocina involucrados
- FCM: push a panel domicilios (si es domicilio)
- FCM: push a meseras (si es mesa por QR, para aprobar)
```

---

## FORMATO DE RESPUESTAS DEL BACKEND

```typescript
// Éxito
{
  exito: true,
  datos: { ... },
  mensaje: "Descripción en español"
}

// Error
{
  exito: false,
  error: "CODIGO_ERROR_EN_SCREAMING_SNAKE",
  mensaje: "Descripción legible para el usuario en español"
}
```

### Códigos de error más usados
```
STOCK_INSUFICIENTE         → No hay ingredientes
PRODUCTO_NO_DISPONIBLE     → disponible=false en BD
PRECIO_INVALIDO            → Flutter mandó precio diferente al de BD
RESTAURANTE_CERRADO        → Fuera del horario configurado
MESA_NO_ENCONTRADA         → qr_token inválido
CAJA_NO_ABIERTA            → Operación de caja sin turno activo
CAJA_YA_ABIERTA            → Intento de abrir caja duplicada
SIN_PERMISO                → Rol sin el permiso requerido
TOKEN_EXPIRADO             → JWT expirado
PEDIDO_NO_MODIFICABLE      → Estado no permite el cambio solicitado
DOMICILIARIO_NO_DISPONIBLE → Sin domiciliario en el radio
```

---

## ESTRUCTURA DE CARPETAS (referencia rápida)

```
foody_backend/src/
  core/           → BD, auth, realtime, FCM, impresión
  modulos/        → Un módulo por dominio (pedidos, caja, inventario, etc.)
  compartido/     → Decoradores, filtros, interceptores, utilidades

foody_flutter/lib/
  core/           → Constantes, tema, red (Dio), almacenamiento local
  features/       → Una carpeta por feature con data/domain/presentation
  compartido/     → Widgets reutilizables, modelos compartidos, providers
```

---

## AGENTES DE AGENCY-AGENTS RECOMENDADOS PARA FOODY

Del repositorio msitarzewski/agency-agents, los más útiles para este proyecto:

```
engineering/engineering-backend-architect.md    → Diseño de módulos NestJS, transacciones
engineering/engineering-mobile-app-builder.md   → Pantallas Flutter, Riverpod
engineering/engineering-database-optimizer.md   → Queries PostgreSQL, índices, RLS
engineering/engineering-senior-developer.md     → Patrones avanzados, arquitectura
engineering/engineering-devops-automator.md     → Docker, CI/CD, VPS
testing/testing-api-tester.md                   → Validar endpoints del backend
testing/testing-reality-checker.md              → Antes de marcar algo como terminado
engineering/engineering-security-engineer.md    → RLS Supabase, validaciones
```

---

## LOG DE DECISIONES IMPORTANTES

> Actualizar esta sección cada vez que tomes una decisión que afecte la arquitectura.

| Fecha | Decisión | Razón |
|---|---|---|
| Inicio | Supabase self-hosted en vez de Firebase | Relaciones complejas, transacciones, control total |
| Inicio | Supabase Realtime en vez de Socket.IO | Ya viene incluido, menos infraestructura |
| Inicio | Clientes sin login, solo device_id | Mejor conversión, menos fricción |
| Inicio | IVA incluido en precio visible | Experiencia de usuario más limpia |
| Inicio | Backend calcula TODO lo financiero | Seguridad, evitar manipulación desde cliente |
| Inicio | sucursal_id en casi todas las tablas | Multi-sucursal desde el inicio sin refactorizar |
| Inicio | Servidor Python local para impresión | Los navegadores imprimen mal. Red local necesaria |
| Inicio | Proveedor FE intermediario (Factus/Alegra) | Integración directa DIAN toma meses |

---

## CÓMO USAR ESTE ARCHIVO CON CURSOR

1. Mantén este archivo en la raíz del proyecto como `MEMORIA.md`
2. Al iniciar cualquier sesión de trabajo, adjúntalo con: `@MEMORIA.md`, **`@docs/AVANCE_PROYECTO.md`** (sprints/técnico) y **`@docs/MODULOS_ESTADO.md`** (hecho/falta por módulo; actualizar al terminar cada tarea)
3. Cuando hagas cambios de arquitectura grandes, actualiza el "Log de decisiones"
4. Si agregas tablas nuevas, actualiza la sección "Jerarquía de datos"
5. Si cambias umbrales de negocio, actualiza "Variables globales del sistema"

Los agentes de agency-agents leerán este archivo y tendrán contexto completo
sin necesidad de leer los 6 documentos de especificación cada vez.

---

## ACTUALIZACIÓN v3 — ERP GASTRONÓMICO Y ESTADOS DE PEDIDO

### Nuevo módulo: ERP Gastronómico (Módulo 5)
El sistema ahora es un ERP gastronómico completo. Las tablas clave nuevas son:

```
unidades_medida          → Base de conversiones (gramo, kg, ml, litro, unidad, pieza)
ingredientes             → Lo que se compra físicamente. Tiene tipo_costeo y rendimiento
presentaciones_compra    → Cómo se compra (saco 25kg, caja 30 und) y conversión a unidad base
compras_ingrediente      → Cada compra de mercancía con conversión automática
movimientos_ingrediente  → Trazabilidad completa de todo lo que entra y sale
recetas                  → Define qué ingredientes/subrecetas usa cada producto
receta_items             → Los componentes de cada receta con cantidades y unidades
costos_receta            → Costo calculado de producir cada receta (se recalcula automático)
historial_costos_receta  → Foto del costo en cada momento histórico
producciones             → Lotes preparados (10L salsa BBQ, 5kg apanado)
mermas                   → Desperdicios, daños, vencimientos registrados
conteos_inventario       → Conteos físicos periódicos
conteo_items             → Diferencia entre teórico y real por ingrediente
margenes_venta           → Foto del margen exacto en el momento de cada venta
```

### Tipos de costeo de ingredientes
```
peso        → por gramo/kg (papas, queso, carne molida)
pieza       → por unidad (alitas, panes, huevos)
rendimiento → tiene merma en preparación (pollo con hueso=75%, papa con cáscara=85%)
produccion  → rinde N porciones (aceite, gas, carbón)
```

### Recetas anidadas (subrecetas)
```
Combo → usa Hamburguesa doble → usa Salsa BBQ → usa Ketchup + Miel + Mostaza
                              → usa Carne 180g
                              → usa Pan
                              → usa Empaque
```
`receta_items.tipo_item` puede ser 'ingrediente', 'subreceta' o 'empaque'
`receta_items.subreceta_id` apunta a otra receta (anidamiento sin límite)

### Food Cost
```
Food Cost = (costo_ingredientes / precio_venta) × 100
Objetivo estándar restaurantes: 25-35%
Si supera 40% → alerta food_cost_elevado
```

### Panel de estados con reloj — tabla clave
```
estados_pedido_historial → registra CADA cambio de estado con timestamp
  - estado_anterior
  - estado_nuevo
  - fecha (timestamp exacto del cambio)
  - duracion_estado_anterior_seg (calculado por backend)

El reloj en el panel = NOW() - fecha del último registro de ese pedido
Se resetea a 0 cada vez que entra a un nuevo estado
Supabase Realtime actualiza el panel en tiempo real
```

### Estados del pedido actualizados
```
pendiente_aprobacion → QR mesa, espera aprobación de mesera
pendiente            → Recibido, esperando confirmación
confirmado           → Aceptado, en espera de preparación
en_cocina            → Al menos un ítem preparándose
listo                → Todos los ítems listos en todas las cocinas
asignado             → Domiciliario asignado (solo domicilios)
en_camino            → Domiciliario salió
entregado            → Cliente recibió
pagado               → Pago procesado
cancelado            → Cancelado con motivo
```

### Panel Kanban de pedidos
El panel muestra columnas por estado con:
- Reloj en tiempo real desde que entró al estado (rojo si supera umbral)
- Card por pedido con: número, tipo, cliente/mesa, total
- Botones de cambio de estado desde el panel
- Dropdown de asignación de domiciliario en columna "listo"
- Filtros por tipo de pedido

### Costos operativos fijos (nuevo)
```
costos_operativos_fijos → arriendo, nómina, internet, gas, energía, agua
Se usan para calcular ganancia neta real y punto de equilibrio
Punto de equilibrio = costos_fijos_mes / margen_contribucion_promedio
```

### Reportes nuevos disponibles
```
/reportes/food-cost              → food cost diario/semanal/mensual vs objetivo
/reportes/punto-equilibrio       → cuánto vender para no perder
/reportes/inventario/mermas      → desperdicios por tipo e ingrediente
/reportes/inventario/rotacion    → ingredientes más usados
/reportes/pedidos/estados        → tiempos promedio en cada estado
```

### Fórmulas del sistema
```
Precio sugerido    = costo_produccion / (1 - margen_deseado/100)
Food Cost          = (costo_ingredientes / precio_venta) × 100
Ganancia bruta     = ventas_brutas - costo_ventas
Ganancia neta      = ganancia_bruta - gastos_operativos - costos_fijos
Punto equilibrio   = costos_fijos_mes / margen_contribucion_promedio
Rendimiento        = (cantidad_utilizable / cantidad_comprada) × 100
```

---

## ACTUALIZACIÓN v4 — DASHBOARDS, LOGIN Y PANEL SUPER_ADMIN

### Los tres dashboards (mismo login, redirección por rol)

```
Login único → POST /auth/login
  ↓ backend verifica rol
  ├── super_admin       → PanelFoodyScreen       (URL oculta /foody-control)
  ├── domiciliario_planta → DashboardDomiciliarioScreen
  └── cualquier otro   → PanelRestauranteScreen (pestañas según permisos)
```

### Tablas nuevas del módulo 14

```
suscripciones_restaurante  → estado de pago y bloqueo por restaurante
                             estados: 'prueba', 'activa', 'vencida', 'bloqueada'
                             Si bloqueada → backend rechaza todos los requests

configuracion_global_foody → parámetros del sistema editables sin código
                             clave/valor. El backend los lee en cada operación.
                             Ejemplo: 'comision_domiciliario_porcentaje' = '15'
```

### Regla de redirección Flutter
```dart
switch (respuesta.dashboard) {
  case 'foody_control':   → PanelFoodyScreen()         // super_admin
  case 'domiciliario':    → DashboardDomiciliarioScreen() // domiciliario_planta
  default:                → PanelRestauranteScreen()    // todos los demás roles
}
```

### Panel Foody (super_admin) — qué controla
```
Ciudades          → crear, editar, activar/desactivar
Restaurantes      → crear, editar, bloquear/desbloquear
Suscripciones     → estado de pago, cambiar plan, bloquear por mora
Usuarios globales → todos los usuarios de todos los restaurantes
                    crear, editar, cambiar contraseña, habilitar/inhabilitar
Roles             → crear roles personalizados por restaurante
Domiciliarios     → aprobar documentos, suspender cuentas independientes
Estadísticas      → métricas globales de la plataforma
Configuración     → editar configuracion_global_foody sin código
```

### Panel restaurante — menú dinámico por rol
Flutter construye las pestañas SOLO con las que el rol tiene permiso.
Si no tiene permiso → la pestaña no existe, no está deshabilitada.

```
admin     → todo: dashboard, pedidos, menú, inventario, mesas, cocinas,
            caja, domiciliarios, reportes, alertas, usuarios, sucursales, config
gerente   → igual que admin pero sin: usuarios, sucursales, eliminar registros
cajero    → pedidos (filtrado), caja, encargos
mesero    → mesas, pedidos activos de sus mesas
cocina_X  → solo tickets de su cocina específica (sin precios ni totales)
```

### Dashboard domiciliario — secciones
```
Pedidos pendientes → domicilios asignados a él
                     confirmar entrega → cambia estado a entregado
                     confirmar método de pago si es efectivo
Historial          → entregas del día
Estadísticas       → contadores personales
Configuración      → perfil y contraseña
```

### Parámetros globales editables (configuracion_global_foody)
```
comision_domiciliario_porcentaje = 15
tiempo_expiracion_oferta_seg     = 60
radio_inicial_busqueda_km        = 3
ampliacion_radio_km              = 2
intentos_max_busqueda            = 3
umbral_alerta_descuento_pct      = 30
umbral_alerta_cuadre_caja        = 5000
umbral_alerta_costo_sube_pct     = 15
umbral_alerta_margen_bajo_pct    = 20
dias_datos_restaurante_bloqueado = 30
tiempo_aprobacion_mesera_min     = 3
umbral_reloj_pedido_rojo_min     = 15
```

---

## GUARDS DE SEGURIDAD — ORDEN DE VERIFICACIÓN EN CADA REQUEST

```
Todo request al backend pasa por estos guards en orden:

1. JwtAuthGuard          → token válido y no expirado
2. UsuarioActivoGuard    → usuario.activo = true
3. SuscripcionActivaGuard → suscripcion.estado IN ('activa', 'prueba')
                            EXCEPTO endpoints /super/* y /auth/*
4. RolGuard              → el rol tiene el permiso requerido
5. SuperAdminGuard       → SOLO para endpoints /super/*

Si cualquier guard falla → para ahí, devuelve error, no continúa.
```

## JERARQUÍA DE CONTROL ACTUALIZADA

```
super_admin (Foody — el programador)
  ↓ controla
restaurantes (el negocio)
  ↓ tiene
sucursales (las sedes físicas)
  ↓ tienen
usuarios internos (admin, cajero, mesero, cocina, domiciliario_planta)
  ↓ atienden
clientes (sin login, solo device_id)
```

## MÓDULO 14 — TABLAS NUEVAS
```
suscripciones_restaurante  → 2 campos clave: estado y fecha_vencimiento
configuracion_global_foody → clave/valor, el backend los carga al arrancar
                             y los cachea en memoria para no leer BD en cada request
```
