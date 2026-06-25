# Pantallas — Flujo principal Foody
## Descripción detallada de cada pantalla para Cursor

---

## APP CLIENTE (foody_cliente) — Sin login

---

### P01 — Splash / Selección de ciudad

**Qué muestra:**
- Logo Foody centrado con animación de entrada suave
- Texto "¿En qué ciudad estás?" debajo del logo
- Lista de ciudades activas como cards horizontales con nombre e imagen representativa
- Si ya eligió ciudad antes (guardada en SharedPreferences), la preselecciona y va directo a P02

**Acciones del usuario:**
- Tocar una ciudad → guarda en SharedPreferences → navega a P02

**Estados:**
- Cargando ciudades: skeleton loader
- Sin ciudades activas: mensaje "Próximamente en tu ciudad"
- Error de conexión: botón reintentar

---

### P02 — Lista de restaurantes de la ciudad

**Qué muestra:**
- Header con nombre de la ciudad y botón para cambiarla
- Barra de búsqueda para filtrar restaurantes
- Sección superior: "Historias / Promociones" — scroll horizontal de cards circulares por restaurante. Al tocar una, abre el estado de ese restaurante en pantalla completa con temporizador como WhatsApp
- Lista de restaurantes: card por restaurante con banner, logo, nombre, descripción corta, si está abierto o cerrado según horario
- Restaurantes cerrados van al final y tienen overlay de "Cerrado"

**Acciones del usuario:**
- Tocar historia/promoción → abre P_HISTORIA (pantalla temporal fullscreen)
- Tocar restaurante → navega a P03

**Estados:**
- Sin restaurantes en la ciudad: ilustración + "Aún no hay restaurantes en tu ciudad"
- Cargando: skeleton de cards

---

### P03 — Menú del restaurante

**Qué muestra:**
- Header con banner del restaurante (imagen grande), logo pequeño superpuesto, nombre, estado (abierto/cerrado), botón de atrás
- Tabs de categorías en scroll horizontal sticky (se quedan arriba al hacer scroll)
- Grid o lista de productos por categoría activa con: foto, nombre, descripción corta, precio
- Si hay sección de encargos, aparece como última tab "Encargos 📦"
- Botón flotante del carrito en la esquina inferior derecha con contador de ítems y total acumulado. Aparece cuando hay algo en el carrito.
- Productos no disponibles aparecen con overlay gris y texto "No disponible"

**Acciones del usuario:**
- Tocar tab de categoría → scroll a esa sección
- Tocar producto → abre P04 (modal inferior)
- Tocar botón carrito → abre P05

**Estados:**
- Restaurante cerrado: banner rojo "Cerrado" pero puede ver el menú sin poder pedir
- Sin productos en categoría: "Esta categoría está vacía"

---

### P04 — Detalle del producto (modal inferior)

**Qué muestra:**
- Imagen grande del producto
- Nombre y precio
- Descripción completa
- Si tiene toppings disponibles: sección "Agrega extras" con chips seleccionables y precio de cada topping
- Si tiene bebidas disponibles: sección "¿Qué vas a tomar?" con opciones
- Campo de texto "Observaciones" (opcional): "Sin cebolla", "Bien cocido"
- Contador de cantidad (-, número, +)
- Botón "Agregar al carrito" con el precio total del ítem en el botón

**Acciones del usuario:**
- Seleccionar toppings (múltiple selección)
- Seleccionar bebida (selección única)
- Ajustar cantidad
- Escribir observaciones
- Tocar "Agregar" → cierra modal, actualiza carrito, muestra snackbar de confirmación

---

### P05 — Carrito

**Qué muestra:**
- Lista de ítems en el carrito: foto pequeña, nombre, toppings seleccionados, observaciones, precio, botones para editar cantidad o eliminar
- Resumen: subtotal, costo de domicilio (si aplica), total
- Sección de tipo de pedido: tabs o selector "Mesa 🪑 / Para llevar 🛍️ / Domicilio 🛵"
- Botón "Confirmar pedido"

