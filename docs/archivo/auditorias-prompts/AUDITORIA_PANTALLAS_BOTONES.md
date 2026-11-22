# Auditoría pantallas → API → BD → Realtime

**Última actualización:** 2026-07-02 — Cierre huecos auditoría (Ir a cliente, delete cocina/impresora, subrecetas).

## Resumen ejecutivo

| Categoría | Estado |
|-----------|--------|
| Botones → API NestJS | ~98% conectados |
| Botones muertos (`onPressed: () {}`) | 0 en `lib/features/` |
| Navegación rota flavor equipo | **Corregido** (`AbrirAppCliente`) |
| APIs sin UI | **Corregido** delete cocina/impresora, recalcular subreceta, historial producciones |
| Legacy Firestore | Fuera de `lib/features/` (no afecta Foody) |

## Verificación rápida

```powershell
.\scripts\verificar-cierre-sin-vps.ps1 -SinDocker
flutter analyze lib/core/navegacion/abrir_app_cliente.dart lib/features/cocinas/presentation/cocinas_admin_screen.dart lib/features/inventario/presentation/inventario_admin_screen.dart
```

## Fix aplicados (2026-07-02)

| Hallazgo | Solución |
|----------|----------|
| «Ir a cliente» en app equipo redirigía a login | `AbrirAppCliente` abre `Configuracion.urlAppCliente` (web dev: `localhost:8081`) |
| Back en login staff en equipo | Oculto (entrada natural es login) |
| Sin UI `DELETE /cocinas`, `/impresoras` | Botón eliminar en `cocinas_admin_screen` |
| Sin UI recalcular subreceta | Icono calcular → `POST /costeo/subrecetas/:id/recalcular` |
| Sin UI historial producciones | Icono historial → `GET /costeo/producciones/:sucursalId` |

## Arquitectura

```
Pantalla → Repository (Dio) → NestJS Service → PostgreSQL
                              ↘ RealtimeBroadcast → Supabase WS → Flutter FoodyRealtime
```

## Rutas GoRouter (22)

| Ruta | Pantalla | Rol |
|------|----------|-----|
| `/splash` | `foody_splash_screen` | Cliente |
| `/cliente` | `ciudades_screen_foody` | Cliente |
| `/cliente/escanear-qr` | `escanear_qr_mesa_screen` | Cliente |
| `/cliente/mis-pedidos` | `mis_pedidos_screen` | Cliente |
| `/ciudades/:slug/restaurantes` | `restaurantes_screen_foody` | Cliente |
| `/restaurantes/:id/sucursales` | `sucursales_screen_foody` | Cliente |
| `/mesa/:qrToken` | `mesa_qr_entrada_screen` | Cliente mesa |
| `/menu/:sucursalId` | `menu_screen_foody` | Cliente |
| `/carrito/:sucursalId` | `carrito_screen` | Cliente |
| `/checkout/:sucursalId` | `checkout_screen` | Cliente |
| `/pedidos/:id/seguimiento` | `seguimiento_pedido_screen` | Cliente |
| `/admin/login` | `staff_login_screen` | Staff |
| `/admin/registro` | `restaurante_registro_screen` | Onboarding |
| `/admin/panel` | `panel_restaurante_screen` (+ subsecciones) | Admin/gerente |
| `/admin/cajero` | `panel_cajero_screen` | Cajero |
| `/admin/mesero` | `panel_mesero_screen` | Mesero |
| `/admin/cocina` | `kds_screen` | Cocina |
| `/admin/domiciliario` | `dashboard_domiciliario_screen` | Domi planta |
| `/admin/foody-control` | `panel_foody_control_screen` | Super admin |
| `/domiciliario/login` | `domiciliario_independiente_login_screen` | Repartidor |
| `/domiciliario/registro` | `domiciliario_registro_screen` | Repartidor |
| `/domiciliario/documentos` | `domiciliario_documentos_screen` | Repartidor |
| `/domiciliario/independiente` | `dashboard_domiciliario_independiente_screen` | Repartidor |

