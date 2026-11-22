# Auditoría preproducción — Foody

**Fecha:** 2026-07-02  
**Estado:** P0 locales **cerrados** · VPS pendiente

## Verificación ejecutada

| Suite | Resultado |
|-------|-----------|
| `verificar-cierre-sin-vps.ps1 -SinDocker` | **7/7 OK** |
| `verificar-preproduccion.ps1` | **3/3 OK** |
| `npm run build` (foody_backend) | OK |
| `flutter analyze` mis_pedidos | OK |

Sesión: `docs/archivo/qa-sesiones/2026-07-02-cierre-sin-vps.md`

---

## P0 implementados (esta sesión)

### Seguridad / IDOR
- `SucursalScopeService` en: costeo, reportes, cocinas, impresoras, domiciliarios-planta, auditoría, promociones admin.
- `GET /pedidos/device` ya no expone `seguimiento_token` (Flutter fusiona desde cache local).
- `validarConfigProduccion()`: falla arranque si `JWT_SECRET` default o `CORS_ORIGEN=*` en prod.
- Rate limit login: **solo en producción** (CI local no bloquea).
- `GET /salud`: sin mapa de módulos en producción.

### Financiero
- Kanban `entregado` domicilio usa `montoVentaCajaEntregaDomicilio` (producto vs domicilio).
- Idempotencia pedidos: `pg_advisory_xact_lock` + sin re-notificar Realtime en replay.
- Fiado CxC y descuento con exceso: exigen caja abierta.

### Ops
- `scripts/backup-postgres.ps1` (supabase-db)
- `scripts/verificar-migraciones-prod.ps1`
- `scripts/verificar-idor-scope.ps1`
- `scripts/verificar-preproduccion.ps1` (integrado en cierre sin VPS)

### Notificaciones
- FCM: no marca `enviada=true` si todos los tokens fallan.

---

## Pendiente (requiere VPS / hardware)

> Specs de implementación (pasos, archivos, criterio hecho): **`docs/RECOMENDACIONES_IMPLEMENTACION.md`** (OPS-01…07, FCM-02, STOR-01).

| ID auditoría | ID recomendaciones | Ítem |
|--------------|-------------------|------|
| P0-05 | OPS-01 | Despliegue VPS + TLS |
| P0-06 | OPS-03 | Wompi producción |
| P0-07 | OPS-02 | Backups: scripts ✅ · **cron + offsite en VPS** pendiente — `docs/BACKUPS_FOODY.md` |
| P0-01 | OPS-06 | Impresora física validada en sitio |
| RT | OPS-07 | Canales Realtime privados con JWT (riesgo documentado; anon key en cliente) |

**Nota ID:** en `ROADMAP_TERMINAR_FOODY.md`, **P0-07** es redirect Wompi HTTPS — no confundir con backups (aquí P0-07 = OPS-02).

---

## Cómo re-verificar

```powershell
cd foody_backend; npm run build
# reiniciar API (node dist/main.js)
.\scripts\verificar-preproduccion.ps1
.\scripts\verificar-cierre-sin-vps.ps1 -SinDocker
```

Backup manual:

```powershell
.\scripts\backup-postgres.ps1
```
