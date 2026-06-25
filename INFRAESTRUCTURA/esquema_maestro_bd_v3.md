# Esquema maestro de base de datos v3.0
## Sistema POS SaaS para restaurantes — Foody
## Documento unificado completo con ERP gastronómico + costeo industrial + estados de pedido

> 13 módulos, 68 tablas. Todo lo acordado sin omitir nada.

---

## Consideraciones globales

- Todas las tablas usan `uuid` como PK generado por `gen_random_uuid()`.
- Todas tienen `created_at timestamptz default now()` salvo excepciones.
- `sucursal_id` es la columna más crítica. Sin ella los datos de sucursales se mezclan.
- Los clientes consumidores NO tienen login. Se identifican por `device_id`.
- Solo el personal interno tiene login via Supabase Auth.
- El backend Node.js ejecuta TODA la lógica crítica. Flutter solo envía intenciones.
- Toda confirmación de pedido ocurre en una única transacción PostgreSQL atómica.
- La app de domiciliarios independientes tiene su propio login pero comparte la BD.
- El servidor Python corre en un PC fijo del negocio e imprime automáticamente.
- IVA incluido en precios del menú. El cliente ve precio final.

---

## Módulo 1 — Geografía y acceso

### `ciudades`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| nombre | text NOT NULL | "Bogotá", "Medellín", "Valledupar" |
| slug | text UNIQUE NOT NULL | "bogota", "medellin" |
| activa | bool DEFAULT true | Visible en la app cliente |
| created_at | timestamptz | Fecha de creación |

### `restaurantes`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| ciudad_id | uuid FK → ciudades | Ciudad principal |
| nombre | text NOT NULL | Nombre del restaurante |
| descripcion | text | Descripción breve |
| logo_url | text | Supabase Storage |
| banner_url | text | Imagen de portada |
| telefono | text | Contacto |
| activo | bool DEFAULT true | Visible en la app |
| created_at | timestamptz | Fecha de creación |

### `sucursales`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| restaurante_id | uuid FK → restaurantes | A qué restaurante pertenece |
| ciudad_id | uuid FK → ciudades | Ciudad de esta sede |
| nombre | text NOT NULL | "Sede Norte", "Centro" |
| direccion | text | Dirección física |
| telefono | text | Teléfono de la sede |
| lat | numeric(10,7) | Latitud para distancias |
| lng | numeric(10,7) | Longitud para distancias |
| activa | bool DEFAULT true | Si opera actualmente |
| created_at | timestamptz | Fecha de creación |

### `zonas_cobertura`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text | "Zona norte", "Centro" |
| costo_domicilio | numeric(12,2) NOT NULL | Costo del domicilio en esta zona |
| distancia_max_km | numeric NOT NULL | Distancia máxima |
| poligono | jsonb | Coordenadas del polígono (opcional) |
| activa | bool DEFAULT true | Si está operativa |
| created_at | timestamptz | Fecha de creación |

---

## Módulo 2 — Usuarios, roles y permisos

### `usuarios`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Mismo UUID de Supabase Auth |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | Nombre completo |
| email | text UNIQUE NOT NULL | Email de login |
| telefono | text | Teléfono del empleado |
| rol | text NOT NULL | Ver roles abajo |
| activo | bool DEFAULT true | Si puede ingresar |
| created_at | timestamptz | Fecha de creación |

**Roles:** `super_admin`, `admin`, `gerente`, `cajero`, `mesero`, `cocina_[nombre]`, `domiciliario_planta`, `inventario`

### `roles_permisos`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| rol | text NOT NULL | Nombre del rol |
| permiso | text NOT NULL | Acción permitida |

---

## Módulo 3 — Dispositivos y notificaciones

### `dispositivos_cliente`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador interno |
| device_id | text UNIQUE NOT NULL | UUID generado por Flutter, guardado en SharedPreferences |
| fcm_token | text | Token Firebase push |
| ciudad_id | uuid FK → ciudades | Última ciudad seleccionada |
| nombre_opcional | text | Si alguna vez lo escribió |
| telefono_opcional | text | Si alguna vez lo dio |
| plataforma | text | 'android', 'ios', 'web' |
| ultimo_acceso | timestamptz | Para análisis de retención |
| created_at | timestamptz | Primera vez que usó la app |

### `tokens_push_admin`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| usuario_id | uuid FK → usuarios | A quién pertenece |
| fcm_token | text NOT NULL | Token FCM |
| plataforma | text | 'android', 'ios', 'web' |
| activo | bool DEFAULT true | Si sigue vigente |
| updated_at | timestamptz | Última actualización |

---

## Módulo 4 — Catálogo y menú

### `categorias`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | "Salchipapas", "Asados" |
| imagen_url | text | Imagen de la categoría |
| orden | int DEFAULT 0 | Posición en el menú |
| activa | bool DEFAULT true | Visible en el menú |
| created_at | timestamptz | Fecha de creación |

### `productos`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| categoria_id | uuid FK → categorias | Categoría del producto |
| cocina_id | uuid FK → cocinas | A qué cocina se manda |
| receta_id | uuid FK → recetas, null | Receta base del producto |
| nombre | text NOT NULL | Nombre del plato |
| descripcion | text | Descripción visible al cliente |
| precio | numeric(12,2) NOT NULL | Precio de venta al público |
| precio_sugerido | numeric(12,2) | Calculado por sistema según margen deseado |
| costo_calculado | numeric(12,2) | Costo real de producción (de costos_receta) |
| imagen_url | text | Foto del producto |
| disponible | bool DEFAULT true | Si se puede pedir ahora |
| es_encargo | bool DEFAULT false | Si pertenece a sección encargos |
| orden | int DEFAULT 0 | Posición en la categoría |
| created_at | timestamptz | Fecha de creación |

### `toppings`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | "Queso extra", "Bacon" |
| precio | numeric(12,2) DEFAULT 0 | Costo adicional |
| disponible | bool DEFAULT true | Si se puede seleccionar |
| created_at | timestamptz | Fecha de creación |

### `bebidas`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | "Gaseosa 400ml", "Jugo de lulo" |
| precio | numeric(12,2) NOT NULL | Precio de venta |
| disponible | bool DEFAULT true | Si se puede pedir |
| created_at | timestamptz | Fecha de creación |

### `combos`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | "Combo familiar pizza" |
| descripcion | text | Qué incluye |
| precio_fijo | numeric(12,2) NOT NULL | Precio total |
| imagen_url | text | Foto del combo |
| disponible | bool DEFAULT true | Si se puede pedir |
| created_at | timestamptz | Fecha de creación |

### `combo_items`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| combo_id | uuid FK → combos | A qué combo pertenece |
| tipo_item | text NOT NULL | 'producto', 'bebida', 'topping' |
| item_id | uuid NOT NULL | ID del producto/bebida/topping |
| cantidad | int DEFAULT 1 | Cuántas unidades incluye |
| es_opcional | bool DEFAULT false | Si el cliente elige entre opciones |
| grupo_opcion | text | Agrupa opciones del mismo slot |

