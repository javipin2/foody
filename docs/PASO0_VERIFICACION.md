# Paso 0 — Verificación base Foody

> **Objetivo:** Confirmar que migraciones, backend, logins demo y rutas API funcionan antes de implementar Paso 1.
> **Automatizado:** `scripts/verificar-paso0.ps1`
> **Última ejecución:** 2026-06-08 — **25 OK, 0 FALLO**

---

## 1. Pre-requisitos (encender entorno)

1. **Docker Desktop** en ejecución.
2. Stack Supabase local (`supabase-db`, `supabase-kong`, etc.) — suele arrancar con Docker Desktop si ya estaba configurado.
3. Backend NestJS en puerto **3000**:
   ```powershell
   cd foody_backend
   node dist/main.js
   ```
   O: `scripts\iniciar-backend-wsl.bat` (WSL).
4. Flutter web (opcional para prueba manual):
   ```powershell
   flutter run -d chrome
   ```

Si Postgres no responde, ejecutar `scripts\puesta-a-punto-completa.bat` (aplica migraciones 026–029).

---

## 2. Verificación automática (API + BD)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verificar-paso0.ps1
```

| Área | Qué valida |
|------|------------|
| Infra | `GET /salud`, Postgres `supabase-db` |
| Login | admin, super, cocina, domi, repartidor (`123456`) |
| Admin API | pedidos, inventario, costos, combos, cocinas, zonas, horarios, reportes, alertas |
| Cocina | `GET /cocina/cocinas` |
| Domiciliario planta | `GET /domiciliario/pedidos-asignados` |
| Domiciliario independiente | `GET /domiciliarios/ofertas-activas` |
| Super admin | `GET /super/estadisticas` |
| Cliente público | `GET /menu/:sucursal`, `GET /ciudades` |
| Migraciones | IVA (027), RLS (028), horarios (030) |

**Resultado 2026-06-08:** todos OK.

---

## 3. Checklist manual por rol (Flutter)

Marcar en cada sesión de prueba. Contraseña demo: **`123456`**.

| Rol | Login / ruta | Qué probar manualmente | 2026-06-08 |
|-----|--------------|------------------------|------------|
| **Cliente** | Sin login → `/cliente` | Ciudad → menú → carrito → checkout → seguimiento | ⏳ UI |
| **Cliente mesa** | `/mesa/demo-mesa-1` | Pedido mesa → pendiente aprobación | ⏳ UI |
| **Admin** | `admin@foody.demo` → `/admin/login` | Kanban, mesas, caja, menú, inventario, zonas, horarios | ⏳ UI |
| **Super admin** | `super@foody.demo` | Foody Control: ciudades, onboarding restaurante | ⏳ UI |
| **Cocina** | `cocina@foody.demo` | Panel KDS `/admin/cocina`, marcar ítem listo | ⏳ UI |
| **Dom. planta** | `domi@foody.demo` | `/admin/domiciliario`, entregas | ⏳ UI |
| **Repartidor** | `repartidor@foody.demo` | `/domiciliario/login` → ofertas | ⏳ UI |
| **Cajero** | `cajero.test@foody.demo` | Caja + nuevo pedido (si existe en BD) | ⏳ UI |

> API validada; **prueba UI Flutter pendiente** en esta sesión (no se lanzó `flutter run`).

---

## 4. Flujo E2E recomendado (1 pedido completo)

1. Cliente: pedido **para llevar** → pagar → anotar `pedido_id`.
2. Admin: Kanban → confirmar → cocina.
3. Cocina: KDS → marcar ítems **listo**.
4. Admin: marcar pedido **entregado** / cerrar según tipo.
5. Caja: verificar movimiento de venta si caja abierta.
6. Inventario: si producto tiene `receta_id`, comprobar movimiento en tab Movimientos.

---

## 5. Migraciones aplicadas (verificado en BD)

| Migración | Señal en BD |
|---------|-------------|
| `026_cocinas_kds.sql` | Usuario `cocina@foody.demo`, permiso `ver_cocina` |
| `027_bloque2_dinero.sql` | Columnas `pedidos.iva_porcentaje`, `iva_valor` |
| `028_bloque4_seguridad_rls.sql` | `relrowsecurity` en `pedidos` |
| `029_completar_rls_bloque4.sql` | RLS extendido |
| `030_fix_demo_operacion.sql` | `repartidor@foody.demo` activo; 7 horarios sucursal demo |

---

## 6. Problemas conocidos / siguientes pasos

| Tema | Estado |
|------|--------|
| Docker apagado al iniciar sesión | Se arrancó Docker Desktop + contenedores Supabase |
| `foody_postgres_dev` vs `supabase-db` | Entorno real usa **supabase-db** (pooler :5432) |
| Prueba UI Flutter | **Pendiente** — ejecutar checklist §3 |
| **Paso 1** | Cierre operativo pedidos + roles → ver roadmap en `AVANCE_PROYECTO.md` |

---

## 7. Referencias

- Avance vivo: `docs/AVANCE_PROYECTO.md`
- Entorno: `docs/ENTORNO_LOCAL.md`
- Script: `scripts/verificar-paso0.ps1`
