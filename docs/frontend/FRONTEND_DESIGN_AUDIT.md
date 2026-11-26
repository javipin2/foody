# Foody — Auditoría visual / Product Design (Flutter)

> El estado de inspección y aceptación del rediseño administrativo se controla en [`FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md`](FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md). La auditoría histórica siguiente informa problemas detectados anteriormente, pero no equivale a una validación actual de todas las vistas.

## Nueva dirección premium (decisión del usuario, 2026-11-23)

Se acuerda evolucionar el estilo premium a partir de las cuatro referencias visuales, manteniendo marca, contenido y operaciones Foody. Dirección: superficies claras y limpias donde favorezcan la lectura, sidebar azul oscuro estructural, naranja Foody para acciones principales, turquesa para indicadores positivos, verde para confirmación/éxito y rojo para error/crítico; jerarquía tipográfica marcada, tablas de alta densidad en escritorio y transformación en vistas priorizadas en móvil, dashboards con tareas/indicadores reales y microinteracciones breves que respetan movimiento reducido. Evitar saturación, tarjetas gigantes y espacios vacíos artificiales. La implementación será progresiva; los cambios compartidos no implican que todas las vistas estén terminadas. La matriz completa de aceptación está en [`FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md`](FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md).

**Actualización visual:** la tabla desktop y las tarjetas móvil/tablet de Insumos, incluidos búsqueda, filtros, superficies, bordes y textos, usan tokens que siguen el tema activo. El Centro de Operación usa iconos semánticos y KPIs de altura uniforme. Análisis reemplaza su barra de 8–10 pestañas por un selector en compacto (menos de 720 px) y conserva la barra actual en escritorio, sincronizado con el `TabController` y sus índices de permisos. **Verificación de esta oleada:** `flutter test` 117/117; análisis global con 1 warning preexistente y 56 infos; build web estándar release correcto en `build/qa_ui_premium_20261123`; `impeccable detect --json --changed` devolvió `[]`. Análisis Wasm encontró incompatibilidades en dependencias existentes (`dart:html`, USB, geolocator y `image`), sin impedir el build estándar. Falta QA autenticado completo y revisión visual vista por vista en claro/oscuro, móvil/tablet/escritorio.

## Sistema visual: base y dirección acordada (2026-11-22)

La auditoría original es histórica y sus puntuaciones no se recalificaron en esta fase. El código ya cuenta con `ColoresFoody`, `TemaFoody` claro/oscuro, `SaaSTokens`, `OperacionUi` y `FoodyBreakpoints`; el trabajo es unificar uso, no crear otra paleta paralela.

- **Color:** tokens semánticos por función (marca/acción, superficie, texto, borde, éxito, atención, error); conservar acentos existentes y validar contraste en ambos temas.
- **Tipografía:** jerarquía desde `ThemeData.textTheme`; estilos inline solo para ajustes contextuales, evitando familias distintas por módulo.
- **Espaciado y forma:** escala existente SaaS `4/8/12/16/20/24/32`, radios `8/10/12/16`; reutilizarla.
- **Controles:** formularios con etiquetas persistentes, validación junto al campo y estados disabled/loading/error; tablas densas con acciones visibles y adaptación móvil mediante cards/listas.
- **Estados:** reutilizar `FoodyEstadoUi` / `FoodyAsyncBody`; distinguir sin conexión, carga, vacío, error y éxito sin depender solo del color.
- **Responsive:** breakpoints centrales `600/720/1100/1440`, contenido admin hasta `1280`; validar compacto, tablet y escritorio.
- **Evolución sectorial:** tokens/componentes genéricos en `core`; vocabulario, flujos y pantallas verticales en features de gastronomía. No crear un checkout genérico especulativo.

**Criterio de aceptación:** nuevas pantallas usan tokens existentes; patrones inconsistentes se migran incrementalmente sin mover reglas de negocio a Dart.

### Referencias visuales recibidas (2026-11-22)

Las cuatro imágenes adjuntas orientan composición, densidad y adaptación por dispositivo; no son una instrucción para copiar marca, datos ni módulos ajenos a Foody.

| Ref. | Qué aporta | Cómo trasladarlo a Foody | Qué no trasladar |
|---|---|---|---|
| 1 — dashboard SaaS oscuro | Navegación lateral compacta, jerarquía de títulos, superficies, indicadores resumidos y tabla operativa | Para paneles de administración y vistas de plataforma; aplicar azul oscuro estructural, naranja Foody para acciones y semántica consistente | Marca Stocky/morado, contenido de tenants genérico y cuatro KPI-card grandes en cada vista |
| 2 — panel móvil analítico | Resumen en una columna, visualizaciones pequeñas, tarjetas compactas y navegación táctil inferior | Referencia para lectura móvil de métricas e insights, respetando navegación y tareas reales de Foody | Copiar etiqueta, métricas, colores o el mismo patrón de navegación a POS/caja |
| 3 — panel tablet claro | Composición híbrida, menú lateral, barra superior, KPIs en fila, gráficos y actividad en columnas | Referencia para dashboard en tablet/desktop; colapsar o adaptar navegación bajo el breakpoint de escritorio | Escalar sin cambios el dashboard ancho a tablet |
| 4 — tabla de inventario | Barra de búsqueda/filtros, tabla compacta, jerarquía de stock y acciones contextuales | Referencia para la vista de listado de inventario en escritorio; en móvil transformar filas a cards priorizadas y mantener acciones accesibles | Datos de productos/equipos ajenos y tabla horizontal comprimida en móvil |

**Orden inicial de aplicación:** Configuración admin ya añadida como primer patrón de navegación, pendiente QA visual; después inventariar y abordar individualmente las vistas de Inventario (listado → detalle/formularios/diálogos), usando la referencia 4, y luego las vistas operativas priorizadas por la auditoría. En cada vista se registra propósito, elementos/acciones, tamaños, temas, estados y resultado de verificación. Las referencias 1–3 se aplican solo a dashboards/contextos equivalentes.

### Registro de rediseño por vista