### `estados_promociones`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | Quién publica |
| usuario_id | uuid FK → usuarios | Qué usuario lo publicó |
| imagen_url | text NOT NULL | Imagen en Supabase Storage |
| texto | text | Texto superpuesto opcional |
| producto_id | uuid FK → productos, null | Si enlaza a un producto |
| fecha_inicio | timestamptz NOT NULL | Cuándo empieza |
| fecha_fin | timestamptz NOT NULL | Cuándo expira |
| activo | bool DEFAULT true | Si está visible |
| vistas | int DEFAULT 0 | Contador de vistas |
| created_at | timestamptz | Fecha de creación |

---

## Módulo 5 — ERP Gastronómico: Unidades, ingredientes y costeo industrial

Este es el núcleo del sistema de costeo profesional. Soporta unidades mixtas,
rendimientos, conversiones, subrecetas anidadas, mermas y food cost real.

### `unidades_medida`
Define todas las unidades del sistema con sus conversiones base.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| nombre | text NOT NULL | "gramo", "kilogramo", "mililitro", "unidad", "pieza" |
| simbolo | text NOT NULL | "g", "kg", "ml", "l", "und", "pza" |
| tipo | text NOT NULL | 'peso', 'volumen', 'unidad', 'porcion' |
| unidad_base_id | uuid FK → unidades_medida, null | A qué unidad base se convierte |
| factor_conversion | numeric(18,8) | Cuántas unidades base equivale (1 kg = 1000 g) |

**Ejemplos de conversiones:**
- gramo → es la unidad base de peso (factor 1)
- kilogramo → unidad_base = gramo, factor = 1000
- mililitro → es la unidad base de volumen (factor 1)
- litro → unidad_base = mililitro, factor = 1000
- unidad → es su propia base

---

### `ingredientes`
Los ingredientes reales que se compran. No los platos del menú.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | "Papa", "Pechuga de pollo", "Salsa BBQ" |
| unidad_base_id | uuid FK → unidades_medida | Unidad base de este ingrediente (gramo, ml, unidad) |
| tipo_costeo | text NOT NULL | 'peso', 'pieza', 'rendimiento', 'produccion' |
| rendimiento_porcentaje | numeric(5,2) DEFAULT 100 | % utilizable (pollo con hueso = 75%) |
| stock_actual | numeric(18,3) DEFAULT 0 | Cantidad en unidad base disponible ahora |
| stock_minimo | numeric(18,3) DEFAULT 0 | Alerta cuando baje de aquí |
| stock_teorico | numeric(18,3) DEFAULT 0 | Lo que debería haber según el sistema |
| costo_unitario_actual | numeric(12,4) | Costo por unidad base con última compra |
| costo_promedio | numeric(12,4) | Promedio ponderado de costos históricos |
| metodo_costeo | text DEFAULT 'promedio' | 'fifo', 'promedio', 'ultimo_costo' |
| es_subreceta | bool DEFAULT false | Si es una preparación interna (salsa BBQ, apanado) |
| created_at | timestamptz | Fecha de creación |

**Tipos de costeo:**
- `peso` → se costea por gramo/kg (papas, queso, carne)
- `pieza` → se costea por unidad (alitas, panes, huevos)
- `rendimiento` → tiene merma en preparación (pollo con hueso, papa con cáscara)
- `produccion` → rinde N porciones (aceite, gas, carbón)

---

### `presentaciones_compra`
Cómo se compra realmente el ingrediente (saco, caja, litro) y la conversión a la unidad base.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| ingrediente_id | uuid FK → ingredientes | A qué ingrediente pertenece |
| nombre | text NOT NULL | "Saco 25kg", "Caja 30 unidades", "Garrafa 5L" |
| unidad_compra_id | uuid FK → unidades_medida | Unidad en que se compra |
| cantidad_en_unidad_base | numeric(18,3) NOT NULL | Cuántas unidades base contiene (25kg = 25000g) |
| es_presentacion_defecto | bool DEFAULT false | La que se usa por defecto al registrar compras |

---

### `compras_ingrediente`
Cada vez que entra mercancía. Registra precio real y actualiza stock y costo.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| ingrediente_id | uuid FK → ingredientes | Qué ingrediente se compró |
| presentacion_id | uuid FK → presentaciones_compra | En qué presentación se compró |
| proveedor | text | Nombre del proveedor |
| cantidad_presentaciones | numeric(10,3) NOT NULL | Cuántas presentaciones (2.5 sacos) |
| cantidad_unidad_base | numeric(18,3) NOT NULL | Total en unidad base (calculado) |
| costo_total | numeric(12,2) NOT NULL | Cuánto costó todo |
| costo_unidad_base | numeric(12,4) NOT NULL | Costo por unidad base (calculado) |
| comprobante_url | text | Foto de la factura del proveedor |
| registrado_por | uuid FK → usuarios | Quién registró |
| fecha | timestamptz NOT NULL | Cuándo se compró |
| created_at | timestamptz | Cuándo se registró |

**Efectos automáticos al registrar una compra:**
1. Suma `cantidad_unidad_base` al `stock_actual` del ingrediente
2. Recalcula `costo_unitario_actual` y `costo_promedio` según método de costeo
3. Inserta en `movimientos_ingrediente` tipo 'entrada'
4. Recalcula `costos_receta` de todas las recetas que usen este ingrediente
5. Si el costo subió más del 15%, genera alerta financiera

---

### `movimientos_ingrediente`
Trazabilidad completa de todo lo que entra y sale de cada ingrediente. Inmutable.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| ingrediente_id | uuid FK → ingredientes | Qué ingrediente se movió |
| pedido_id | uuid FK → pedidos, null | Si vino de una venta |
| compra_id | uuid FK → compras_ingrediente, null | Si vino de una compra |
| produccion_id | uuid FK → producciones, null | Si vino de una producción |
| usuario_id | uuid FK → usuarios, null | Quién lo hizo (null si automático) |
| tipo | text NOT NULL | 'entrada', 'venta', 'produccion_consumo', 'produccion_resultado', 'ajuste', 'merma', 'desperdicio', 'retiro' |
| cantidad | numeric(18,3) NOT NULL | En unidad base. Positivo=entrada, Negativo=salida |
| costo_unitario | numeric(12,4) | Costo en ese momento |
| costo_total | numeric(12,2) | cantidad × costo_unitario |
| stock_resultante | numeric(18,3) NOT NULL | Stock después del movimiento |
| motivo | text | Descripción del movimiento |
| fecha | timestamptz DEFAULT now() | Cuándo ocurrió |

---

### `recetas`
El corazón del costeo. Una receta define qué ingredientes y subrecetas usa un producto y en qué cantidad.
Soporta recetas anidadas: un producto puede usar subrecetas que a su vez usan ingredientes.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | "Salchipapa salvaje", "Salsa BBQ", "Apanado especial" |
| descripcion | text | Descripción de la receta |
| tipo | text NOT NULL | 'producto', 'subreceta', 'empaque' |
| unidad_resultado | uuid FK → unidades_medida | En qué unidad produce (porciones, gramos, litros) |
| cantidad_resultado | numeric(18,3) NOT NULL | Cuánto produce esta receta (ej: produce 650g) |
| porciones | int DEFAULT 1 | En cuántas porciones se divide el resultado |
| costo_total_calculado | numeric(12,2) | Suma de todos los ítems (se recalcula) |
| costo_por_porcion | numeric(12,2) | costo_total / porciones |
| recalculado_at | timestamptz | Última vez que se recalculó |
| created_at | timestamptz | Fecha de creación |

---

