# Migración PC → VPS — qué cambia y qué NO

> Léelo el día que compres el VPS.  
> Guía paso a paso: [`PREPARACION_VPS.md`](PREPARACION_VPS.md) · Preflight: `.\scripts\verificar-listo-vps.ps1`

---

## Regla de oro

**Los dominios públicos no cambian.**  
`foodyy.store` / `equipo` / `api` / `sb` siguen iguales.  
Solo cambia **dónde** corre el origen (PC → Ubuntu) y algunos secretos/hosts internos.

```text
Internet → Cloudflare → cloudflared  →  hoy: tu PC
                                     →  luego: VPS
```

---

## NO cambia (no retocar dashboards)

| Pieza | Valor actual | Acción en VPS |
|-------|--------------|---------------|
| Dominio | `foodyy.store` | Igual |
| App cliente | `https://foodyy.store` | Igual |
| Equipo / admin | `https://equipo.foodyy.store` | Igual |
| API | `https://api.foodyy.store` | Igual |
| Supabase público | `https://sb.foodyy.store` | Igual |
| Rutas Cloudflare Tunnel | hostname → `127.0.0.1:8081/8080/3000/8000` | **Igual** (mismo túnel `foody`) |
| UptimeRobot URL | `https://api.foodyy.store/api/v1/health` | **No crear otro monitor** — sigue el mismo |
| Wompi webhook | `https://api.foodyy.store/api/v1/pagos/webhook-wompi` | **No cambiar** en el dashboard |
| Wompi redirect | `https://equipo.foodyy.store/admin/panel?seccion=mejorar_plan` | **No cambiar** |
| Google OAuth origins / redirects | foodyy + equipo + `sb.../callback` | Igual (salvo nuevo dominio) |
| `config/foody-entorno.env` DOMINIO/HOST_* | foodyy.store | Copiar tal cual |
| Flutter `usarTunel=true` + hosts | sync desde entorno | Igual tras sync en VPS |
| `DB_POOL_MAX` | `25` | Mantener `25` |
| `TUNNEL_TOKEN` / nombre túnel | `scripts/cloudflare-tunnel.env` | Mismo token; **mover** el conector al VPS |

---

## SÍ cambia (checklist obligatorio)

### A) Máquina / procesos

| Qué | Hoy (PC) | En VPS | Notas |
|-----|----------|--------|-------|
| Dónde corre Docker / Supabase | PC / WSL | Ubuntu VPS | Instalar Docker en VPS |
| Dónde corre Nest | `node dist/main.js` Windows | `docker compose -f docker-compose.prod.yml` (o node en VPS) | Preferir compose prod |
| Dónde corre web `:8080` / `:8081` | Python SPA / bat Windows | Mismo puertos en VPS o Nginx | Cloudflare apunta a localhost del VPS |
| Dónde corre **cloudflared** | PC | **Solo VPS** | Apagar el del PC o habrá doble origen / 502 |
| Arranque diario | `iniciar-backend-wsl.bat` + `iniciar-foody-subdominios.bat` | systemd / docker restart + cloudflared service | `setup-ubuntu-vps.sh` |

### B) Archivos a **copiar** del PC → VPS (scp/rsync)

| Archivo | ¿Por qué? |
|---------|-----------|
| Todo el repo (`git clone` o sync) | Código |
| `config/foody-entorno.env` | URLs/puertos |
| `foody_backend/.env` | Secretos (luego editar — ver C) |
| `scripts/cloudflare-tunnel.env` | Token túnel (no commitear) |
| Opcional: `backups/*.sql` reciente | Semilla / restore de prueba |

### C) Variables en `foody_backend/.env` — **editar en VPS**