| Vista | Propósito / acciones | Implementación | Verificación | Estado |
|---|---|---|---|---|
| Centro Configuración admin — `lib/features/admin/presentation/configuracion_admin_screen.dart` | Índice para establecimiento/sedes, horarios, cobertura, cocinas/impresión y equipo; abre pantallas existentes, no duplica formularios ni servicios | Composición por tarea; filas compactas; 1 columna compacto, 2 tablet, hasta 3 escritorio; superficie y tipografía del tema; enlaces filtrados por permisos | `flutter analyze` focalizado en 4 archivos: sin issues. QA visual autenticado, tamaños y temas aún pendientes | 🟡 Implementada; pendiente validación visual del usuario |
| Insumos — listado Mercado — `lib/features/inventario/presentation/inventario_admin_screen.dart` | Buscar/filtrar, inspeccionar niveles de stock y abrir edición, compra o ajuste | Escritorio ancho: tabla densa con insumo, categoría, stock/estado, costo unitario, compra y acciones; tablet: grid; compacto: tarjetas apiladas | Widget selector de secciones 6/6 en 320/390 light/dark y 820/1440; QA visual manual pendiente | 🟡 Implementada; verificar densidad/tablet/móvil durante revisión |
| Insumos — movimientos — misma ruta, pestaña Movimientos | Revisar cambios del stock y abrir el insumo relacionado | Registro compacto: nombre, tipo/fecha/motivo y transición de stock resaltada; la fila completa mantiene el acceso al insumo | `dart analyze` focalizado sin errores; QA visual pendiente | 🟡 Implementada; validar textos largos y tamaños pequeños |
| Traslados entre sedes — `lib/features/inventario/presentation/inventario_traslados_panel.dart` | Crear/envíar traslado, recibir en sede destino, cancelar en origen y consultar historial | Formulario con shell Foody; cabecera adaptable; cards con origen/destino, cantidad, estado semántico y acción en fila propia para móvil; estados vacío, carga, error y sin permiso explícitos | `dart analyze` del archivo: sin issues; no se realizó QA visual manual en navegador/dispositivo | 🟡 Implementada; QA visual pendiente |
| Shells compartidos de formulario — `lib/core/tema/foody_formulario.dart` | Proveer estructura consistente a formularios, secciones y métricas de módulos | `FoodyDialogoShell` usa `Dialog` y permite desplazar todo el contenido, incluidos encabezado y acciones, en ventanas bajas; acciones envuelven si hace falta. Evita medidas intrínsecas incompatibles con `LayoutBuilder`. Selectores largos de Menú/Inventario usan ancho expandido | Análisis limpio; formularios Insumo y Subreceta abren con teclado simulado en 320×568/390×844; Menú revalidado en widget tests | 🟡 Fallo transversal corregido; claro/oscuro y teclado físico pendientes |
| Editor de subreceta — `lib/features/inventario/presentation/widgets/dialogo_subreceta_form.dart` | Definir rendimiento, composición de ingredientes/subrecetas, modo de descuento/producción y costo estimado | Secciones/campos usan shells compartidos; modo de stock, preview y filas de composición ahora derivan fondos y textos del tema activo | Análisis focalizado sin errores; un aviso info preexistente por interpolación innecesaria en línea 82; QA visual claro/oscuro pendiente | 🟡 Implementada; validar formularios largos en móvil/tablet |
| Estado compartido — `lib/core/widgets/foody_estado_ui.dart` | Comunicar bloqueo de plan con acción para reactivar | La tarjeta, icono, texto y CTA derivan colores del `ColorScheme`; elimina superficie blanca/texto oscuro fijos en tema oscuro | Widget tests en tema claro y oscuro; análisis focalizado sin issues | ✅ Contraste dependiente del tema verificado |
| Menú admin — Productos — `lib/features/catalogo/presentation/menu_admin_screen.dart` | Buscar, filtrar disponibilidad/receta/margen, editar precios, cambiar disponibilidad, cocina, foto, toppings y costos | Tabla desde 1100 px; tarjetas en móvil/tablet; cambio de disponibilidad accesible, con progreso, bloqueo de doble envío y error reintentable; refresh conserva el listado | Menú widget 13/13, incluye error + reintento en 390 px y progreso en tabla 1440; analyzer limpio; Equipo Release publicado y JS Tunnel coincide por hash | 🟡 Responsive y alta básica verificados; edición, media, tema oscuro y sesión real pendientes |
| Menú admin — Toppings — `lib/features/catalogo/presentation/menu_admin_screen.dart` | Consultar precio, costeo/margen, ir a costos y activar/desactivar | Tabla compacta desde 1100 px; tarjetas en móvil/tablet; switch y acceso a Costos preservados | `dart format` + `dart analyze` focalizado sin incidencias; QA visual pendiente | 🟡 Implementada; formulario y estados globales pendientes |
| Menú admin — Bebidas — `lib/features/catalogo/presentation/menu_admin_screen.dart` | Consultar precio, costeo/margen e inventario visible; activar/desactivar bebida publicada | Tabla compacta desde 1100 px; tarjetas en móvil/tablet; switch y acceso a Costos preservados | `dart format` + `dart analyze` focalizado sin incidencias; QA visual pendiente | 🟡 Implementada; formulario y estados globales pendientes |
| Menú admin — Categorías — `lib/features/catalogo/presentation/menu_admin_screen.dart` | Consultar categorías y subir/cambiar imagen | Diálogo responsive compartido, filas con miniatura/estado de imagen y control explícito de carga | `dart format` + `dart analyze` focalizado sin incidencias; QA visual pendiente | 🟡 Implementada; formulario de alta y estados pendientes |
| Menú admin — Combos — `lib/features/catalogo/presentation/menu_admin_screen.dart` | Consultar precio fijo, contenido, disponibilidad y subir foto | Tabla desde 1100 px; tarjetas en móvil/tablet; acciones y disponibilidad preservadas | `dart format` + `dart analyze` focalizado sin incidencias; QA visual pendiente | 🟡 Implementada; formulario de creación y estados pendientes |
| Menú admin — asignación de cocina y toppings — `lib/features/catalogo/presentation/menu_admin_screen.dart` | Asignar estación de preparación y opciones visibles por plato | Diálogos responsivos del sistema Foody con contexto del producto, secciones agrupadas y contenido adaptable a scroll | `dart format` + `dart analyze` focalizado sin incidencias; QA visual pendiente | 🟡 Implementada; falta revisar accesibilidad y flujo visual completo |
| Menú admin — copiar menú — `lib/features/catalogo/presentation/menu_admin_screen.dart` | Seleccionar sede origen y entender el alcance de la copia | Diálogo Foody agrupado por sede origen; aclara qué entidades copia y que combos no se incluyen | `dart format` + `dart analyze` focalizado sin incidencias; QA visual pendiente | 🟡 Implementada |
| Facturación — listado — `lib/features/facturacion/presentation/facturacion_admin_screen.dart` | Revisar factura/cliente/fecha/total/estado y abrir acciones de pedido, vista previa, emitir o anular | Tabla en escritorio ≥1100 px; tarjetas en tablet/móvil; menú de acciones compartido y refresh conservado | `dart format` + `dart analyze` focalizado sin incidencias; QA visual pendiente | 🟡 Listado implementado |
| Facturación — config fiscal, vista previa y anulación — misma ruta | Editar datos fiscales internos; leer resumen; copiar HTML; introducir motivo de anulación | Formulario por secciones con tema activo, vista previa jerarquizada como comprobante y diálogo Foody con ayuda de motivo | `dart format` + `dart analyze` focalizado sin incidencias; QA visual claro/oscuro y tamaños pendientes | 🟡 Mejoradas; no se altera estado DIAN ni reglas fiscales |
| Checkout cliente — `lib/features/pedidos/presentation/checkout_screen.dart` | Definir canal, datos/contacto, domicilio, factura opcional, pago, promoción y confirmar pedido | Contenido limitado a 760 px en escritorio; barra final alineada; controles, tarjetas y campos siguen el tema actual; errores permanecen junto al flujo | `dart format` + `dart analyze` focalizado sin incidencias; QA visual móvil/escritorio y claro/oscuro pendiente | 🟡 Mejorado; cálculo y envío conservan el backend como autoridad |
| Carrito cliente — `lib/features/pedidos/presentation/carrito_screen.dart` | Ajustar cantidades, revisar extras/detalle, retirar líneas, vaciar y continuar | Lista y barra de total/CTA limitadas a 760 px en escritorio; app bar, tarjetas, stepper, detalle y barra inferior derivan color del tema; táctil móvil conservado | `dart format` + `dart analyze` focalizado sin incidencias; QA visual móvil/escritorio y claro/oscuro pendiente | 🟡 Mejorado; estado del carrito y gestos intactos |
| Domiciliarios — resumen de planta e independientes — `lib/features/domiciliarios/presentation/domiciliarios_admin_screen.dart` | Ver disponibilidad, ruta, saldos de planta, reglas de cobro y resumen de independientes | Se conserva separación escritorio/apilado; los resúmenes independientes usan filas-card compactas y distinguen comisión Foody del monto pendiente al repartidor. Etiquetas financieras en español; reglas de cobro muestran carga/error/reintento, y el resumen independiente separa error de lista vacía | `dart analyze` de pantalla/repositorio/tests sin incidencias; pruebas de contrato y pantalla pasan en 390, 820 y 1440 px, incluidos importes `numeric` enviados como cadenas. QA autenticado/theme oscuro pendiente | 🟡 Mejorada; normalización limitada a importes de esta respuesta en el repositorio |
| Inicio — centro de operación — `lib/features/admin/presentation/widgets/dashboard_resumen_widget.dart` | Leer KPIs de turno y revisar mesas, domicilios, inventario y alertas que necesitan atención | Indicadores con navegación muestran un icono de salida para comunicar que son interactivos; los paneles de atención se expanden/contraen con transición corta y respetan “reducir movimiento” | `dart analyze` focalizado sin incidencias; QA visual de movimiento reducido y tamaños pendiente | 🟡 Pulido de interacción; no modifica datos ni destinos existentes |
| Usuarios — `lib/features/usuarios/presentation/usuarios_admin_screen.dart` | Consultar equipo, roles, estaciones, estado y editar o activar/desactivar cuentas | Escritorio ≥1100 px usa tabla compacta; tablet/móvil usa tarjetas. Desactivar explica pérdida de acceso y requiere confirmar; reactivar es inmediato. Propietario sigue protegido | Suite widget 6/6: tabla/tarjetas 390/820/1440, confirmación/cancelación 390/1440 y alcance permiso; analyzer sin issues; Equipo Release publicado y JS público coincide por SHA-256 | 🟡 Mejorada; QA autenticado, tema oscuro y aceptación visual pendiente |
| Horarios — `lib/features/sucursales/presentation/horarios_admin_screen.dart` | Revisar resumen público, activar días y editar apertura/cierre | Diálogo de edición con contenido desplazable y altura limitada al viewport; selector horario se adapta a pantallas bajas/estrechas. Repositorio inyectable solo para prueba; UI mantiene las mismas llamadas | `dart analyze` limpio; widget tests abren ambos diálogos en 320×568 y 390×844 sin excepciones | 🟡 Mejorada; QA con teclado real, tema oscuro y sesión autenticada pendiente |
| Sedes — `lib/features/sucursales/presentation/sucursales_admin_screen.dart` | Administrar sucursales y marca pública | Formularios de marca/nueva/editar sucursal y vista previa de imagen limitados al viewport con desplazamiento vertical; repositorio inyectable para pruebas, servicios y flujos reales conservados | `dart analyze` limpio; widget test abre “Nueva sucursal” en 320×568 y 390×844 sin excepciones | 🟡 Mejorada; edición, teclado real, carga de imágenes, tema oscuro y sesión autenticada pendientes |
| Zonas de domicilio — `lib/features/zonas/presentation/zonas_admin_screen.dart` | Mantener anillos de precio/distancia y su cobertura geográfica | El formulario de anillo mantiene la selección/previsualización existente y limita el contenido a la ventana con desplazamiento; repositorio inyectable solo para test; mapa y reglas siguen iguales | `dart analyze` limpio; widget test abre creación en 320×568 y 390×844 sin excepciones | 🟡 Mejorada; mapa real, teclado, tema oscuro y sesión autenticada pendientes |
| Cocinas e impresoras — `lib/features/cocinas/presentation/cocinas_admin_screen.dart` | Administrar estaciones KDS e impresoras de red/USB/PDF | Diálogos limitados al viewport y desplazables; campos de tipo/cocina se expanden al ancho disponible y nombres largos se truncan sin desbordar; repositorio inyectable solo para test | `dart analyze` limpio; widget tests abren alta de cocina e impresora en 320×568 y 390×844 sin excepciones | 🟡 Mejorada; KDS en tiempo real, impresoras físicas, teclado y tema oscuro quedan fuera de esta verificación visual |
| Alertas — `lib/features/alertas/presentation/alertas_admin_screen.dart` | Filtrar riesgos, navegar al origen y marcar alertas revisadas | Tarjetas y badges semánticos conservan origen, gravedad, fecha y acción; repositorio inyectable únicamente para comprobar render responsive | `dart analyze` limpio; widget tests cubren una alerta larga en 320, 390, 820 y 1440 px | 🟡 Responsive probado con datos de prueba; sesión real, realtime, tema oscuro y acción de revisar pendientes |
| Finanzas — `lib/features/finanzas/presentation/finanzas_admin_screen.dart` | Revisar ingresos, gastos, nómina, rentabilidad y CRUD financiero | Alertas e insights respetan el ancho disponible; los cinco formularios usan el shell Foody y liberan controladores después de la transición; endpoints y cálculos conservados | `dart analyze` limpio; render vacío en 320/390/820/1440 y alta de gasto fijo/empleado en 320/390 (teclado simulado a 320). Edición/pago migrados pero no abiertos por prueba automatizada | 🟡 CRUD responsive cubierto parcialmente; datos reales, teclado físico, tema oscuro y sesión autenticada pendientes |
| Promociones — `lib/features/promociones/presentation/promociones_admin_screen.dart` | Crear historias de foto/video, enlazar productos y administrar publicaciones | Formulario de alta limitado al viewport y scrollable incluso al abrir teclado; menú vinculado se expande dentro del ancho disponible; repositorios inyectables solo para prueba | `dart analyze` limpio; widget tests abren el formulario en 320×568 y 390×844 | 🟡 Mejorada; selección/carga real de multimedia, teclado y tema oscuro pendientes |
| Reportes — `lib/features/reportes/presentation/reportes_admin_screen.dart` | Consultar reportes financieros, productos, pedidos y auditoría; exportar | El diseño existente usa pestañas scrollables y estados de carga/error; se agregan repositorios sustituibles para render aislado sin cambiar exportaciones | Prueba de render vacía en 320, 390, 820 y 1440 px pasó; análisis conserva cuatro avisos informativos preexistentes de `Share.shareXFiles` obsoleto | 🟡 Responsive básico cubierto; payload real, exportar/compartir, navegación de pestañas y tema oscuro pendientes |
| Costos y márgenes — `lib/features/costeo/presentation/costos_margenes_screen.dart` | Buscar productos, revisar costo/margen, administrar recetas y cambiar entre lista/detalle | Lista/master-detail se conserva; detalle reorganizado según referencia: producto destacado, secuencia de cinco pasos, grupos de receta plegables, acompañamientos y resumen financiero lateral en escritorio / al final en móvil. El buscador nombra los tipos reales de ítem y ofrece recuperación ante cero resultados. Mismo motor y contratos | `flutter analyze` focalizado limpio; `costeo_flujo_receta_test.dart` + `costos_margenes_screen_test.dart`: 10/10 en 320/390/820/1440, acordeón y recuperación de búsqueda | 🟡 Estructura implementada; falta recorrido autenticado de detalle/edición, guardado y recálculo; QA visual de formularios, tema oscuro y dispositivo físico pendiente |
| Inventario — alta/edición de insumo y subreceta — `dialogo_insumo_form.dart`, `dialogo_subreceta_form.dart` | Configurar compra/merma, costo, unidad, stock y composición de subreceta | El shell compartido permite scroll vertical de formulario completo; selectores se expanden y nombres largos se truncan | Widget tests Insumo/Subreceta abren en 320×568 y 390×844 con teclado simulado; análisis limpio | 🟡 Render básico probado; composición de líneas, modo lote y guardado real requieren QA manual |