### `receta_items`
Los componentes de cada receta: ingredientes o subrecetas.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| receta_id | uuid FK → recetas | A qué receta pertenece |
| tipo_item | text NOT NULL | 'ingrediente', 'subreceta', 'empaque' |
| ingrediente_id | uuid FK → ingredientes, null | Si es ingrediente |
| subreceta_id | uuid FK → recetas, null | Si es subreceta (receta dentro de receta) |
| cantidad | numeric(18,3) NOT NULL | Cuánto se usa en la unidad del ingrediente/subreceta |
| unidad_id | uuid FK → unidades_medida | En qué unidad se mide esta cantidad |
| incluye_merma | bool DEFAULT false | Si ya considera merma de preparación |
| porcentaje_merma | numeric(5,2) DEFAULT 0 | % extra que se pierde en preparación |
| costo_calculado | numeric(12,2) | Costo de este ítem (calculado automáticamente) |

**Ejemplo real — Salchipapa salvaje (3 personas):**
- Papa: 600g (ingrediente, tipo_costeo=rendimiento, rendimiento=85%)
- Salchicha: 3 unidades (ingrediente, tipo_costeo=pieza)
- Aceite: 50ml (ingrediente, tipo_costeo=produccion, rinde 20 combos)
- Lechuga: 80g (ingrediente, tipo_costeo=peso)
- Salsa BBQ: 1 porción (subreceta — apunta a receta "Salsa BBQ")
- Empaque: 1 unidad (ingrediente, tipo_costeo=pieza)

**Ejemplo real — Salsa BBQ (subreceta, produce 100 porciones):**
- Ketchup: 500ml
- Miel: 100ml
- Mostaza: 50ml
- Costo total: $8.000 → costo por porción: $80

---

### `costos_receta`
Costo calculado de cada receta. Se recalcula automáticamente cuando cambia cualquier ingrediente.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| receta_id | uuid FK → recetas | La receta calculada |
| sucursal_id | uuid FK → sucursales | A qué sede |
| costo_ingredientes | numeric(12,2) | Suma de costos de ingredientes directos |
| costo_subrecetas | numeric(12,2) | Suma de costos de subrecetas usadas |
| costo_empaques | numeric(12,2) | Costo de empaques |
| costo_merma | numeric(12,2) | Costo estimado de merma |
| costo_total | numeric(12,2) | Suma de todo |
| costo_por_porcion | numeric(12,2) | costo_total / porciones |
| margen_con_precio_actual | numeric(5,2) | Si el producto tiene precio de venta |
| food_cost_porcentaje | numeric(5,2) | (costo / precio_venta) × 100 |
| recalculado_at | timestamptz | Última vez que se actualizó |

---

### `historial_costos_receta`
Fotografía del costo en cada momento. Permite ver cómo han cambiado los costos con el tiempo.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| receta_id | uuid FK → recetas | La receta |
| sucursal_id | uuid FK → sucursales | A qué sede |
| costo_por_porcion | numeric(12,2) NOT NULL | Costo en ese momento |
| motivo_cambio | text | Por qué cambió (subió el pollo, etc.) |
| registrado_at | timestamptz DEFAULT now() | Cuándo se tomó la foto |

---

### `producciones`
Cuando el equipo prepara lotes de subrecetas o ingredientes procesados.
Ejemplo: hoy se prepararon 10 litros de salsa BBQ o 5kg de apanado.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| receta_id | uuid FK → recetas | Qué receta/subreceta se produjo |
| cantidad_producida | numeric(18,3) NOT NULL | Cuánto se produjo en unidad resultado |
| costo_real_produccion | numeric(12,2) | Costo real de esta producción |
| registrado_por | uuid FK → usuarios | Quién lo registró |
| observaciones | text | Notas del proceso |
| fecha | timestamptz NOT NULL | Cuándo se produjo |
| created_at | timestamptz | Cuándo se registró |

**Efecto automático:** descuenta los ingredientes usados del stock y suma el resultado a stock del ingrediente destino si aplica.

---

### `mermas`
Registro de desperdicios, daños y pérdidas. Diferencia entre inventario teórico y real.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| ingrediente_id | uuid FK → ingredientes | Qué se perdió |
| tipo_merma | text NOT NULL | 'preparacion', 'coccion', 'daño', 'vencimiento', 'humano', 'fritura' |
| cantidad | numeric(18,3) NOT NULL | Cuánto se perdió en unidad base |
| costo_estimado | numeric(12,2) | Costo de lo perdido |
| registrado_por | uuid FK → usuarios | Quién lo registró |
| descripcion | text | Qué pasó exactamente |
| fecha | timestamptz NOT NULL | Cuándo ocurrió |
| created_at | timestamptz | Cuándo se registró |

---

### `conteos_inventario`
Conteos físicos periódicos para detectar diferencias entre teórico y real.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| realizado_por | uuid FK → usuarios | Quién hizo el conteo |
| estado | text DEFAULT 'en_proceso' | 'en_proceso', 'completado', 'aprobado' |
| observaciones | text | Notas generales |
| fecha_inicio | timestamptz NOT NULL | Cuándo empezó el conteo |
| fecha_fin | timestamptz | Cuándo terminó |

### `conteo_items`
Cada ingrediente dentro de un conteo físico.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| conteo_id | uuid FK → conteos_inventario | A qué conteo pertenece |
| ingrediente_id | uuid FK → ingredientes | Qué ingrediente se contó |
| cantidad_teorica | numeric(18,3) NOT NULL | Lo que el sistema dice que debería haber |
| cantidad_real | numeric(18,3) NOT NULL | Lo que se contó físicamente |
| diferencia | numeric(18,3) | cantidad_real - cantidad_teorica |
| costo_diferencia | numeric(12,2) | diferencia × costo_unitario_actual |
| tipo_diferencia | text | 'faltante', 'sobrante', 'exacto' |

---

### `margenes_venta`
Fotografía del margen en el momento exacto de cada venta. Los precios cambian, esto preserva la historia.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_item_id | uuid FK → pedido_items | El ítem vendido |
| producto_id | uuid FK → productos | El producto |
| sucursal_id | uuid FK → sucursales | La sede |
| precio_venta | numeric(12,2) NOT NULL | A cuánto se vendió |
| costo_al_momento | numeric(12,2) NOT NULL | Cuánto costaba producirlo |
| food_cost_porcentaje | numeric(5,2) | (costo / precio_venta) × 100 |
| margen_bruto | numeric(12,2) NOT NULL | precio_venta - costo_al_momento |
| margen_porcentaje | numeric(5,2) NOT NULL | Margen porcentual |
| fecha | timestamptz NOT NULL | Cuándo ocurrió la venta |

---

## Módulo 6 — Cocinas e impresión

### `cocinas`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| nombre | text NOT NULL | "Cocina asados", "Cocina bebidas" |
| activa | bool DEFAULT true | Si está operativa |
| created_at | timestamptz | Fecha de creación |

### `impresoras`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| cocina_id | uuid FK → cocinas | A qué cocina pertenece |
| nombre | text NOT NULL | "Impresora asados" |
| ip_local | text | IP en la red local del negocio |
| tipo | text NOT NULL | 'termica_red', 'termica_usb', 'pdf' |
| activa | bool DEFAULT true | Si está disponible |
| created_at | timestamptz | Fecha de creación |

