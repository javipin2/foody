# Foody — App domiciliario (planta + independiente)

**Última actualización:** 2026-08-08 — rediseño app repartidor (shell, tarjeta, ingresos, dispatch).

## Rutas

| Rol | Login | Dashboard |
|-----|-------|-----------|
| Planta | staff `domi@foody.demo` | `/admin/domiciliario` |
| Independiente | `repartidor@foody.demo` | `/domiciliario/independiente` |

## Shell

Ambas apps: **NavigationBar** Activos/Ofertas · Historial o Activos · **Ingresos** · **Perfil** (logout / turno).

## Tarjeta pedido

`TarjetaPedidoDomiciliario`: nombre, dirección (tap → Waze/Maps), teléfono (sheet: llamar / WhatsApp / copiar / agregar), método de pago, producto + domicilio + total, CTA en camino / entregar. Indep: «Ir al restaurante» + «Ir al cliente».

## Ofertas indep

`ganancia_estimada` / `comision_foody` desde API (sin `× 0.85` en Flutter). Sin teléfono hasta aceptar. Countdown desde `expira_at`.

## Ingresos

- Indep: `GET /domiciliarios/ganancias?desde&hasta` → `{ items, resumen }`.
- Planta: historial + stats con filtro fechas; `total_cobrado_rango`.

## Dispatch

Radio 3→5→7 km, TTL config, max 3 intentos. Auto-reintento al expirar oferta sin asignación. Intento vacío (0 candidatos) se persiste como oferta `expirada` para ampliar radio. FCM usa segundos dinámicos.

## Archivos

- `lib/features/domiciliarios/presentation/dashboard_domiciliario_*.dart`
- `widgets/tarjeta_pedido_domiciliario.dart`, `acciones_contacto_cliente.dart`, `tarjeta_oferta_in_driver.dart`, `filtro_fechas_chips.dart`
- `foody_backend/.../dispatch.service.ts`, `domiciliarios-independientes.service.ts`