#### Operación e interfaces administrativas

- **Caja.** El panel muestra las acciones junto al resumen cuando hay espacio y debajo de las métricas en una columna estrecha. Apertura, movimientos, fiados y acciones de turno usan superficies y texto del tema activo. El error usa el estado compartido con reintento.
- **Pedidos.** Las tarjetas y columnas del tablero adoptan el tema activo, incluidos el contador de pedidos y los estados vacíos por columna. Se conserva el flujo por pestañas y canales.
- **Menú.** La cabecera, las pestañas, los filtros, las tarjetas, las tablas y los controles de formulario usan colores del tema activo. La navegación y las acciones siguen conectadas a los flujos existentes.
- **Insumos.** Conteo y el listado de Subrecetas adaptan sus superficies al tema. Conteo indica dónde agregar insumos cuando todavía no se puede iniciar.
- **Administración.** Se migraron los colores neutros de Usuarios, Alertas, Horarios, Cocinas, Domiciliarios, Promociones, Reportes, Sedes, Zonas y Costos en sus vistas principales. Este pase cubre el tema visual. Aún falta la comprobación de tamaños, diálogos y estados por pantalla.

El análisis focalizado de las 17 unidades Dart pasó sin errores ni advertencias. Reportes conserva cuatro avisos preexistentes sobre la API para compartir archivos. En la API local se comprobó salud con BD conectada, acceso con la cuenta demo, sedes y Caja activa con HTTP 200, y rechazo sin sesión con HTTP 401 en la consulta de sedes.

