# Facturación electrónica (DIAN) — PAUSADA

**Decisión:** 2026-07-02  
**Estado:** 🚫 Pospuesta hasta nuevo aviso (sin recursos para proveedor FE / integración DIAN).

## Qué sigue funcionando

- Borrador de factura al crear pedido (`requiere_factura`).
- Pantalla admin **Facturas internas**: listar, emitir, anular, vista previa HTML (sin pretender DIAN).
- Permisos `ver_facturacion` / `gestionar_facturacion` (plan enterprise en metadata).
- UI (2026-08-11): campo «Resolución DIAN» oculto; banner FE pausada; menú renombrado.

## Qué NO se implementará ahora

- CUFE, XML UBL, envío a DIAN.
- Nota crédito electrónica legal.
- Proveedor FE (Carvajal, Alegra, etc.).
- Mostrar resolución DIAN en config hasta retomar FE.

## Referencias congeladas

- Escenarios: `PED-011`, `PED-012`, `QR-011`, `FAC-003` en `docs/ESCENARIOS_NEGOCIO_FOODY.md` → 🚫 pospuesto.
- Roadmap: `X-01` en `docs/ROADMAP_TERMINAR_FOODY.md`.

## Cuando se retome

1. Elegir proveedor FE y presupuesto.
2. Sprint dedicado (guía: 9–11 en `INFRAESTRUCTURA/`).
3. No tocar flujo POS actual; añadir capa de emisión legal sobre `facturas` existentes.