### `horarios_sucursal`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede aplica |
| dia_semana | int NOT NULL | 0=domingo … 6=sábado |
| hora_apertura | time NOT NULL | Hora de inicio |
| hora_cierre | time NOT NULL | Hora de cierre |
| cerrado | bool DEFAULT false | Si ese día no opera |

---

## Módulo 7 — Mesas y QR

### `mesas`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| numero | int NOT NULL | Número físico |
| nombre | text | "Terraza 1", "Salón VIP" |
| capacidad | int | Cuántas personas |
| qr_token | text UNIQUE NOT NULL | Token único para el QR |
| estado | text DEFAULT 'libre' | 'libre', 'ocupada', 'esperando_comida', 'pagando', 'reservada' |
| ocupada_desde | timestamptz | Para calcular tiempo en mesa |
| created_at | timestamptz | Fecha de creación |

### `transferencias_mesa`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_id | uuid FK → pedidos | Qué pedido se movió |
| mesa_origen_id | uuid FK → mesas | De dónde venía |
| mesa_destino_id | uuid FK → mesas | A dónde fue |
| usuario_id | uuid FK → usuarios | Quién hizo la transferencia |
| motivo | text | Por qué se transfirió |
| fecha | timestamptz DEFAULT now() | Cuándo ocurrió |

---

## Módulo 8 — Pedidos y panel de estados

### `pedidos`
La tabla central del sistema.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | En qué sede |
| mesa_id | uuid FK → mesas, null | Si es pedido de mesa |
| device_id | text FK → dispositivos_cliente, null | Dispositivo del cliente |
| creado_por_usuario_id | uuid FK → usuarios, null | Si lo creó mesero o cajero |
| aprobado_por | uuid FK → usuarios, null | Mesera que aceptó el pedido de QR |
| tipo | text NOT NULL | 'mesa', 'domicilio', 'para_llevar', 'encargo' |
| estado | text NOT NULL | Ver estados completos abajo |
| cliente_nombre | text | Nombre para el pedido |
| cliente_telefono | text | Obligatorio en domicilios |
| direccion_entrega | text | Solo para domicilios |
| lat | numeric(10,7) | Latitud del cliente |
| lng | numeric(10,7) | Longitud del cliente |
| subtotal | numeric(12,2) NOT NULL | Calculado por backend |
| iva_porcentaje | numeric(5,2) DEFAULT 0 | % IVA aplicado |
| iva_valor | numeric(12,2) DEFAULT 0 | Valor del IVA |
| costo_domicilio | numeric(12,2) DEFAULT 0 | Solo domicilios |
| descuento | numeric(12,2) DEFAULT 0 | Descuento aplicado |
| descuento_motivo | text | Por qué se aplicó |
| total | numeric(12,2) NOT NULL | Total final |
| metodo_pago | text | 'efectivo', 'tarjeta', 'transferencia', 'nequi' |
| requiere_factura | bool DEFAULT false | Si pidió factura |
| factura_id | uuid FK → facturas, null | Factura emitida |
| caja_id | uuid FK → cajas, null | A qué caja se registró |
| observaciones | text | Nota general |
| numero_pedido | text | Número legible "FDY-001" para mostrar |
| created_at | timestamptz | Cuándo se hizo |
| updated_at | timestamptz | Última actualización |

**Estados completos en orden cronológico:**
- `pendiente_aprobacion` → pedido de mesa por QR esperando que mesera acepte
- `pendiente` → recibido, esperando confirmación del restaurante
- `confirmado` → aceptado, en espera de preparación
- `en_cocina` → al menos un ítem siendo preparado
- `listo` → todos los ítems de todas las cocinas listos
- `asignado` → domiciliario asignado (solo domicilios)
- `en_camino` → domiciliario salió con el pedido
- `entregado` → cliente recibió
- `pagado` → pago procesado en caja
- `cancelado` → cancelado con motivo

---

### `estados_pedido_historial`
**TABLA CLAVE para el panel de estados con reloj.**
Registra cada cambio de estado con timestamps exactos para calcular duración en cada etapa.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_id | uuid FK → pedidos | A qué pedido pertenece |
| estado_anterior | text | Estado del que venía (null si es el primero) |
| estado_nuevo | text NOT NULL | Estado al que pasó |
| usuario_id | uuid FK → usuarios, null | Quién hizo el cambio (null si automático) |
| duracion_estado_anterior_seg | int | Cuántos segundos estuvo en el estado anterior |
| fecha | timestamptz DEFAULT now() | Cuándo ocurrió el cambio |

**Cómo funciona el reloj:**
- Cuando un pedido cambia de estado, el backend inserta aquí el nuevo estado con timestamp
- Para calcular el tiempo en el estado actual: `NOW() - fecha` del último registro
- Para calcular el tiempo total en cada etapa: `duracion_estado_anterior_seg` ya lo tiene calculado
- El panel de estados muestra este reloj en tiempo real usando Supabase Realtime
- El reloj se resetea a cero cada vez que el pedido entra a un nuevo estado

---

### `pedido_items`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_id | uuid FK → pedidos | Al pedido que pertenece |
| producto_id | uuid FK → productos | Qué producto es |
| cocina_id | uuid FK → cocinas | A qué cocina va |
| cantidad | int NOT NULL | Cuántas unidades |
| precio_unitario | numeric(12,2) NOT NULL | Precio al momento del pedido |
| costo_unitario | numeric(12,2) | Costo de producción al momento |
| observaciones | text | "Sin cebolla", "Bien cocido" |
| estado_cocina | text DEFAULT 'pendiente' | 'pendiente', 'preparando', 'listo' |
| created_at | timestamptz | Fecha de creación |

### `pedido_item_toppings`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_item_id | uuid FK → pedido_items | Al ítem que pertenece |
| topping_id | uuid FK → toppings | Qué topping |
| precio | numeric(12,2) NOT NULL | Precio al momento |

### `pedido_item_bebidas`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_item_id | uuid FK → pedido_items | Al ítem que pertenece |
| bebida_id | uuid FK → bebidas | Qué bebida |
| precio | numeric(12,2) NOT NULL | Precio al momento |
| cantidad | int DEFAULT 1 | Cuántas |

### `pedido_combo_selecciones`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_item_id | uuid FK → pedido_items | El ítem de tipo combo |
| combo_item_id | uuid FK → combo_items | El slot del combo |
| tipo_seleccion | text NOT NULL | 'producto', 'bebida', 'topping' |
| item_id | uuid NOT NULL | El ítem elegido por el cliente |

---

## Panel de estados de pedidos — cómo funciona

El panel tiene columnas tipo Kanban, una por estado activo:

```
[ PENDIENTE ]  [ EN COCINA ]  [ LISTO ]  [ ASIGNADO ]  [ EN CAMINO ]  [ ENTREGADO ]
   🕐 2:34        🕐 8:12       🕐 1:05     🕐 4:30        🕐 12:40       🕐 0:45
  Pedido #001   Pedido #003   Pedido #005  Pedido #002   Pedido #004   Pedido #006
  Mesa 3        Domicilio     Para llevar  Carlos P.     Juan R.       María L.
  $34.000       $28.500       $15.000      $42.000       $31.000       $22.000
```