La compilación web release de Equipo terminó en `build/qa_redisenio_equipo`. El navegador abrió el formulario local de acceso, pero el inicio de sesión demo quedó cargando sin mostrar el panel. El mismo inicio por HTTP al API del túnel devolvió 201 y permitió el origen local. Esto deja pendiente la comprobación visual autenticada.

Queda por cerrar la revisión visual de la oleada en móvil, tablet y escritorio, incluidas las vistas operativas por rol, los formularios de Insumos, las pantallas de cliente fuera de Carrito y Checkout y el panel de plataforma. El entorno de referencia sigue siendo `MODO=tunel`.

#### Panel del restaurante, navegación y carga

- Barra superior con nombre de sección, contexto de grupo o sede, menú de cuenta y acciones agrupadas en móvil. El selector de sedes admite nombres largos y muestra el cambio en curso.
- Barra lateral plegable en escritorio con acento Foody en la selección. El menú móvil cierra tras abrir una sección. Los accesos del Inicio siguen la misma ruta que la barra lateral.
- Entrada breve por sección y estados de carga adaptados al tema. La preferencia de reducir movimiento elimina la transición y el efecto de brillo. Los estados compartidos de carga, error y vacío usan colores del tema.
- Búsqueda disponible desde que abre el diálogo. Pedidos y mesas se consultan por separado para conservar los resultados que sí llegaron ante un error parcial.
- Salón, Punto de venta, Cocina, Análisis y Plan y pagos adoptan colores del tema en las vistas principales. El cuadro compartido de formularios se adapta al espacio disponible y permite desplazar el título y el contenido.
- Los diálogos que usan `FoodyDialogo` recogen el tema y tienen una entrada y salida breves, con opción de reducir movimiento. En Usuarios, los formularios permiten desplazar su contenido en móvil y muestran nombres legibles para los permisos.
- El registro de notificaciones continúa en segundo plano después del acceso. Al cerrar sesión se acota la espera del token de notificaciones. El ingreso habitual va a Inicio y el retorno con pago pendiente conserva su ruta específica.

Pruebas observadas en la compilación local de Equipo con cuenta demo: encabezado accesible de las 23 rutas del catálogo, plegado de la barra lateral, búsqueda de Caja, datos de Caja en modo oscuro, cierre al formulario, nuevo ingreso a Inicio, acceso a Configuración desde el menú a 390 px y barra de navegación reducida a 820 px. Las consultas de Dashboard, Reportes, Análisis y listados pasaron. El chequeo del ranking ahora reconoce un periodo sin ventas cuando ambas fuentes están vacías. Con la cuenta Pro, Facturación respondió HTTP 403 según la restricción Enterprise. El análisis de `lib` reportó cero errores y advertencias y 66 avisos informativos.

La cobertura de pantallas se complementó con escrituras de Caja, Inventario, Facturación interna y Foody Control en una base aislada. Queda por completar la revisión de combinaciones de tema, tamaño y rol para formularios secundarios.

La última compilación local verificó el diálogo Nuevo usuario en tema oscuro a 390 px y su cancelación. El control de Mesas ahora rechaza un identificador de sede mal formado antes de consultar datos. Nest compiló y el controlador ejecutado en una instancia aislada respondió 400 al dato inválido y 200 al válido. La API del túnel no se reinició durante la prueba.

#### Diálogos operativos y plataforma