Subsecciones panel (`?seccion=`): `dashboard`, `pedidos`, `nuevo_pedido`, `mesas`, `caja`, `menu`, `cocinas`, `cocina_kds`, `zonas`, `horarios`, `domiciliarios`, `promociones`, `sucursales`, `inventario`, `costos_margenes`, `reportes`, `analitica`, `facturacion`, `alertas`, `usuarios`, `mejorar_plan`.

## Flujo cliente — acciones principales

| Acción | API | Tablas | Realtime |
|--------|-----|--------|----------|
| Listar ciudades | `GET /ciudades` | R `ciudades` | — |
| Menú | `GET /menu/:sucursalId` | R catálogo | Escucha `catalogo_disponibilidad` |
| Cotizar domicilio | `GET /zonas/cotizar-domicilio` | R `zonas_cobertura` | — |
| Crear pedido | `POST /pedidos` | W `pedidos`, items, stock | `pedido_actualizado`, `estado_actualizado`, `mesas_actualizadas`, `cocina_actualizada` |
| Seguimiento | `GET /pedidos/:id/estado` | R `pedidos` | Canal `pedido_{id}_{token}` |
| Cancelar | `POST /pedidos/:id/cancelar` | W `pedidos`, stock | `pedido_actualizado` |
| Llamar mesera | `POST /pedidos/:id/llamar-mesera` | W `auditoria_logs` | `llamar_mesera` |

## Flujo staff — acciones principales

| Módulo | Acción | API | Realtime |
|--------|--------|-----|----------|
| Kanban | Cambiar estado | `PATCH /pedidos/:id/estado` | `pedido_actualizado` |
| Kanban | Aprobar/rechazar QR | `PATCH /pedidos/:id/aprobar\|rechazar` | `mesas_actualizadas`, `cocina_actualizada` |
| Mesas | CRUD / transferir | `POST/PATCH /mesas/*` | `mesas_actualizadas` |
| Caja | Abrir/cerrar/movimientos | `POST /caja/*` | `caja_movimiento` |
| KDS | Item listo | `PATCH /cocina/items/:id/estado` | `cocina_actualizada` |
| Domi | En camino / entregar | `PATCH /domiciliario/pedidos/*` | `ubicacion_repartidor`, `pedido_actualizado` |
| Domi indep | Aceptar oferta | `POST /domiciliarios/ofertas/:id/responder` | `oferta_nueva`, `oferta_expirada` |

## Eventos Realtime (canal → evento)

| Canal | Eventos |
|-------|---------|
| `sucursal_{id}` | `pedido_actualizado`, `mesas_actualizadas`, `caja_movimiento`, `alerta_nueva`, `qr_aprobacion_urgente`, `catalogo_disponibilidad`, `llamar_mesera` |
| `cocina_{id}` | `cocina_actualizada` |
| `domiciliario_{userId}` | `pedido_asignado`, `pedido_desasignado` |
| `domiciliario_indep_{id}` | `oferta_nueva`, `oferta_expirada` |
| `pedido_{id}_{token}` | `estado_actualizado`, `ubicacion_repartidor` |

Implementación Flutter: `lib/core/realtime/foody_realtime.dart`.

## Pendiente menor (no bloquea piloto)

| Ítem | Nota |
|------|------|
| `InventarioRepository.costosProductos` | Duplica `CosteoRepository.resumen`; sin UI dedicada |
| Módulos bloqueados por plan | Placeholder intencional |
| `default` panel «en construcción» | Solo `?seccion=` inválida |
| QA visual Flutter §3 | API cubierta por `verificar-qa-roles-api.ps1` |

## Referencias

- Checklist manual: `docs/CHECKLIST_QA_ROLES.md`
- Realtime QA: `docs/CHECKLIST_QA_REALTIME.md`
- CI cierre local: `scripts/verificar-cierre-sin-vps.ps1`