**Funciones del panel:**
- Reloj en tiempo real por pedido desde que entró al estado actual (usando `estados_pedido_historial`)
- Botón de cambio de estado manual desde el panel (confirmar, mover a cocina, marcar listo)
- Asignación de domiciliario directamente desde la columna "LISTO" para pedidos de domicilio
- Dropdown con domiciliarios de planta disponibles en ese momento
- Alerta visual (color rojo parpadeante) cuando un pedido lleva más de N minutos en un estado
- Filtro por tipo de pedido (mesa / domicilio / para llevar / encargo)
- Click en cualquier pedido abre el detalle completo

---

## Módulo 9 — Domiciliarios

### `domiciliarios_planta`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| usuario_id | uuid FK → usuarios | Su cuenta de usuario |
| sucursal_id | uuid FK → sucursales | A qué sede pertenece |
| disponible | bool DEFAULT true | Si puede recibir pedidos ahora |
| created_at | timestamptz | Fecha de creación |

### `domiciliarios_independientes`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| auth_id | uuid | UUID de Supabase Auth propio |
| nombre | text NOT NULL | Nombre completo |
| telefono | text NOT NULL | Teléfono |
| email | text NOT NULL | Email de login |
| foto_url | text | Foto de perfil |
| documento_tipo | text | 'cc', 'ce', 'pasaporte' |
| documento_numero | text NOT NULL | Número del documento |
| fecha_nacimiento | date | Para verificación |
| ciudad_id | uuid FK → ciudades | Ciudad donde opera |
| radio_operacion_km | numeric DEFAULT 5 | Distancia máxima que acepta |
| vehiculo_tipo | text | 'moto', 'bicicleta', 'pie', 'carro' |
| vehiculo_placa | text | Placa si aplica |
| estado_cuenta | text DEFAULT 'pendiente' | 'pendiente', 'activo', 'suspendido', 'bloqueado' |
| motivo_suspension | text | Razón si está suspendido |
| calificacion_promedio | numeric(3,2) DEFAULT 5.0 | Promedio de calificaciones |
| total_entregas | int DEFAULT 0 | Contador total |
| activo | bool DEFAULT true | Si puede recibir pedidos |
| created_at | timestamptz | Fecha de registro |

### `documentos_domiciliario`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| domiciliario_id | uuid FK → domiciliarios_independientes | A quién pertenece |
| tipo | text NOT NULL | 'cedula_frente', 'cedula_reverso', 'licencia', 'soat', 'foto_vehiculo' |
| url | text NOT NULL | Archivo en Supabase Storage |
| estado | text DEFAULT 'pendiente' | 'pendiente', 'aprobado', 'rechazado' |
| revisado_por | uuid FK → usuarios, null | Quién lo revisó |
| motivo_rechazo | text | Razón si fue rechazado |
| created_at | timestamptz | Fecha de subida |

### `domiciliarios_sesiones`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| domiciliario_id | uuid FK → domiciliarios_independientes | A quién pertenece |
| lat | numeric(10,7) NOT NULL | Latitud actual |
| lng | numeric(10,7) NOT NULL | Longitud actual |
| precision_metros | numeric | Precisión del GPS |
| disponible | bool DEFAULT true | Si está disponible |
| ciudad_id | uuid FK → ciudades | En qué ciudad opera ahora |
| fecha_inicio | timestamptz DEFAULT now() | Inicio del turno |
| fecha_fin | timestamptz | Fin del turno |
| activa | bool DEFAULT true | Si la sesión sigue abierta |

### `domiciliarios_ubicaciones_historial`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| domiciliario_id | uuid FK → domiciliarios_independientes | A quién pertenece |
| pedido_id | uuid FK → pedidos | Durante qué pedido |
| lat | numeric(10,7) NOT NULL | Latitud |
| lng | numeric(10,7) NOT NULL | Longitud |
| fecha | timestamptz DEFAULT now() | Cuándo se registró |

### `ofertas_pedido`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_id | uuid FK → pedidos | El pedido que necesita repartidor |
| sucursal_id | uuid FK → sucursales | Desde dónde recoger |
| tipo_busqueda | text | 'planta', 'independiente', 'hibrido' |
| radio_busqueda_km | numeric DEFAULT 3 | Radio actual |
| estado | text DEFAULT 'buscando' | 'buscando', 'aceptada', 'expirada', 'cancelada' |
| domiciliario_asignado_id | uuid FK → domiciliarios_independientes, null | Quién la aceptó |
| valor_domicilio_domiciliario | numeric(12,2) | Lo que gana el domiciliario |
| comision_plataforma | numeric(12,2) | Ganancia de Foody |
| tiempo_expiracion | timestamptz | Cuándo expira |
| intento_numero | int DEFAULT 1 | Número de intento |
| created_at | timestamptz | Cuándo se creó |

### `respuestas_oferta`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| oferta_id | uuid FK → ofertas_pedido | A qué oferta responde |
| domiciliario_id | uuid FK → domiciliarios_independientes | Quién respondió |
| respuesta | text NOT NULL | 'aceptada', 'rechazada', 'expirada', 'no_vio' |
| lat_al_momento | numeric(10,7) | Dónde estaba |
| lng_al_momento | numeric(10,7) | Dónde estaba |
| distancia_al_momento_km | numeric | Qué tan lejos estaba |
| fecha | timestamptz DEFAULT now() | Cuándo respondió |

### `asignaciones_domicilio`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_id | uuid FK → pedidos | Qué pedido |
| tipo_domiciliario | text NOT NULL | 'planta', 'independiente' |
| domiciliario_planta_id | uuid FK → domiciliarios_planta, null | Si es de planta |
| domiciliario_independiente_id | uuid FK → domiciliarios_independientes, null | Si es independiente |
| asignado_por | uuid FK → usuarios, null | Quién asignó (null=automático) |
| estado | text DEFAULT 'asignado' | 'asignado', 'en_camino', 'entregado' |
| fecha_asignacion | timestamptz DEFAULT now() | Cuándo se asignó |
| fecha_entrega | timestamptz | Cuándo se entregó |

### `calificaciones_domiciliario`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| pedido_id | uuid FK → pedidos | El pedido calificado |
| domiciliario_id | uuid FK → domiciliarios_independientes | Quién se califica |
| device_id | text FK → dispositivos_cliente | Quién califica |
| calificacion | int NOT NULL | 1 a 5 estrellas |
| comentario | text | Comentario opcional |
| fecha | timestamptz DEFAULT now() | Cuándo se calificó |

### `ganancias_domiciliario`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| domiciliario_id | uuid FK → domiciliarios_independientes | A quién corresponde |
| pedido_id | uuid FK → pedidos | Por qué pedido |
| valor_entrega | numeric(12,2) NOT NULL | Lo que recibe el domiciliario |
| comision_plataforma | numeric(12,2) NOT NULL | Ganancia de Foody |
| estado | text DEFAULT 'pendiente' | 'pendiente', 'pagado' |
| fecha_entrega | timestamptz | Cuándo se completó |
| fecha_pago | timestamptz | Cuándo se le pagó |
| created_at | timestamptz | Fecha de creación |

---

## Módulo 10 — Caja e inteligencia financiera

### `cajas`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| usuario_apertura_id | uuid FK → usuarios | Quién abrió |
| usuario_cierre_id | uuid FK → usuarios, null | Quién cerró |
| monto_inicial | numeric(12,2) NOT NULL | Efectivo con que se abrió |
| monto_esperado | numeric(12,2) | Calculado al cerrar |
| monto_cierre_real | numeric(12,2) | Lo que el cajero contó |
| diferencia | numeric(12,2) | Real - Esperado |
| estado | text DEFAULT 'abierta' | 'abierta', 'cerrada' |
| observaciones_cierre | text | Nota al cerrar |
| fecha_apertura | timestamptz NOT NULL | Cuándo se abrió |
| fecha_cierre | timestamptz | Cuándo se cerró |