- Caja, Inventario, Menú, Facturación, Finanzas, Pedidos, Promociones y Foody Control reutilizan presentación y movimiento de `FoodyDialogo`. Las hojas modales usan el color y el borde superior del tema base.
- El conteo mantiene el formulario abierto cuando una cantidad está vacía o es inválida. El fiado señala los campos incompletos. La anulación de factura conserva el motivo en el formulario hasta que tenga la longitud requerida.
- Foody Control usa la barra y navegación adaptadas al ancho, con selección anunciada, transición de sección, carga y soporte para reducir movimiento. El formulario de alta de restaurante muestra errores antes de salir y solicita una contraseña inicial.
- El esquema de color comparte una escala neutra para superficies, bordes y texto en ambos temas. Los esqueletos de sección mantienen la altura prevista en paneles que ocupan toda la pantalla.
- Confirmado en navegador: validación y cancelación de fiado, apertura y cancelación de cobro, validación y cancelación del conteo, ingreso y navegación por las siete secciones de plataforma, apertura y cancelación del alta de restaurante en oscuro a 390 px. En la última compilación también se comprobó que la contraseña del alta empieza vacía y que enviar los campos vacíos mantiene abierto el formulario. En la API activa, la cuenta super admin recibió HTTP 200 en estadísticas, restaurantes, usuarios, ciudades y configuración. Mesas respondió 400 para una sede inválida y 200 para una válida.
- En una base aislada con datos sintéticos se verificaron apertura y cobro, rechazo de reapertura de pedidos pagados, alta y cobro de fiado, conteo y actualización de existencias, alta de restaurante y cajero, y rechazo de acceso entre dos restaurantes.
- Facturación Enterprise se verificó en navegador contra esa base. Guardar configuración y anular con motivo actualizan y persisten los datos. La vista previa mostró el estado y los importes. La API rechazó emitir antes de cobrar, emitió después del cobro y mantuvo el pedido pagado al anular la factura. DIAN sigue pausado.
- El alta de personal en Foody Control empieza con la contraseña vacía, muestra errores por campo y carga las sedes del restaurante elegido. Se verificaron en navegador la falta de contraseña, el intento de envío vacío y la cancelación. El alta con datos sintéticos se comprobó por API.

---

> **Rol:** Senior Product Designer · Flutter  
> **Alcance:** 40 pantallas en `lib/features/` + widgets compartidos  
> **Última actualización:** 2026-07-02  
> **Referencias benchmark:** Uber Eats · Toast POS · Square · Shopify · Rappi · Notion · Linear

---

## Resumen ejecutivo

| Dimensión | Nota global | Veredicto |
|-----------|:-----------:|-----------|
| Jerarquía visual | 5.5/10 | Mezcla 3 lenguajes (cliente delivery, operación slate, Material genérico) |
| Espaciado | 5/10 | Sin escala 4/8/16/24 unificada; padding ad hoc por pantalla |
| Tipografía | 5/10 | Poppins+Inter definidos en tema pero **no aplicados** en la mayoría de `TextStyle` inline |
| Colores / marca | 6/10 | Paleta Foody existe; **~90+ hex sueltos** compiten con `ColoresFoody` |
| Contraste | 6.5/10 | KDS/sidebar bien; cliente gris sobre gris en secundarios |
| Componentes | 5/10 | `OperacionUi` solo en ~5 módulos operativos; resto `Card`+`ListTile` crudo |
| Consistencia | **4.5/10** | Principal deuda visual del producto |
| Identidad Foody | 5/10 | Naranja presente pero splash/logo legacy «Tu Cancha Fácil» |

**Nota media pantallas:** **5.8 / 10** — Funcional y usable en operación; **no compite visualmente** con Uber Eats/Rappi en cliente ni con Toast/Linear en admin.

---

## Diagnóstico del sistema de diseño actual

### Lo que existe

| Activo | Ubicación | Estado |
|--------|-----------|--------|
| Paleta marca | `lib/core/constantes/colores_foody.dart` | ✅ 9 tokens |
| Tema M3 | `lib/core/tema/tema_foody.dart` | 🟡 Mínimo (AppBar naranja, 2 estilos texto) |
| Tokens operación | `operacion_ui.dart` | ✅ Slate + chips estado (estilo Linear/Toast) |
| Sidebar admin | `panel_sidebar_nav.dart` | ✅ Oscuro `#0F172A` (Notion/Linear) |
| Sidebar super | `foody_control_ui.dart` | 🟡 Similar pero duplicado |

### Problemas transversales

1. **Dos productos visuales en uno**
   - **Cliente:** fondos `#F3F4F6`, botones `#111624`, chips Material — cercano a Rappi/Uber pero **sin** fotografía hero, sin bottom sheet estándar, sin tipografía de marca.
   - **Staff:** slate oscuro + tarjetas blancas 12px radius — cercano a Toast/Linear en KDS/sidebar.
   - **Admin CRUD:** Material 2018 (`Card`, `ListTile`, `TabBar` naranja) — cercano a **panel genérico**, no Shopify.

2. **Tema global no gobierna**
   - `TemaFoody` no define: `elevatedButtonTheme`, `inputDecorationTheme`, `cardTheme`, `chipTheme`, `tabBarTheme`, `snackBarTheme`, espaciado.
   - Casi todo es `TextStyle(fontSize: 12, color: Colors.grey.shade600)` inline.

3. **Tipografía a medias**
   - `GoogleFonts` solo en `textTheme` base; pantallas no usan `Theme.of(context).textTheme`.
   - Pesos mezclados: `w600`, `w700`, `w800` sin escala (display / title / body / caption).

4. **Identidad diluida**
   - Splash: `assets/tucanchafacil.png` + fondo `fondo2.jpg` legacy.
   - Paquete `reserva_canchas` (deuda P3-05).
   - Secundario `#2EC4B6` y acento `#FFE66D` **casi ausentes** en UI.

5. **Diseños anticuados detectados**
   - `ListTile` + `Card` plano para listas cliente (2019).
   - `AppBar` naranja sólido en todo el flujo cliente (no estilo Uber Eats flat/blanco).
   - Formularios checkout largos sin secciones visuales (no Square/Shopify checkout).
   - Tab bars con 5–9 tabs sin sub-navegación (Inventario, Analítica).
   - Errores con texto técnico y bloques de párrafo (no empty state ilustrado).

6. **Exceso de texto**
   - Checkout, caja, mesa cobro, registro restaurante, super admin.
   - Subtítulos API (`slug`) visibles al usuario en ciudades.

7. **Mala alineación / distribución**
   - Dashboard: KPIs + gráficos sin grid responsive unificado.
   - Inventario: tablas anchas en móvil con scroll horizontal implícito.
   - Cliente carrito: trailing `Row` estrecho (íconos comprimidos).

---

## Benchmark — qué tomar de cada referencia

| Referencia | Aplicar en Foody | Pantallas objetivo |
|------------|------------------|-------------------|
| **Uber Eats / Rappi** | App bar blanca, categorías chip scroll, imágenes producto 16:9, carrito sticky inferior, sheets para modifiers | Menú, carrito, checkout |
| **Toast POS** | Botones grandes táctiles, estados color codificados, densidad alta pero **una acción primaria** por vista | Cajero, mesero, mesas, KDS |
| **Square** | Checkout en pasos, resumen pedido sticky, tipografía clara montos | Checkout, cobro mesa |
| **Shopify Admin** | Tablas limpias, filtros en toolbar, páginas con un CTA primario | Menú admin, inventario, usuarios |
| **Notion / Linear** | Sidebar oscuro, contenido blanco, bordes `1px #E2E8F0`, headers 16px semibold | Panel admin shell, listados |
| **Linear** | Chips estado pastel, barra acento 3px en tarjetas, spacing 12/16 | Kanban, mesas, alertas |

---