**Acciones del usuario:**
- Cambiar cantidad de un ítem o eliminarlo
- Seleccionar tipo de pedido
- Tocar "Confirmar pedido" → va a P06 según el tipo

**Estados:**
- Carrito vacío: ilustración + "Tu carrito está vacío" + botón volver al menú

---

### P06A — Checkout para llevar

**Qué muestra:**
- Resumen del pedido (colapsable)
- Campo nombre de quien recibe (opcional, precargado si ya lo dio antes)
- Selector de método de pago: Efectivo / Tarjeta / Transferencia
- Total final destacado
- Botón "Hacer pedido"

---

### P06B — Checkout domicilio

**Qué muestra:**
- Resumen del pedido (colapsable)
- Nombre de quien recibe (obligatorio)
- Teléfono (obligatorio, con validación de formato)
- Dirección de entrega (obligatorio, campo de texto)
- Botón "Usar mi ubicación actual" → captura GPS y muestra en mapa pequeño
- Si ya tiene datos guardados: aparecen precargados con opción de editar
- Checkbox "Guardar esta información para la próxima vez"
- ¿Necesito factura? → toggle. Si activa, pide NIT/cédula, nombre fiscal, email
- Selector de método de pago
- Total con costo de domicilio incluido
- Botón "Hacer pedido"

---

### P07 — Confirmación y seguimiento del pedido

**Qué muestra:**
- Animación de éxito (check verde animado)
- Número de pedido grande
- Línea de tiempo del estado: Pendiente → Confirmado → En cocina → Listo → En camino (si domicilio) → Entregado
- El estado actual resaltado y los anteriores marcados como completados
- Si es domicilio y hay domiciliario asignado: nombre, foto, calificación del domiciliario y mapa con su ubicación en tiempo real
- Botón "Ver menú" para seguir pidiendo (pedidos adicionales en mesa)

**Actualización en tiempo real:** Supabase Realtime escucha cambios en el estado del pedido y actualiza la línea de tiempo sin refrescar.

---

## APP COCINA (foody_cocina)

---

### C01 — Login cocina

Campo de email y contraseña. Sin opción de registro (el admin crea las cuentas).

---

### C02 — Pantalla principal cocina

**Qué muestra:**
- Header con nombre de la cocina y estado (activa/inactiva)
- Lista de tickets en tiempo real, ordenados por hora de llegada (más antiguo arriba)
- Cada ticket muestra: número de pedido, mesa o tipo, hora, lista de ítems con cantidades y observaciones
- Cada ítem tiene botón "Preparando" y "Listo"
- Ticket completo (todos sus ítems listos) se marca visualmente diferente y se puede archivar

**Comportamiento:**
- Cuando llega ticket nuevo: sonido de notificación + vibración + el ticket aparece animado arriba
- Los ítems marcados como "Preparando" cambian de color (amarillo)
- Los ítems marcados como "Listo" cambian de color (verde) y se tachan
- Cuando todos los ítems del ticket están listos: el ticket completo se resalta en verde

**Acciones:**
- Marcar ítem como "Preparando" → actualiza en BD, notifica en tiempo real al panel admin y mesero
- Marcar ítem como "Listo" → actualiza en BD, si es el último ítem, notifica a mesero y admin que el pedido está listo

---

## PANEL ADMIN/CAJERO/MESERO (foody_admin)

---

### A01 — Login

Email + contraseña. El sistema detecta el rol y redirige a la pantalla correcta.
- Admin/Gerente → A02 Dashboard
- Cajero → A_CAJERO pantalla de caja y pedidos para llevar
- Mesero → A_MESERO vista de mesas

---

### A02 — Dashboard admin

**Qué muestra:**
- Tarjetas resumen: ventas hoy, pedidos activos, pedidos completados hoy, alertas de riesgo pendientes
- Gráfica de ventas de los últimos 7 días
- Lista de pedidos activos en tiempo real (todos los tipos)
- Lista de alertas de riesgo no revisadas con nivel y descripción
- Accesos rápidos a los módulos principales