### `movimientos_caja`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| caja_id | uuid FK → cajas | A qué turno |
| sucursal_id | uuid FK → sucursales | A qué sede |
| pedido_id | uuid FK → pedidos, null | Si vino de una venta |
| registrado_por | uuid FK → usuarios | Quién lo registró |
| tipo | text NOT NULL | 'ingreso', 'egreso', 'retiro_parcial' |
| concepto | text NOT NULL | Ver conceptos |
| metodo | text | 'efectivo', 'tarjeta', 'transferencia', 'nequi' |
| monto | numeric(12,2) NOT NULL | Valor siempre positivo |
| descripcion | text | Detalle adicional |
| fecha | timestamptz DEFAULT now() | Cuándo ocurrió |

**Conceptos ingreso:** `venta_efectivo`, `venta_tarjeta`, `venta_transferencia`, `venta_nequi`, `propina`, `abono_cuenta_por_cobrar`
**Conceptos egreso:** `gasto_mercado`, `pago_servicio`, `adelanto_empleado`, `pago_domiciliario`, `gasto_operativo`
**Conceptos retiro:** `retiro_propietario`, `retiro_autorizado`

### `cortes_caja`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| caja_id | uuid FK → cajas | En qué turno |
| monto_retirado | numeric(12,2) NOT NULL | Cuánto se retiró |
| motivo | text | Por qué |
| autorizado_por | uuid FK → usuarios | Quién autorizó |
| recibido_por | uuid FK → usuarios | Quién recibió el físico |
| fecha | timestamptz DEFAULT now() | Cuándo |

### `gastos`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| caja_id | uuid FK → cajas | En qué turno |
| registrado_por | uuid FK → usuarios | Quién registró |
| concepto | text NOT NULL | "Compra gas", "Pago internet" |
| categoria | text | 'operativo', 'nomina', 'servicios', 'mercado', 'arriendo', 'otros' |
| monto | numeric(12,2) NOT NULL | Cuánto |
| comprobante_url | text | Foto del recibo |
| fecha | timestamptz NOT NULL | Cuándo ocurrió |
| created_at | timestamptz | Cuándo se registró |

### `costos_operativos_fijos`
Gastos recurrentes que afectan el cálculo de ganancia neta real.
(arriendo, empleados, internet, gas, energía, agua)

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| concepto | text NOT NULL | "Arriendo", "Nómina cocina" |
| categoria | text | 'arriendo', 'nomina', 'servicios', 'otros' |
| monto_mensual | numeric(12,2) NOT NULL | Cuánto cuesta al mes |
| activo | bool DEFAULT true | Si sigue vigente |
| created_at | timestamptz | Fecha de creación |

### `cuentas_por_cobrar`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| pedido_id | uuid FK → pedidos | El pedido fiado |
| cliente_nombre | text NOT NULL | A quién se fió |
| cliente_telefono | text | Para cobrar |
| monto | numeric(12,2) NOT NULL | Cuánto debe |
| pagado | bool DEFAULT false | Si ya pagó |
| fecha_vencimiento | timestamptz | Compromiso de pago |
| fecha_pago | timestamptz | Cuándo pagó |
| registrado_por | uuid FK → usuarios | Quién lo autorizó |
| created_at | timestamptz | Fecha de creación |

---

**Fórmulas de inteligencia financiera que calcula el backend:**

```
Food Cost          = (costo_ingredientes / ventas_brutas) × 100
Ganancia bruta     = ventas_brutas - costo_ventas (de margenes_venta)
Gastos operativos  = SUM(gastos) + SUM(costos_operativos_fijos proporcional) + SUM(egresos caja)
Ganancia neta real = ganancia_bruta - gastos_operativos
Punto de equilibrio = costos_fijos_mes / margen_contribucion_promedio
Precio sugerido    = costo_produccion / (1 - margen_deseado/100)
```

**Reportes que genera el sistema:**
- Utilidad por período (día/semana/mes/rango)
- Food cost por producto y general
- Inventario teórico vs real con diferencias
- Merma por tipo y por ingrediente
- Ventas por producto (top performers y bottom)
- Horas pico por día de la semana
- Desperdicios registrados
- Costo operativo total vs ventas
- Punto de equilibrio mensual
- Productos más rentables vs más vendidos

---

## Módulo 11 — Fiscal: IVA y factura electrónica DIAN

### `configuracion_fiscal_sucursal`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | A qué sede |
| nit | text NOT NULL | NIT sin dígito de verificación |
| razon_social | text NOT NULL | Nombre legal del negocio |
| regimen | text NOT NULL | 'simplificado', 'comun' |
| responsable_iva | bool DEFAULT false | Si es responsable del IVA |
| porcentaje_iva_general | numeric(5,2) DEFAULT 0 | 19% régimen común, 0 simplificado |
| prefijo_factura | text | 'FAC', 'FE', 'SETP' |
| resolucion_dian | text | Número de resolución DIAN |
| rango_desde | int | Número inicial autorizado |
| rango_hasta | int | Número final autorizado |
| consecutivo_actual | int DEFAULT 0 | Último número emitido |
| proveedor_fe | text | 'factus', 'alegra', 'siigo', null |
| api_key_proveedor | text | API key encriptada en backend |
| activo | bool DEFAULT true | Si está activo |
| created_at | timestamptz | Fecha de creación |

### `facturas`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | Quién emitió |
| pedido_id | uuid FK → pedidos | El pedido origen |
| caja_id | uuid FK → cajas | En qué turno |
| numero_factura | text NOT NULL | Prefijo + consecutivo |
| cufe | text | Código DIAN |
| estado | text DEFAULT 'borrador' | 'borrador', 'emitida', 'aceptada_dian', 'rechazada_dian' |
| subtotal | numeric(12,2) NOT NULL | Base gravable |
| iva_porcentaje | numeric(5,2) NOT NULL | % aplicado |
| iva_valor | numeric(12,2) NOT NULL | Valor IVA |
| total | numeric(12,2) NOT NULL | Total con IVA |
| cliente_nombre | text NOT NULL | Nombre fiscal |
| cliente_nit_cc | text | NIT o cédula |
| cliente_email | text | Para enviar PDF |
| cliente_direccion | text | Dirección fiscal |
| xml_enviado | text | XML enviado al proveedor |
| respuesta_dian | jsonb | Respuesta completa DIAN |
| pdf_url | text | PDF en Supabase Storage |
| fecha_emision | timestamptz NOT NULL | Fecha y hora de emisión |
| created_at | timestamptz | Fecha de creación |

---

## Módulo 12 — Auditoría y detección de riesgo

### `auditoria_logs`
Solo INSERT. Nunca UPDATE ni DELETE.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| usuario_id | uuid FK → usuarios | Quién hizo la acción |
| sucursal_id | uuid FK → sucursales | En qué sede |
| accion | text NOT NULL | 'crear', 'editar', 'eliminar', 'cambiar_estado' |
| tabla_afectada | text NOT NULL | Nombre de la tabla |
| registro_id | uuid | ID del registro afectado |
| datos_antes | jsonb | Estado antes del cambio |
| datos_despues | jsonb | Estado después del cambio |
| ip | text | IP del dispositivo |
| dispositivo | text | Info del dispositivo |
| fecha | timestamptz DEFAULT now() | Cuándo ocurrió |