## Calificación por pantalla (1–10)

Escala: **1–4** anticuado · **5–6** aceptable MVP · **7–8** moderno usable · **9–10** referencia industria

### Cliente (`flavor cliente`)

| # | Pantalla | Archivo | Nota | Problemas clave | Mejora prioritaria |
|---|----------|---------|:----:|-----------------|-------------------|
| 1 | Splash | `foody_splash_screen.dart` | **5** | Logo legacy, tipografía genérica | Logo Foody + gradiente marca |
| 2 | Ciudades | `ciudades_screen_foody.dart` | **5** | ListTile plano, slug visible, AppBar naranja | Cards con imagen ciudad, ocultar slug |
| 3 | Restaurantes | `restaurantes_screen_foody.dart` | **6** | Stories bien; cards desiguales | Grid 2 col, rating/distancia, foto hero |
| 4 | Sucursales | `sucursales_screen_foody.dart` | **5** | Lista utilitaria | Card sede + ETA + «Abierto» chip |
| 5 | Menú | `menu_screen_foody.dart` | **7** | Mejor pantalla cliente; hex sueltos; error crudo | Unificar tokens; imágenes; sheet producto |
| 6 | Carrito | `carrito_screen.dart` | **4** | Mínima; sin +; ListTile 2019 | Barra inferior sticky Square; steppers |
| 7 | Checkout | `checkout_screen.dart` | **5** | Formulario largo; factura siempre visible | Steps 1-2-3; secciones colapsables |
| 8 | Seguimiento | `seguimiento_pedido_screen.dart` | **7** | Timeline claro; mezcla estilos | Ilustración estado; mapa domi más grande |
| 9 | Mis pedidos | `mis_pedidos_screen.dart` | **5** | Lista básica | Cards con reorder CTA (Rappi) |
| 10 | Entrada mesa QR | `mesa_qr_entrada_screen.dart` | **6** | Funcional | Animación bienvenida mesa |
| 11 | Escanear QR | `escanear_qr_mesa_screen.dart` | **6** | Estándar cámara | Marco escaneo branded |

**Media cliente: 5.7**

---

### Auth / onboarding

| # | Pantalla | Archivo | Nota | Problemas | Mejora |
|---|----------|---------|:----:|-----------|--------|
| 12 | Login staff | `staff_login_screen.dart` | **7** | Animaciones OK; split visual cliente/staff | Card centrada Linear; logo Foody |
| 13 | Registro restaurante | `restaurante_registro_screen.dart` | **6** | Form largo | Wizard 3 pasos Shopify |
| 14 | Registro domi | `domiciliario_registro_screen.dart` | **5** | Form estándar | Mismos tokens |
| 15 | Login domi | `domiciliario_independiente_login_screen.dart` | **5** | Básico | Igualar staff login |
| 16 | Espera domi | `domiciliario_registro_screen.dart` | **5** | Texto estático | Estado ilustrado |

**Media auth: 5.6**

---

### Admin — shell y operación

| # | Pantalla / módulo | Archivo | Nota | Problemas | Mejora |
|---|-------------------|---------|:----:|-----------|--------|
| 17 | Panel restaurante (shell) | `panel_restaurante_screen.dart` | **6** | Buen sidebar; contenido heterogéneo | Fondo `OperacionUi.fondoPagina` en todos los módulos |
| 18 | Sidebar nav | `panel_sidebar_nav.dart` | **8** | Referencia interna | Extraer a design system |
| 19 | Dashboard resumen | `dashboard_resumen_widget.dart` | **6** | KPIs no clicables | Cards métricas Shopify |
| 20 | Dashboard gráficos | `dashboard_graficos_widget.dart` | **6** | Charts OK; leyendas pequeñas | Paleta chart = marca |
| 21 | Dashboard consolidado | `dashboard_consolidado_widget.dart` | **6** | Denso | Grid 2×2 responsive |
| 22 | Pedidos kanban | `pedidos_kanban_widget.dart` | **7** | Chips OperacionUi | Columnas más anchas; drag handle |
| 23 | Mesas grid | `mesas_grid_widget.dart` | **7** | Operativo Toast-like | Unificar con mesero/cajero |
| 24 | KDS cocina | `kds_screen.dart` | **8** | Mejor pantalla staff | Tipografía mono para tiempos |
| 25 | POS cajero | `pedido_cajero_screen.dart` | **6** | OperacionUi parcial | Teclado numérico Square |
| 26 | Panel cajero | `panel_cajero_screen.dart` | **6** | Tabs funcionales | Tab bar inferior móvil Toast |
| 27 | Panel mesero | `panel_mesero_screen.dart` | **6** | Similar cajero | Misma shell operación |
| 28 | Mesa pedidos sheet | `mesa_pedidos_sheet.dart` | **6** | Mucha info | Tabs dentro sheet |

**Media operación: 6.6**

---

### Admin — back-office (CRUD)

| # | Pantalla | Archivo | Nota | Problemas | Mejora |
|---|----------|---------|:----:|-----------|--------|
| 29 | Menú admin | `menu_admin_screen.dart` | **5** | Tabla densa | Shopify table + drawer detalle |
| 30 | Inventario | `inventario_admin_screen.dart` | **4** | 5 tabs visibles en escritorio; selector compacto ya existe en móvil | Agrupar áreas por flujo y evaluar sub-nav lateral en escritorio; revisar visualmente móvil/tablet |
| 31 | Caja | `caja_admin_screen.dart` | **6** | Mezcla OperacionUi | Resumen caja hero card |
| 32 | Cocinas config | `cocinas_admin_screen.dart` | **5** | CRUD básico | Lista + empty states |
| 33 | Analítica | `analitica_screen.dart` | **6** | 8–9 tabs | Dropdown métricas; menos tabs |
| 34 | Reportes | `reportes_admin_screen.dart` | **5** | Utilitario | Cards descargables |
| 35 | Facturación | `facturacion_admin_screen.dart` | **4** | Borrador HTML crudo | Preview card; DIAN pausada |
| 36 | Usuarios | `usuarios_admin_screen.dart` | **5** | Tabla | Avatar + rol chip |
| 37 | Alertas | `alertas_admin_screen.dart` | **5** | Lista | Severidad color + icono |
| 38 | Promociones | `promociones_admin_screen.dart` | **6** | Stories creativo | Mantener; pulir forms |
| 39 | Zonas domicilio | `zonas_admin_screen.dart` | **5** | Mapa+form | Mapa full bleed |
| 40 | Horarios | `horarios_admin_screen.dart` | **5** | Grid horas | Week view calendario |
| 41 | Sucursales | `sucursales_admin_screen.dart` | **5** | Lista | Cards sede |
| 42 | Costeo | `costos_margenes_screen.dart` | **6** | `costeo_ui_bloques` | Extender bloques a inventario |
| 43 | Domiciliarios admin | `domiciliarios_admin_screen.dart` | **5** | Denso | Kanban asignación |
| 44 | Mejorar plan | `mejorar_plan_screen.dart` | **7** | Paywall claro | Referencia para otros módulos |

