# Documentación Foody — índice

## Leer primero (cada sesión)

| # | Documento | Para qué |
|--:|-----------|----------|
| 1 | [`MASTER_STATUS.md`](MASTER_STATUS.md) | **Estado oficial** — implementado, pendiente, problemas |
| 2 | [`PRIORIDADES_FOODY.md`](PRIORIDADES_FOODY.md) | **Lista viva priorizada** — tachar avance A→F, dependencias |
| 3 | [`INFORME_MAESTRO_FOODY.md`](INFORME_MAESTRO_FOODY.md) | **Cola de corrección** F0–F8 (reemplaza QA externo) |
| 4 | [`ROADMAP_TERMINAR_FOODY.md`](ROADMAP_TERMINAR_FOODY.md) | Checklist P0→P3 |
| 5 | [`AVANCE_PROYECTO.md`](AVANCE_PROYECTO.md) | BD, env, endpoints, changelog sprint |
| 6 | [`MAPA_FOODY.md`](MAPA_FOODY.md) | Módulos Nest, pantallas, endpoints |
| 7 | [`../MEMORIA.md`](../MEMORIA.md) | Reglas irreversibles, stack |

Frontend UI: [`frontend/FRONTEND_ROADMAP.md`](frontend/FRONTEND_ROADMAP.md) · Matriz vista por vista: [`frontend/FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md`](frontend/FOODY_PANEL_ADMIN_REDESIGN_MATRIX.md) · Flavors/QA: [`ESTRATEGIA_BACKEND_PRIMERO.md`](ESTRATEGIA_BACKEND_PRIMERO.md)

## Operación (dev / VPS)

| Doc | Uso |
|-----|-----|
| [`ENTORNO_LOCAL.md`](ENTORNO_LOCAL.md) | Docker, backend, seeds |
| [`CONFIG_ENTORNO_FOODY.md`](CONFIG_ENTORNO_FOODY.md) | URLs/puertos (`config/foody-entorno.env`) |
| [`CI_E2E.md`](CI_E2E.md) | Scripts `verificar-*` |
| [`PREPARACION_VPS.md`](PREPARACION_VPS.md) | Deploy Ubuntu |
| [`MIGRACION_VPS_QUE_CAMBIA.md`](MIGRACION_VPS_QUE_CAMBIA.md) | Checklist día VPS |
| [`WOMPI_PRODUCCION.md`](WOMPI_PRODUCCION.md) | Pagos prod |
| [`CHECKLIST_F5_GOLIVE.md`](CHECKLIST_F5_GOLIVE.md) | F5 humano: térmica · Wompi dashboard · VPS |
| [`REMEDIACION_NEST_AUTH_2026-08-07.md`](REMEDIACION_NEST_AUTH_2026-08-07.md) | Cierre BN/AUTH: evidencia scripts + **detalles a pulir** |
| [`IMPRESION_RESTAURANTE.md`](IMPRESION_RESTAURANTE.md) | Agente Python |
| [`BACKUPS_FOODY.md`](BACKUPS_FOODY.md) | Backup / R2 |
| [`MONITOREO_SALUD.md`](MONITOREO_SALUD.md) | `/health`, UptimeRobot |
| [`CLOUDFLARE_TUNNEL_FOODY.md`](CLOUDFLARE_TUNNEL_FOODY.md) | Túnel HTTPS |

## Specs (diseño, no status)

- Módulos / flujos: `MODULO_*.md`, `MULTI_SUCURSAL.md`, `FLUJO_*.md`, `PLANES_SUSCRIPCION.md`
- Resumen por módulo (secundario a MASTER): [`MODULOS_ESTADO.md`](MODULOS_ESTADO.md)
- Frontend: [`frontend/README.md`](frontend/README.md)
- Multi-negocio (no implementar aún): [`multinegocio/README.md`](multinegocio/README.md)
- Spec objetivo: `INFRAESTRUCTURA/`

## Evidencia de auditorías (archivo)

- **Rendimiento de punta a punta (2026-11-22):** [`AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md`](AUDITORIA_RENDIMIENTO_PUNTA_A_PUNTA.md) — flujo Flutter → Tunnel → Nest → pool/SQL → PostgreSQL, mediciones ligeras, hallazgos vigentes y plan priorizado.
- Medición HTTP GET liviana local/túnel: [`../scripts/perf/medir-lecturas-tunel.ps1`](../scripts/perf/medir-lecturas-tunel.ps1) — solo `/salud` y `/menu/:sucursalId`, concurrencia máxima 5; no usar como prueba de capacidad.

Los informes forenses Prompts 01–34 viven en:

**[`archivo/auditorias-prompts/README.md`](archivo/auditorias-prompts/README.md)**

No son lectura diaria. Usar INFORME_MAESTRO para priorizar; abrir el AUDITORIA_\* solo al arreglar ese ID.

Histórico Antigravity / QA sesiones: [`archivo/README.md`](archivo/README.md)
