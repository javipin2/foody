# Backups Foody (OPS-02)

**Estado:** script listo · cron/offsite en VPS pendiente de activar.

## Manual (Windows / PC)

```powershell
.\scripts\backup-postgres.ps1
.\scripts\backup-postgres.ps1 -Destino .\backups -RetencionDias 14
```

Salida: `backups/foody_db-YYYYMMDD-HHmmss.sql` (sin comprimir en Windows).

## Automático (Windows / PC + túnel)

```powershell
.\scripts\programar-backup-windows.ps1
# Tarea: FoodyBackupPostgres · diario 03:00 · carpeta backups\
```

Quitar: `Unregister-ScheduledTask -TaskName 'FoodyBackupPostgres' -Confirm:$false`

## Automático (VPS Ubuntu)

```bash
chmod +x /opt/foody/scripts/backup-postgres.sh
# Prueba:
DESTINO=/var/backups/foody RETENCION_DIAS=14 /opt/foody/scripts/backup-postgres.sh
```

Cron diario 03:00:

```cron
0 3 * * * DESTINO=/var/backups/foody RETENCION_DIAS=14 /opt/foody/scripts/backup-postgres.sh >> /var/log/foody-backup.log 2>&1
```

## Offsite (Cloudflare R2 / S3)

1. Instalar [rclone](https://rclone.org/) y configurar remoto (ej. `foody-r2`).
2. En cron o env:

```bash
R2_REMOTE=foody-r2 R2_PATH=foody-backups DESTINO=/var/backups/foody \
  /opt/foody/scripts/backup-postgres.sh
```

Retención local: 14 días (variable `RETENCION_DIAS`). Offsite: configurar lifecycle en R2 (30 días recomendado).

## Restore de prueba (checklist mensual)

```bash
gunzip -c /var/backups/foody/foody_db-XXXX.sql.gz | \
  docker exec -i supabase-db psql -U postgres -d postgres_restore_test
```

Documentar resultado en `docs/archivo/qa-sesiones/`.

## Criterio «hecho» en prod

- [ ] Cron corre 3 mañanas seguidas
- [ ] Objeto visible en R2
- [ ] Un restore de prueba OK
