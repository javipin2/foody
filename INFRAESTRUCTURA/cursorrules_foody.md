# .cursorrules — Foody
## Archivo de contexto global para Cursor AI

Pega este contenido en un archivo llamado `.cursorrules` en la raíz de cada proyecto (backend y Flutter).

---

```
# PROYECTO: FOODY
# Sistema POS SaaS para restaurantes — LATAM

## QUIÉN SOY Y QUÉ ESTOY CONSTRUYENDO
Estoy desarrollando Foody, una plataforma SaaS centralizada donde múltiples
restaurantes se registran y gestionan sus operaciones. Es un sistema POS completo
con menú digital, pedidos por QR, gestión de cocinas, impresión automática,
inventario inteligente, caja, facturación electrónica DIAN y sistema de
domiciliarios independientes.

## STACK TECNOLÓGICO — NO CAMBIAR NI SUGERIR ALTERNATIVAS
- Frontend/Mobile: Flutter (Dart) — una sola base de código para todas las apps
- Backend: Node.js con NestJS + TypeScript
- Base de datos: PostgreSQL via Supabase self-hosted
- Auth: Supabase Auth (solo para usuarios internos — admins, cajeros, meseros, cocinas, domiciliarios)
- Storage: Supabase Storage (imágenes, documentos, PDFs)
- Tiempo real: Supabase Realtime (canales por sucursal)
- Push notifications: Firebase Cloud Messaging (FCM)
- Impresión: Servidor Python local por WebSocket en cada negocio
- Contenedores: Docker + Docker Compose
- VPS: Ubuntu 22.04

## IDIOMA DEL CÓDIGO
- Variables, funciones, clases, métodos: español
- Nombres de tablas y columnas en BD: español con snake_case
- Comentarios: español
- Mensajes de error al cliente: español
- Logs internos del servidor: español
- Commits: español

## CONVENCIONES FLUTTER
- Estado global: Riverpod
- HTTP: Dio con interceptores para auth
- Navegación: GoRouter
- Modelos: clases con fromJson/toJson
- Carpeta de cada feature: /lib/features/[nombre_feature]/
  - data/ (repositorios, fuentes de datos)
  - domain/ (modelos, casos de uso)
  - presentation/ (pantallas, widgets, providers)
- Widgets reutilizables en: /lib/shared/widgets/
- Constantes en: /lib/core/constantes/
- Temas en: /lib/core/tema/

## CONVENCIONES NESTJS BACKEND
- Módulo por cada dominio (pedidos, productos, caja, inventario, etc.)
- Controllers solo reciben y delegan — sin lógica de negocio
- Services contienen toda la lógica de negocio
- Toda operación crítica (confirmar pedido, descontar stock, registrar caja)
  ocurre en transacciones PostgreSQL con BEGIN/COMMIT/ROLLBACK
- Guards para autenticación y roles en cada endpoint
- DTOs con class-validator para validar entradas
- Responses siempre con estructura: { exito: boolean, datos: any, mensaje: string }
- Errores siempre con estructura: { exito: false, error: string, codigo: string }

## REGLAS CRÍTICAS — NUNCA VIOLAR
1. Flutter NUNCA calcula totales, precios, descuentos ni IVA. Solo el backend.
2. Flutter NUNCA escribe directamente a Supabase saltándose el backend (excepto Storage para imágenes).
3. Toda operación financiera ocurre en una transacción PostgreSQL atómica.
4. Los clientes consumidores NO tienen login. Se identifican por device_id (UUID local).
5. El stock NUNCA se descuenta desde Flutter. Solo el backend en transacción.
6. Las impresoras NUNCA reciben órdenes desde Flutter. Solo el servidor Python local.
7. Supabase Realtime es solo para escuchar cambios. Las escrituras van por el backend.
8. Cada tabla tiene sucursal_id. NUNCA omitirlo en queries.
9. auditoria_logs NUNCA se modifica ni elimina. Solo INSERT.
10. Los precios en pedido_items se guardan al momento del pedido, no se referencian del producto.

## ESTILO VISUAL FOODY
- Estilo: vibrante y colorido, similar a Rappi
- Color primario: #FF6B35 (naranja vibrante)
- Color secundario: #2EC4B6 (turquesa)
- Color acento: #FFE66D (amarillo)
- Fondo claro: #FAFAFA
- Texto principal: #1A1A2E
- Error: #E63946
- Éxito: #2DC653
- Tipografía: Poppins (títulos), Inter (cuerpo)
- Bordes redondeados: 12px estándar, 20px para cards principales
- Sombras suaves, cards con elevación
- Imágenes de productos con aspect ratio 16:9 o cuadradas con bordes redondeados
- Animaciones suaves (300ms), no exageradas

## ARQUITECTURA DE APPS (todas en Flutter, diferentes entry points)
1. foody_cliente — App pública. Sin login. Menú, carrito, pedidos, seguimiento.
2. foody_admin — Panel administrativo. Con login. Todo el sistema de gestión.
3. foody_cocina — Pantalla de cocina. Con login. Solo tickets de su cocina.
4. foody_domiciliario — App de repartidores independientes. Con login propio.

## NOMBRE DE LA APP
Foody — con logo naranja vibrante.

## MODELO DE NEGOCIO
Suscripción mensual fija por restaurante (no por sucursal).
Los domiciliarios independientes generan comisión por entrega adicional.
IVA incluido en precios del menú. El cliente ve precio final, sin desglose en menú.
El desglose de IVA solo aparece en la factura electrónica cuando el cliente la solicita.
```
