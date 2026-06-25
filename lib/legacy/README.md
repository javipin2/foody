# Legacy Tu Cancha Fácil

Esta carpeta aísla el entry point de emergencia del producto anterior.

## Qué usar en Foody (producción)

- **Entry point:** `lib/main.dart` → `lib/features/` + `go_router`
- **Backend:** NestJS (`foody_backend/`), no Firebase/Firestore para pedidos

## Qué queda legacy

| Ruta | Estado |
|------|--------|
| `lib/legacy/main_reserva_canchas.dart` | Referencia de emergencia; no usar en builds Foody |
| `lib/screens/` | Reservas canchas, Firebase, dashboards antiguos |
| `lib/providers/` | Provider + Firebase (solo legacy) |
| `lib/services/pedido_service.dart`, `menu_catalog_service.dart` | Escritura Firebase; reemplazados por NestJS |

## Regla de limpieza

1. `lib/features/` **no** debe importar `lib/screens/`.
2. Borrar archivos en `lib/screens/` solo cuando ningún import los referencie (hoy: solo `main_reserva_canchas.dart`).
3. Renombrar paquete `reserva_canchas` → Sprint 11 (no bloqueante).
