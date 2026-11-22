# Legacy Tu Cancha Fácil

Esta carpeta aísla el entry point de emergencia del producto anterior.

## Qué usar en Foody (producción)

- **Entry point:** `lib/main.dart` → `lib/features/` + `go_router`
- **Backend:** NestJS (`foody_backend/`), no Firebase/Firestore para pedidos

## Qué queda legacy

| Ruta | Estado |
|------|--------|
| `lib/legacy/main_reserva_canchas.dart` | Stub informativo (P3-03); no arranca reservas |
| ~~`lib/screens/`~~ | **Eliminado** P3-03 — flujos en `lib/features/` |
| `lib/providers/` | **Eliminado** P3-04 — Riverpod en `lib/features/` |
| ~~`lib/services/pedido_service.dart`, `menu_catalog_service.dart`~~ | **Eliminados** P3-04 |

## Regla de limpieza

1. `lib/features/` **no** importa `lib/screens/` (cumplido).
2. ~~Borrar `lib/screens/`~~ — hecho 2026-07-01 (P3-03).
3. Renombrar paquete `reserva_canchas` → Sprint 11 (P3-05, no bloqueante).