**Media back-office: 5.3**

---

### Super admin y domi campo

| # | Pantalla | Archivo | Nota | Problemas | Mejora |
|---|----------|---------|:----:|-----------|--------|
| 45 | Foody Control | `panel_foody_control_screen.dart` | **6** | 7 secciones densas | Wizard restaurante |
| 46 | Dashboard domi planta | `dashboard_domiciliario_screen.dart` | **6** | Operativo | Mapa más prominente |
| 47 | Dashboard repartidor | `dashboard_domiciliario_independiente_screen.dart` | **6** | GPS chip OK | Bottom nav 3 ítems |
| 48 | Documentos domi | `domiciliario_documentos_screen.dart` | **5** | Upload básico | Progress steps |

**Media super/domi: 5.8**

---

## Tabla resumen por grupo

| Grupo | Pantallas | Media |
|-------|----------:|------:|
| Cliente | 11 | **5.7** |
| Auth / onboarding | 5 | **5.6** |
| Operación (POS/KDS/mesas) | 12 | **6.6** |
| Back-office CRUD | 16 | **5.3** |
| Super / domi campo | 4 | **5.8** |
| **Total** | **48** | **5.8** |

---

## Propuesta: Design System Foody (Fase 6)

### Tokens a formalizar (`lib/core/tema/`)

```
Espaciado: 4, 8, 12, 16, 24, 32, 48
Radius: 8 (chip), 12 (card), 16 (sheet), 24 (modal)
Tipografía:
  display: Poppins 28/32 w700
  title:   Poppins 18/22 w600
  body:    Inter 14/20 w400
  caption: Inter 12/16 w400 muted
Sombras: 0 1px 3px rgba(15,23,42,.08) — estilo Linear
```

### Componentes a extraer (1 por patrón)

| Componente | Inspiración | Reemplaza |
|------------|-------------|-----------|
| `FoodyScaffoldCliente` | Uber Eats | AppBar blanca + body gris |
| `FoodyProductCard` | Rappi | ListTile menú |
| `FoodyStickyBottomBar` | Square | FAB + bottom checkout |
| `FoodyOperacionScaffold` | Toast | Fondo slate + header |
| `FoodyDataTable` | Shopify | Listas admin |
| `FoodyEmptyState` | Linear | Texto centrado |
| `FoodyStatusChip` | OperacionUi | Chips ad hoc |
| `FoodySectionHeader` | Notion | Títulos inline |

### Roadmap visual (prioridad)

| ID | Mejora | Impacto | Esfuerzo |
|----|--------|---------|----------|
| DS-01 | Extender `TemaFoody` (buttons, inputs, cards, chips) | Alto | M |
| DS-02 | Cliente: menú + carrito + checkout (Uber/Square) | Alto | L |
| DS-03 | Migrar admin CRUD a `OperacionUi` + `FoodyDataTable` | Alto | L |
| DS-04 | Splash + logo Foody (quitar legacy) | Medio | S |
| DS-05 | Unificar fondos cliente (`ColoresFoody` vs `#F3F4F6`) | Medio | S |
| DS-06 | Empty/error states ilustrados | Medio | M |
| DS-07 | Usar secundario/acento en CTAs secundarios | Bajo | S |
| DS-08 | Tab bars → sub-nav o drawer (inventario/analítica) | Alto | M |

Detalle en **`FRONTEND_ROADMAP.md` Fase 6**.

---

## Pantallas referencia (objetivo interno 8+/10)

Usar como **plantilla** al rediseñar otras:

1. **KDS** (`kds_screen.dart`) — contraste, foco, acción clara  
2. **Sidebar admin** (`panel_sidebar_nav.dart`) — jerarquía, oscuro, compacto  
3. **Menú cliente** (`menu_screen_foody.dart`) — base Rappi (falta pulir)  
4. **Kanban pedidos** — chips y tarjetas OperacionUi  

---

## Relación con otros docs

| Doc | Relación |
|-----|----------|
| `FRONTEND_UX_AUDITORIA.md` | Fricción flujo (complementa esta auditoría visual) |
| `FRONTEND_FRICTION_FIXES.md` | Quick fixes UX |
| `FRONTEND_ROADMAP.md` | Fases implementación |
| `FRONTEND_INSTRUCCIONES.md` | INS-005 auditoría visual |

---

*Próxima revisión: tras Fase 6 DS-01 (tema extendido) — recalificar pantallas cliente y admin CRUD.*

---

## Continuidad de implementación visual — 2026-11-22

### Trabajo de esta tanda

- Menú y Costos: listas y diálogos sensibles al ancho, textos largos y selectores; repositorios inyectables para probar presentación sin tocar API.
- Inventario: campos desplegables expansibles; shell común de diálogo ahora limita tamaño y desplaza título, formulario y acciones juntos. Se eliminó la medición intrínseca que chocaba con `LayoutBuilder` y causaba overflow en subrecetas/teclado.
- Facturación: vista vacía probada en 320/390/820/1440 y listado con tarjeta en móvil y tabla horizontal en escritorio.
- Caja: repositorio inyectable para pruebas visuales; apertura verificada en 320×640, 390×844, 820×900 y 1440×900.
- Pedido/Kanban: tarjeta con dirección, nombre, productos y acción verificada a 280/320/390/820/1440. Se detectó y corrigió el desbordamiento del pie; el número se trunca para mantener tiempo y total visibles.
- Tablero Pedidos: estado vacío y tarjeta activa probados a 320/390/820/1440; vista columnas comprobada en tablet/escritorio. Se corrigió la etiqueta duplicada “Mesa Mesa 4” cuando el nombre ya incluía el tipo.
- Detalle de pedido: flujo modal comprobado con domicilio, metadatos largos, producto/observaciones largos y acceso desplazable a Acciones en 320/390/820/1440. Repositorio opcional agregado solo para pruebas. No se ejecutaron cobros/cancelaciones.
- Asignación de mesero: límite de altura en escritorio, contenido desplazable y botones adaptables con Wrap; probado con pedido/mesero de muestra en 320×568, 390×844, 820×600 y 1440×700.
- Cobro de Mesa: la prueba interactiva detectó un overflow de 18 px en el diálogo a 320 px; selectores de método de pago ahora se expanden al ancho disponible. Diálogo probado en 320/390/820/1440, teclado simulado a 320; no se confirmó ningún cobro.
- Unión de mesas: lista de selección limitada y desplazable, nombres largos truncados a dos líneas; abrir/cancelar probado a 320×568 y 390×844 sin enviar cambios.
- Reserva: migrada al shell común de formulario; el shell ahora descuenta el inset del teclado y respeta un margen vertical. Formulario probado en 320×568 con teclado simulado, tras corregir el espacio vertical reducido en la grilla inferior.
- QR de mesa: cuadro con alto máximo calculado desde ventana/teclado y contenido desplazable; se corrigió overflow de 72 px, probado a 320×568 con QR sintético. La generación/impresión PDF no se ejecutó.
- Opciones avanzadas de Mesa/CxC: se detectó overflow de 185 px al expandir “Opciones avanzadas” en el pie fijo; la sección tiene ahora scroll y alto máximo. El diálogo “Cliente salió sin pagar” se abrió y canceló a 320×568 sin registrar CxC.
- Menú admin: vista de precios (canales local/para llevar) abierta y comprobada en 320/390/820/1440 con producto sintético. No se guardó ningún cambio ni se probaron fotos.
- KDS: pantalla vacía y ticket activo con datos/textos largos y controles comprobados a 320/390/820/1440 px cuando Supabase Realtime no está listo; un desbordamiento de la pestaña Cocina fue corregido. La carga ya continúa con polling de respaldo si la suscripción opcional no se crea.
- Mesas: la grilla ahora calcula columnas con el ancho disponible real del panel (no con el ancho global del dispositivo); se comprobó en 320 px y en tablet de 820 px con contenido reducido a 520 px por la navegación lateral. El detalle de cuenta/mesa usa tokens dependientes del tema y se probó en claro/oscuro a 320×568 y 390×844.
- Menú, Costos, Insumo y Subreceta mantienen pruebas widget focalizadas; formularios de insumo/subreceta incluyen inset de teclado simulado.