### `alertas_riesgo`
| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| sucursal_id | uuid FK → sucursales | En qué sede |
| usuario_id | uuid FK → usuarios | Quién generó la alerta |
| pedido_id | uuid FK → pedidos, null | Si aplica a un pedido |
| tipo | text NOT NULL | Ver tipos abajo |
| nivel | text NOT NULL | 'bajo', 'medio', 'alto', 'critico' |
| descripcion | text NOT NULL | Qué pasó exactamente |
| datos_contexto | jsonb | Contexto adicional |
| revisado | bool DEFAULT false | Si el admin la vio |
| revisado_por | uuid FK → usuarios, null | Quién la revisó |
| fecha | timestamptz DEFAULT now() | Cuándo se generó |

**Tipos de alerta:** `eliminacion_post_cocina`, `descuento_manual_excesivo`, `cancelaciones_frecuentes`, `transferencia_multiple_mesa`, `modificacion_precio_manual`, `cuadre_caja_negativo`, `retiro_sin_autorizacion`, `cuenta_por_cobrar_vencida`, `stock_minimo_alcanzado`, `producto_sin_stock`, `costo_ingrediente_subio`, `producto_margen_bajo`, `ventas_producto_caen`, `food_cost_elevado`, `pedido_sin_domiciliario`, `domiciliario_tarda_excesivo`, `diferencia_inventario_fisica`, `merma_excesiva`

---

## Módulo 13 — Reportes y KPIs

No son tablas de datos, son vistas o queries que el backend ejecuta.
Se documentan aquí para que Cursor sepa qué construir.

### Reportes financieros
- `GET /reportes/financiero?desde=&hasta=&sucursal_id=` → ventas, costos, ganancia bruta, gastos, ganancia neta, food cost
- `GET /reportes/productos?desde=&hasta=` → ranking por margen, por ventas, food cost por producto
- `GET /reportes/food-cost?desde=&hasta=` → food cost diario, semanal, mensual vs objetivo
- `GET /reportes/punto-equilibrio` → cuánto necesita vender para no perder

### Reportes de inventario
- `GET /reportes/inventario/estado` → stock actual vs teórico vs mínimo
- `GET /reportes/inventario/mermas?desde=&hasta=` → mermas por tipo e ingrediente
- `GET /reportes/inventario/rotacion` → qué ingredientes se usan más
- `GET /reportes/inventario/compras?desde=&hasta=` → historial de compras y costos

### Reportes operativos
- `GET /reportes/pedidos/horas-pico` → ventas por hora y día de semana
- `GET /reportes/pedidos/estados` → tiempos promedio en cada estado (usa estados_pedido_historial)
- `GET /reportes/domiciliarios/rendimiento` → entregas, tiempos, calificaciones

---

## Resumen total del sistema

| Módulo | Tablas | Descripción |
|---|---|---|
| 1. Geografía | ciudades, restaurantes, sucursales, zonas_cobertura | Base geográfica y multi-sucursal |
| 2. Usuarios | usuarios, roles_permisos | Personal interno |
| 3. Dispositivos | dispositivos_cliente, tokens_push_admin | Clientes sin login |
| 4. Catálogo | categorias, productos, toppings, bebidas, combos, combo_items, estados_promociones | Menú completo |
| 5. ERP Gastronómico | unidades_medida, ingredientes, presentaciones_compra, compras_ingrediente, movimientos_ingrediente, recetas, receta_items, costos_receta, historial_costos_receta, producciones, mermas, conteos_inventario, conteo_items, margenes_venta | Costeo industrial completo |
| 6. Cocinas | cocinas, impresoras, horarios_sucursal | Estaciones e impresión |
| 7. Mesas | mesas, transferencias_mesa | QR y auditoría |
| 8. Pedidos | pedidos, estados_pedido_historial, pedido_items, pedido_item_toppings, pedido_item_bebidas, pedido_combo_selecciones | Corazón del sistema |
| 9. Domiciliarios | domiciliarios_planta, domiciliarios_independientes, documentos_domiciliario, domiciliarios_sesiones, domiciliarios_ubicaciones_historial, ofertas_pedido, respuestas_oferta, asignaciones_domicilio, calificaciones_domiciliario, ganancias_domiciliario | Sistema completo de reparto |
| 10. Caja | cajas, movimientos_caja, cortes_caja, gastos, costos_operativos_fijos, cuentas_por_cobrar | Finanzas operativas |
| 11. Fiscal | configuracion_fiscal_sucursal, facturas | IVA y DIAN |
| 12. Auditoría | auditoria_logs, alertas_riesgo | Control y riesgo |
| 13. Reportes | (vistas/queries del backend) | KPIs e inteligencia |

**Total: 13 módulos — 68 tablas**

---

## Transacción completa al confirmar un pedido (20 pasos)

```
1.  Validar sucursal activa y en horario
2.  Validar productos: existen y disponible=true
3.  Validar precios: coinciden exactamente con BD
4.  Por cada producto consultar receta_items y verificar stock en ingredientes
5.  Calcular subtotal, IVA, costo domicilio, descuento, total
6.  INSERT en pedidos con numero_pedido generado
7.  INSERT en estados_pedido_historial (estado inicial)
8.  INSERT en pedido_items (con cocina_id y costo_unitario al momento)
9.  INSERT en pedido_item_toppings
10. INSERT en pedido_item_bebidas
11. INSERT en pedido_combo_selecciones
12. Por cada ingrediente de cada receta: UPDATE stock en ingredientes
13. INSERT en movimientos_ingrediente tipo='venta'
14. CHECK stock <= stock_minimo → INSERT alerta stock_minimo_alcanzado
15. CHECK stock = 0 → UPDATE productos SET disponible=false
16. INSERT en margenes_venta con costo_al_momento
17. Si tiene metodo_pago → INSERT movimiento_caja automático
18. Si requiere_factura → CREATE borrador en facturas
19. INSERT en auditoria_logs
20. COMMIT

POST-TRANSACCIÓN (paralelo):
- Supabase Realtime broadcast al canal de la sucursal
- WebSocket → servidor Python → impresión automática por cocina
- FCM push a roles de cocina involucrados
- FCM push a meseras si es mesa por QR (para aprobar)
- FCM push a panel domicilios si es domicilio
- Iniciar búsqueda de domiciliario si aplica
```

---

## Módulo 14 — Control global de la plataforma (super_admin)

Este módulo es exclusivo del super_admin (el programador/dueño de Foody).
No es visible para ningún restaurante ni usuario interno.

### `suscripciones_restaurante`
Control de acceso y estado de pago de cada restaurante en la plataforma.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| restaurante_id | uuid FK → restaurantes | A qué restaurante pertenece |
| estado | text NOT NULL | 'prueba', 'activa', 'vencida', 'bloqueada' |
| plan | text NOT NULL | 'basico', 'pro', 'enterprise' |
| fecha_inicio | timestamptz NOT NULL | Cuándo empezó la suscripción |
| fecha_vencimiento | timestamptz NOT NULL | Cuándo vence |
| bloqueado_por | uuid FK → usuarios, null | Quién bloqueó (super_admin) |
| motivo_bloqueo | text | Por qué se bloqueó |
| created_at | timestamptz | Fecha de creación |