---

### A_CAJERO — Panel cajero

**Diseño:** Dividido en dos paneles si la pantalla es grande (tablet). En móvil son tabs.
- Panel izquierdo/Tab 1: Constructor de pedido (categorías en tabs, productos en lista compacta sin fotos grandes, toque para agregar al carrito activo)
- Panel derecho/Tab 2: Carrito activo con ítems, total, selector de tipo (para llevar/domicilio), nombre cliente, método de pago, botón confirmar

**Estado de caja:**
- Si no hay caja abierta: pantalla de apertura de caja (ingresar monto inicial)
- Si hay caja abierta: muestra banner con monto acumulado del turno y botón para ver movimientos

---

### A_MESERO — Vista de mesas

**Qué muestra:**
- Grid de mesas con su estado visual:
  - Verde: libre
  - Amarillo: ocupada
  - Naranja parpadeante: tiene pedido nuevo por QR esperando aprobación
  - Rojo: pagando
- Al tocar una mesa ocupada: ver pedidos activos de esa mesa, estado de cocina por ítem
- Al tocar mesa con pedido pendiente: ver detalle del pedido con botones Aprobar/Rechazar
- Al tocar mesa libre: opción de crear pedido manual para esa mesa
- Botón de transferencia de mesa: seleccionar origen y destino con campo de motivo

---

## APP DOMICILIARIO INDEPENDIENTE (foody_domiciliario)

---

### D01 — Registro y verificación

Formulario de datos personales, tipo de vehículo, subida de documentos (cédula frente y reverso, foto del vehículo). Pantalla de espera: "Tu cuenta está siendo verificada. Te notificaremos cuando esté lista."

---

### D02 — Inicio de turno

Toggle grande "Estoy disponible". Al activarlo, el GPS empieza a reportar ubicación cada 30 segundos. Muestra ciudad donde está operando. Contador de entregas del día y ganancias del día.

---

### D03 — Oferta de pedido (pantalla de notificación)

Aparece sobre cualquier pantalla cuando llega una oferta.
- Mapa con pin del restaurante y pin del cliente
- Distancia al restaurante y distancia estimada al cliente
- Valor que ganará por esta entrega
- Temporizador regresivo (60 segundos)
- Botón grande "Aceptar" y botón pequeño "Rechazar"
- Si el tiempo expira sin respuesta: se marca como "no_vio" automáticamente

---

### D04 — Pedido activo

- Datos del restaurante: nombre, dirección, teléfono
- Datos del cliente: nombre, teléfono, dirección, mapa con ubicación GPS del cliente
- Botón "Llegué al restaurante" → cambia estado
- Botón "En camino" → activa tracking continuo visible para el cliente
- Botón "Entregué" → cierra el pedido, activa calificación del cliente, registra ganancia

---

## PANTALLA DE LOGIN ÚNICA (foody_admin)

### L01 — Login principal

**Qué muestra:**
- Logo Foody centrado
- Campo email
- Campo contraseña con toggle de mostrar/ocultar
- Botón "Ingresar"
- Sin opción de registro (los usuarios los crea el admin o super_admin)
- Sin "olvidé mi contraseña" visible (opcional, se puede agregar después)

**Qué hace al ingresar:**
- Llama a `POST /auth/login`
- Muestra indicador de carga
- Si error: mensaje debajo del botón "Credenciales incorrectas"
- Si éxito: lee `respuesta.dashboard` y navega sin que el usuario haga nada

**Redirección automática:**
```
dashboard = 'foody_control'   → PanelFoodyScreen
dashboard = 'domiciliario'    → DashboardDomiciliarioScreen
dashboard = 'restaurante'     → PanelRestauranteScreen
```

---

## PANEL FOODY — SUPER_ADMIN

### F01 — Dashboard super_admin