### Verificación

- `flutter test`: Caja (4 tamaños), Facturación (4 tamaños + lista móvil/escritorio), tarjeta/tablero Pedido (5/4 tamaños), detalle Pedido y asignación mesero (4 tamaños cada uno), Menú (vista vacía, alta y diálogo precios en 4 tamaños), KDS (estado vacío y ticket activo, 4 tamaños sin Realtime), grilla Mesas (móvil y panel estrecho en tablet), detalle Mesa (claro/oscuro 320×568 y 390×844), Costos, Insumo y Subreceta: aprobadas.
- `dart analyze` focalizado en Caja, Facturación, tarjeta Pedido y KDS: limpio; Mesa conserva avisos previos de `DropdownButtonFormField.value`, bloque `if` sin llaves y uso de contexto tras async; Inventario/Subreceta mantiene un info previo de interpolación innecesariamente entre llaves.
- Pendiente: QA visual manual en Chrome con sesión autenticada, ambos temas, permisos/roles reales, tablet/dispositivo físico, flujos con datos reales y comprobación integral de animaciones/transiciones.

### Alcance global

La finalización del rediseño global todavía está en curso. Esta oleada añade una base visual responsive compartida y un primer refinamiento de los KPIs reales del Centro de Operación; no sustituye la adaptación individual de las pantallas pendientes. En Pedidos/Kanban se probaron estado vacío, tarjeta, cambio de vista, detalle y asignación; faltan acciones reales autenticadas. En Mesas se cubren grilla, detalle, cobro, unión, reserva, QR, CxC, alta/renombre y diálogos adaptados; faltan operaciones reales autenticadas. Finanzas cubre render adaptable y altas de gasto fijo/empleado; edición y pago requieren QA interactiva. Falta QA del KDS con sesión/Realtime/datos. También faltan estados secundarios y QA visual manual autenticada por rol/tema/ancho. La suite UI actual pasó: 112 pruebas aprobadas y 5 E2E de API omitidas por defecto; una ejecución previa contra la API activa falló cuatro aserciones de contrato y dejó un único pedido sintético de QA cancelado, por lo que esos E2E quedan pendientes de repetición en una BD aislada. El análisis focalizado del Centro de Operación no encontró issues. El bundle web release compiló para cliente/Equipo; el dry-run Wasm señala incompatibilidades en dependencias existentes que no bloquean el build estándar. El CLI Impeccable no está disponible en PATH para repetir `detect` en esta sesión. Las vistas de cliente y repartidor no quedan cubiertas por esta oleada del panel admin. No presentar esta tanda como cierre general.

## Continuidad — diálogos y cuenta de Mesas — 2026-11-23

- Crear/renombrar/desactivar, transferir pedido, asignación de turno y rechazo QR migran al shell `FoodyDialogoShell` donde corresponde; transferir limita la lista y recorta nombres largos. Alta y renombre conservan explícitamente su contenido scrollable al abrir teclado.
- En detalle de mesa, eliminar ítem, forzar cierre por cocina incompleta, registrar CxC y asignar comensal usan el mismo shell adaptable. El cobro mantiene su diálogo operativo scrollable y acciones apilables.
- Pruebas nuevas abren alta y renombre a 320/390 px con teclado simulado; Mesa/CxC, QR, unión, cobro y detalle continúan cubiertos por widget tests.
- Se reprodujo un ciclo de vida defectuoso: liberar `TextEditingController` inmediatamente después de `Navigator.pop` permite que la animación inversa del diálogo intente volver a escuchar un controlador ya dispuesto. La liberación se difiere 200 ms, después de la transición de cierre.
- `dart analyze` focalizado y tests `mesas_grid_widget_test.dart` + `mesa_pedidos_sheet_test.dart`: aprobados. Sin cambios de API/reglas/operaciones financieras ni túnel.
- Alcance restante: probar transferencia, asignación/rechazo y escrituras reales en sesión autenticada; revisar formularios y estados no cubiertos de otros módulos; validar ambos temas, roles y navegador/dispositivo. El rediseño global sigue abierto.

### 2026-11-24 — navegación compacta de Analítica validada

La pantalla reemplaza la fila de 8–10 tabs por un selector de secciones bajo 720 px, conservando TabBar en escritorio y sincronizando índice/permisos con el mismo TabController. Widgets 4/4 (`analitica_screen_progressive_load_test.dart`), incluidas vistas de 390 y 1440 px. F4-03 queda cerrado; la sub-nav para Inventario sigue pendiente. El screenshot autenticado continúa pendiente porque Chrome está en login.

## Inspección de Chrome por Tunnel — 2026-11-25

Costos y márgenes se revisó en escritorio (1920×1080) y ventana compacta (~500 px): detalle en desktop distribuye producto/receta y resumen en columnas; en compact muestra el menú como navegación móvil y editor de receta apilado/scrollable. En los datos visibles hay un producto `cerso asado` con una imagen que es captura de un login y sin receta; esto es una anomalía del catálogo mostrado, no un error visual de carga (la imagen carga), y no se editaron datos. En Pedidos desktop el Kanban tiene jerarquía compacta y filtros claros. En ventana compacta las chips de estados mantienen una fila horizontal con fade, aunque el primer chip siguiente queda parcialmente cortado; falta affordance más explícito para scroll horizontal y prueba táctil en dispositivo. Sin operaciones ni mutaciones de pedidos.

**Seguimiento UI-PEDIDOS-STATE-SCROLL-01 (26-nov-2026):** se añadió una flecha circular de 48 px, con tooltip/semántica “Ver más estados”, y desplazamiento suave de aproximadamente 72% del ancho visible. Aparece en viewport móvil (<600 px), junto al fade existente. El wrapper visual queda estable cuando se oculta la flecha para no resetear el desplazamiento. La suite pasa 12/12; 320/390/820/1440 mantienen interacción/layout y el test de “Cerrados” navega con flecha, luego comprueba error y reintento. Prueba de dispositivo físico pendiente.
