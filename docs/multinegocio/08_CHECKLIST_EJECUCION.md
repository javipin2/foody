# 08 — Checklist de ejecución (cuando se abra el sprint)

Usar este archivo el día que se decida implementar.  
**Precondición:** P0 restaurante en buen estado (API prod o piloto estable). No mezclar con incendios de impresión/VPS.

Índice de specs: [`README.md`](README.md).

---

## Semáforo previo

- [ ] `GET /api/v1/salud` OK en el entorno de trabajo  
- [ ] Decisión explícita: “abrimos multi-negocio Fase 0”  
- [ ] No hay P0 crítico bloqueando al único desarrollador  
- [ ] Leídos: `01`–`07` de este folder  

---

## Fase 0 — Fundación (obligatoria primero)

### BD
- [ ] Migración `tipo_negocio` + `subtipo` en `restaurantes` (`DEFAULT 'restaurante'`)  
- [ ] Verificar seeds demo siguen siendo restaurante  

### Backend
- [ ] `modulos-por-tipo.config.ts` (ver `05_MODELO_DATOS.md`)  
- [ ] Gate: módulo activo = plan ∩ tipo  
- [ ] Login / perfil devuelve `tipo_negocio`, `modulos_activos`, `terminologia`  
- [ ] Registro público: campo tipo de negocio  
- [ ] Endpoints de módulos apagados → 403 claro  

### Flutter
- [ ] Guardar módulos activos en sesión  
- [ ] Sidebar/nav filtra por módulos  
- [ ] Helper `t(clave)` terminología (`06`)  
- [ ] Onboarding elige tipo  

### Verificación
- [ ] Script `scripts/verificar-multinegocio-fase0.ps1`:  
  - crear negocio retail → no puede `GET` mesas  
  - crear restaurante → sí puede mesas  
  - terminología / módulos en login  

### Docs al cerrar Fase 0
- [ ] `MASTER_STATUS.md` + `AVANCE_PROYECTO.md`  
- [ ] Marcar Fase 0 en `PLAN_MULTINEGOCIO_FOODY.md`  

---

## Fase 1 — Retail

### BD / API
- [ ] `producto_variantes`, sku/barcode en productos  
- [ ] Stock y venta por `variante_id`  
- [ ] Búsqueda por barcode  
- [ ] (Opcional misma fase) `producto_series`  

### UI
- [ ] Editor producto con variantes  
- [ ] POS mostrador + escáner  
- [ ] Oculto: mesas, cocina, costeo  

### Verificación
- [ ] Vender 2 tallas del mismo producto → stocks independientes  
- [ ] Barcode inexistente → error claro  
- [ ] Restaurante demo intacto (sin variantes obligatorias)  

---

## Fase 1b — Clientes (recomendado antes o junto a servicios)

- [ ] Tabla `clientes` + CRUD  
- [ ] Ligar CxC y ventas  
- [ ] UI lista/detalle cliente  

---

## Fase 3 — Catálogo online (puede ir antes que servicios)

- [ ] Endpoint catálogo genérico (menú generalizado)  
- [ ] Link público por sucursal  
- [ ] Compartir WhatsApp  
- [ ] Checkout pickup / envío simple (sin mesa)  

---

## Fase 2 — Servicios

### BD / API
- [ ] `ordenes_trabajo`, ítems, estados  
- [ ] Cotización + aprobación  
- [ ] Descuento repuestos → inventario (transacción)  
- [ ] Asignación técnico  
- [ ] Cobro OT → caja / CxC  

### UI
- [ ] Kanban OT  
- [ ] Formulario recepción equipo  
- [ ] Cotizar / compartir  
- [ ] (Después) Agenda `citas`  

### Verificación
- [ ] OT con repuesto baja stock  
- [ ] OT sin aprobar no descuenta (política a definir)  
- [ ] Cobro refleja caja  

---

## Fase 4 — Pulido

- [ ] Reportes por vertical  
- [ ] Plantillas impresión  
- [ ] Copy marketing / plan gratis  
- [ ] (Opcional) branding nombre paraguas  
- [ ] Módulo `envios` genérico si hay demanda  

---

## Orden anti-caos (resumen)

```text
0 Fundación
→ 1 Retail (+ clientes)
→ 3 Catálogo/WhatsApp
→ 2 Servicios/OT
→ 4 Pulido
```

Si solo hay tiempo para **una** cosa después de Fase 0: **Retail**.  
Es el mayor volumen de “no soy restaurante” y reutiliza pedidos/caja casi enteros.

---

## Estimación orientativa (1 desarrollador, foco parcial)

| Fase | Esfuerzo relativo | Nota |
|------|-------------------|------|
| 0 | 1–2 semanas | Habilitador |
| 1 Retail | 3–6 semanas | Depende de series/garantía |
| 1b Clientes | 3–7 días | Alto valor |
| 3 Catálogo | 2–4 semanas | Mucho reuso menú |
| 2 Servicios | 4–8 semanas | Vertical más nuevo |
| 4 | continuo | |

Son órdenes de magnitud, no compromisos de calendario.

---

## Definición de “no empezar aún”

Si estás leyendo esto y Foody comida no tiene:

- piloto con caja real, o  
- camino claro a HTTPS/API,  

…entonces **solo documentar / refinar estos markdown**. No abrir migraciones multi-negocio.