**Qué muestra:**
- Header con logo Foody y badge "Panel de Control"
- 4 tarjetas de resumen: restaurantes activos, pedidos hoy (toda la plataforma),
  domiciliarios activos, ingresos Foody del mes (comisiones)
- Menú lateral con todas las secciones

**Secciones del menú lateral:**
- 🌆 Ciudades
- 🍽️ Restaurantes
- 💳 Suscripciones
- 👥 Usuarios
- 🔑 Roles
- 🛵 Domiciliarios independientes
- 📊 Estadísticas globales
- ⚙️ Configuración global

---

### F02 — Ciudades

**Qué muestra:**
- Lista de ciudades con nombre, slug, estado (activa/inactiva) y cantidad de restaurantes
- Botón "Nueva ciudad"
- Toggle activa/inactiva por ciudad

**Formulario nueva ciudad:**
- Nombre, slug (se genera automático del nombre), activa

---

### F03 — Restaurantes

**Qué muestra:**
- Lista de restaurantes con: nombre, ciudad, sucursales activas,
  estado de suscripción (badge de color), botones de acción
- Filtros: por ciudad, por estado de suscripción
- Botón "Nuevo restaurante"

**Acciones por restaurante:**
- Ver detalle (sus sucursales, usuarios, estadísticas)
- Editar nombre, ciudad, logo, banner
- Bloquear / desbloquear (con campo de motivo obligatorio)

---

### F04 — Suscripciones

**Qué muestra:**
- Lista de restaurantes con su estado de suscripción
- Badge de color: verde=activa, amarillo=prueba, naranja=vencida, rojo=bloqueada
- Fecha de vencimiento y días restantes
- Filtro por estado

**Acciones:**
- Cambiar plan ('basico', 'pro', 'enterprise')
- Extender fecha de vencimiento
- Bloquear con motivo
- Desbloquear

---

### F05 — Usuarios globales

**Qué muestra:**
- Lista de todos los usuarios de todos los restaurantes
- Filtros: por restaurante, por rol, por estado (activo/inactivo)
- Columnas: nombre, email, rol, restaurante, sucursal, estado, último acceso

**Acciones:**
- Crear usuario nuevo (selecciona restaurante, sucursal, rol)
- Editar nombre, email, foto
- Cambiar contraseña (sin ver la actual, la reemplaza directo)
- Activar / desactivar
- Cambiar rol

---

### F06 — Configuración global

**Qué muestra:**
- Lista de todos los parámetros de `configuracion_global_foody`
- Nombre del parámetro, descripción, valor actual, quién lo editó y cuándo
- Campo editable por parámetro con botón guardar individual

---

## DASHBOARD DOMICILIARIO DE PLANTA

### D01 — Pedidos pendientes (pantalla principal)

**Qué muestra:**
- Lista de pedidos asignados a él con estado 'asignado'
- Card por pedido:
  - Número de pedido y hora de asignación
  - Nombre y teléfono del cliente (con botón de llamar directo)
  - Dirección de entrega
  - Mapa pequeño con pin de destino
  - Total del pedido y método de pago
  - Botón grande "Confirmar entrega"

**Al presionar "Confirmar entrega":**
- Si método de pago ya está definido: confirma directamente
- Si método de pago es 'pendiente': muestra selector
  (Efectivo / Nequi / Tarjeta) antes de confirmar
- Al confirmar: cambia estado del pedido a 'entregado',
  cierra el card, mueve el pedido al historial

---

### D02 — Historial

- Lista de entregas del día ordenadas de más reciente a más antigua
- Cada ítem muestra: número pedido, hora, dirección, total, estado
- Filtro por fecha

---

### D03 — Estadísticas

- Entregas hoy / esta semana / este mes (contadores)
- Tiempo promedio de entrega
- Sin gráficas complejas, solo números claros

---

### D04 — Configuración domiciliario

- Foto de perfil (editable)
- Nombre (solo lectura, lo edita el admin)
- Email (solo lectura)
- Cambiar contraseña (campo contraseña actual + nueva + confirmar)