| Variable | PC (ahora) | VPS (cambiar a) | Por qué |
|----------|------------|-----------------|---------|
| `ENTORNO` | `desarrollo` | **`produccion`** | Activa validaciones prod (JWT fuerte, CORS estricto) |
| `JWT_SECRET` | valor de demo/dev | **secreto largo nuevo** | Obligatorio si `ENTORNO=produccion` |
| `DATABASE_URL` | host local Docker PC | **host interno** del Postgres/Supabase en el VPS | La IP/hostname del PC ya no aplica |
| `SUPABASE_URL` (si es interna) | a veces `localhost:8000` | interno Docker **o** seguir `https://sb.foodyy.store` si Kong público | Preferir URL que Nest alcance desde el contenedor |
| `CORS_ORIGEN` | ya tiene foodyy + equipo | Revisar que siga con `https://foodyy.store,https://equipo.foodyy.store,...` | Sync con `sincronizar-entorno` si hay script en Linux |
| `CLIENT_WEB_URL` | `https://foodyy.store` | Igual | — |
| `WOMPI_REDIRECT_URL` | ya equipo.foodyy | **Igual** | No tocar |
| `WOMPI_*` claves / events secret | sandbox o las que uses | Igual (o pasar a `pub_prod_` cuando cobres) | URLs públicas no cambian |
| `DB_POOL_MAX` | `25` | `25` | — |
| `FCM_*` / paths de credenciales | rutas Windows | **rutas Linux** del JSON de Firebase | Si usas push |

### D) Backups

| Qué | PC | VPS |
|-----|----|----|
| Script | `backup-postgres.ps1` | `backup-postgres.sh` |
| Programación | Task Scheduler `FoodyBackupPostgres` | **cron** 03:00 (`docs/BACKUPS_FOODY.md`) |
| Offsite R2 | opcional | Activar rclone + `R2_REMOTE` en VPS |
| Tarea Windows | Se puede **desactivar** al migrar | Ya no hace backup del origen vivo |

### E) Monitoreo y pagos (solo verificar)

| Servicio | Acción en migración |
|----------|---------------------|
| **UptimeRobot** | Ningún cambio de URL. El día del corte: apagá cloudflared del PC **después** de que el VPS responda, para que no parpadee Down. |
| **Wompi webhook** | Ningún cambio de URL. Tras el corte, un pago de prueba (sandbox o prod). |
| **Google OAuth** | Sin cambios si el dominio es el mismo. |

### F) DNS / Cloudflare Zero Trust

| Qué | Acción |
|-----|--------|
| Public Hostnames del túnel `foody` | **No recrear** |
| Conector cloudflared | Instalar en VPS con el **mismo** `TUNNEL_TOKEN`; detener servicio en PC |
| Registros DNS CNAME | No tocar (ya apuntan al túnel) |

---

## Orden de corte (día D) — resumido

1. VPS listo: Docker + Supabase + migraciones + `.env` editado (`produccion` + JWT + DB).
2. `docker compose -f docker-compose.prod.yml up -d --build`
3. Web en `:8080` / `:8081` (o Nginx).
4. Arrancar **cloudflared en VPS**.
5. Probar en privado: `curl https://api.foodyy.store/api/v1/salud` (debería pegarle al VPS).
6. **Apagar cloudflared (y Nest web) en el PC.**
7. Confirmar UptimeRobot sigue **Up**.
8. Activar cron backup + (opcional) R2.
9. Pago Wompi de prueba.

---

## Antipatrones (evitar)

- Dejar cloudflared en PC **y** VPS a la vez con el mismo túnel.
- Cambiar la URL del monitor UptimeRobot “por si acaso”.
- Cambiar el webhook Wompi a una IP del VPS (debe seguir siendo `api.foodyy.store`).
- Poner `ENTORNO=produccion` con `JWT_SECRET` débil/default → Nest no arranca.
- Olvidar actualizar `DATABASE_URL` al host Docker del VPS.

---

## Referencias

- Pasos largos: [`PREPARACION_VPS.md`](PREPARACION_VPS.md)
- URLs: [`CONFIG_ENTORNO_FOODY.md`](CONFIG_ENTORNO_FOODY.md) · `config/foody-entorno.env`
- Túnel: [`CLOUDFLARE_TUNNEL_FOODY.md`](CLOUDFLARE_TUNNEL_FOODY.md)
- Wompi: [`WOMPI_PRODUCCION.md`](WOMPI_PRODUCCION.md)
- Backups: [`BACKUPS_FOODY.md`](BACKUPS_FOODY.md)
- Humanos Fase 0: [`ACCIONES_HUMANAS_TUNEL.md`](ACCIONES_HUMANAS_TUNEL.md)