**Comportamiento:** Si `estado = 'bloqueada'` o `estado = 'vencida'`, el backend rechaza
cualquier request de ese restaurante con error `RESTAURANTE_BLOQUEADO`. Los datos
se conservan 30 días después del bloqueo antes de eliminar.

---

### `configuracion_global_foody`
Parámetros del sistema editables desde el panel super_admin sin tocar código.

| Campo | Tipo | Descripción |
|---|---|---|
| id | uuid PK | Identificador único |
| clave | text UNIQUE NOT NULL | Nombre del parámetro |
| valor | text NOT NULL | Valor actual |
| descripcion | text | Qué hace este parámetro |
| editado_por | uuid FK → usuarios | Quién lo modificó |
| updated_at | timestamptz | Última modificación |

**Parámetros iniciales del sistema:**

| clave | valor | descripción |
|---|---|---|
| comision_domiciliario_porcentaje | 15 | % que cobra Foody por entrega independiente |
| tiempo_expiracion_oferta_seg | 60 | Segundos antes de que expire una oferta |
| radio_inicial_busqueda_km | 3 | Radio inicial para buscar domiciliarios |
| ampliacion_radio_km | 2 | Cuánto amplía el radio por intento fallido |
| intentos_max_busqueda | 3 | Intentos antes de alertar al restaurante |
| umbral_alerta_descuento_pct | 30 | % de descuento que dispara alerta de riesgo |
| umbral_alerta_cuadre_caja | 5000 | Diferencia en COP que dispara alerta de caja |
| umbral_alerta_costo_sube_pct | 15 | % de subida de costo que dispara alerta |
| umbral_alerta_margen_bajo_pct | 20 | % de margen mínimo antes de alertar |
| dias_datos_restaurante_bloqueado | 30 | Días que se guardan datos tras bloqueo |
| tiempo_aprobacion_mesera_min | 3 | Minutos para que mesera apruebe pedido QR |
| umbral_reloj_pedido_rojo_min | 15 | Minutos en estado antes de poner reloj en rojo |

---

## Flujo de login y redirección por rol

Un solo endpoint de login. El backend detecta el rol y devuelve el tipo de dashboard.
Flutter navega a la pantalla correcta sin que el usuario haga nada adicional.

### Endpoint
`POST /auth/login`
```json
Request:  { "email": "usuario@foody.com", "contrasena": "123456" }

Response: {
  "exito": true,
  "datos": {
    "token": "eyJ...",
    "dashboard": "foody_control" | "domiciliario" | "restaurante",
    "rol": "super_admin" | "domiciliario_planta" | "admin" | "cajero" | ...,
    "permisos": ["crear_pedido", "ver_caja", ...],
    "usuario": { "id": "uuid", "nombre": "Juan", "sucursal_id": "uuid" }
  }
}
```

### Lógica de redirección en Flutter
```dart
// main_admin.dart — después del login exitoso
switch (respuesta.dashboard) {
  case 'foody_control':
    // Solo accesible si rol == super_admin
    navegar a PanelFoodyScreen();
  case 'domiciliario':
    // Solo accesible si rol == domiciliario_planta
    navegar a DashboardDomiciliarioScreen();
  default:
    // Cualquier otro rol del restaurante
    navegar a PanelRestauranteScreen(
      rol: respuesta.rol,
      permisos: respuesta.permisos
    );
}
```

### URL del panel super_admin
La ruta del panel Foody no aparece en ningún lugar público de la app.
No hay enlace visible. Solo quien conoce la URL puede llegar ahí.
Ejemplo: `https://admin.foody.com/foody-control`
Protegida adicionalmente por: verificación de rol `super_admin` en cada request.
Si alguien intenta acceder sin ese rol, redirige al login.

---

## Panel Foody — super_admin (secciones)

| Sección | Qué puede hacer |
|---|---|
| Ciudades | Crear, editar, activar, desactivar ciudades de la plataforma |
| Restaurantes | Crear, editar, bloquear, desbloquear restaurantes. Ver sus sucursales |
| Suscripciones | Ver estado de pago de cada restaurante, cambiar plan, bloquear por mora |
| Usuarios globales | Ver todos los usuarios de todos los restaurantes. Crear, editar, cambiar contraseña, habilitar, inhabilitar usuarios de cualquier restaurante |
| Roles | Crear roles personalizados para restaurantes específicos si lo necesitan |
| Domiciliarios | Ver todos los domiciliarios independientes, aprobar documentos, suspender cuentas |
| Estadísticas globales | Pedidos totales, restaurantes activos, domiciliarios activos, ingresos Foody |
| Configuración global | Editar parámetros de `configuracion_global_foody` sin código |

---

## Panel del restaurante — pestañas por rol

Flutter construye el menú dinámicamente según los permisos devueltos por el backend.
Si un rol no tiene permiso para una pestaña, **no aparece**. No está deshabilitada, no existe.

| Pestaña | admin | gerente | cajero | mesero | cocina_X |
|---|---|---|---|---|---|
| Dashboard general | ✅ | ✅ | ❌ | ❌ | ❌ |
| Pedidos (Kanban + reloj) | ✅ | ✅ | ✅ | ✅ | ❌ |
| Menú y productos | ✅ | ✅ | ❌ | ❌ | ❌ |
| Inventario y recetas | ✅ | ✅ | ❌ | ❌ | ❌ |
| Mesas y QR | ✅ | ✅ | ❌ | ✅ | ❌ |
| Cocinas (tickets) | ✅ | ✅ | ❌ | ❌ | ✅ solo la suya |
| Caja | ✅ | ✅ | ✅ | ❌ | ❌ |
| Domiciliarios | ✅ | ✅ | ❌ | ❌ | ❌ |
| Reportes | ✅ | ✅ | ✅ básico | ❌ | ❌ |
| Alertas de riesgo | ✅ | ✅ | ❌ | ❌ | ❌ |
| Usuarios de la sucursal | ✅ | ❌ | ❌ | ❌ | ❌ |
| Sucursales | ✅ | ❌ | ❌ | ❌ | ❌ |
| Configuración | ✅ | ✅ parcial | ❌ | ❌ | ❌ |
| Encargos | ✅ | ✅ | ✅ | ❌ | ❌ |
| Promociones | ✅ | ✅ | ❌ | ❌ | ❌ |

---

## Dashboard domiciliario de planta — secciones

Pantalla completamente diferente al panel del restaurante.
Diseñada para celular. Simple y directa.

| Sección | Qué ve y puede hacer |
|---|---|
| Pedidos pendientes | Los domicilios asignados a él. Card por pedido con: dirección, nombre cliente, teléfono, mapa, total, método de pago. Botón "Confirmar entrega" → cambia estado a entregado. Si método de pago es efectivo, confirma que recibió el dinero |
| Historial | Sus entregas del día con estado, hora y valor |
| Estadísticas | Entregas hoy / semana / mes. Tiempo promedio por entrega |
| Configuración | Su perfil, foto, cambiar contraseña |

**Nota:** El domiciliario de planta NO puede ver pedidos de otros domiciliarios,
ni el menú, ni la caja, ni nada del sistema del restaurante.
Solo ve lo que le asignaron a él.
