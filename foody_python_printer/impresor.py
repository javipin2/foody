"""Impresión térmica Foody vía python-escpos (red o archivo de respaldo)."""
from __future__ import annotations

import logging
import os
from datetime import datetime
from pathlib import Path
from typing import Any

logger = logging.getLogger("foody_printer.impresor")

PUERTO_RED = int(os.getenv("FOODY_PRINTER_PORT_NET", "9100"))
LOG_DIR = os.getenv("FOODY_PRINTER_LOG_DIR", "")
# archivo = siempre guarda en disco (dev sin hardware)
# red = solo red; falla si no hay IP
# auto = red si hay IP, si no archivo (default)
MODO = (os.getenv("FOODY_PRINTER_MODE", "auto") or "auto").strip().lower()


def _guardar_ticket_archivo(
    ticket: str, meta: dict[str, Any] | None, pedido_id: str | None = None
) -> Path:
    destino = LOG_DIR.strip() or str(Path(__file__).resolve().parent / "tickets")
    Path(destino).mkdir(parents=True, exist_ok=True)
    cocina = (meta or {}).get("cocina_id") or "sin-cocina"
    ped = pedido_id or (meta or {}).get("pedido_id") or "pedido"
    nombre = (
        f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-"
        f"{str(ped)[:8]}-{str(cocina)[:8]}.txt"
    )
    ruta = Path(destino) / nombre
    ruta.write_text(ticket, encoding="utf-8")
    logger.info("Ticket guardado en %s", ruta)
    return ruta


def _imprimir_red(ip: str, ticket: str) -> None:
    from escpos.printer import Network

    impresora = Network(ip, PUERTO_RED, timeout=5)
    impresora.text(ticket)
    if not ticket.endswith("\n"):
        impresora.text("\n")
    impresora.cut()
    impresora.close()


def imprimir_ticket(ticket: str, meta: dict[str, Any] | None = None) -> dict[str, Any]:
    """
    Imprime el ticket o lo deja en log si no hay impresora.
    meta: { cocina_id, pedido_id, impresora: { nombre, ip_local, tipo } }
    """
    if not ticket.strip():
        return {"exito": False, "error": "Ticket vacío"}

    impresora = (meta or {}).get("impresora") or {}
    ip = (impresora.get("ip_local") or "").strip()
    pedido_id = (meta or {}).get("pedido_id")

    if MODO == "archivo" or (MODO == "auto" and not ip):
        try:
            ruta = _guardar_ticket_archivo(ticket, meta, pedido_id)
            return {
                "exito": True,
                "mensaje": f"Modo archivo — ticket en {ruta}",
                "simulado": True,
                "ruta": str(ruta),
            }
        except Exception as err:
            logger.exception("Fallo guardar ticket: %s", err)
            return {"exito": False, "error": str(err)}

    if MODO == "red" and not ip:
        return {
            "exito": False,
            "error": "Modo red: falta ip_local en la impresora de cocina",
        }

    if ip:
        try:
            _imprimir_red(ip, ticket)
            logger.info(
                "Impreso en %s (%s)",
                ip,
                impresora.get("nombre") or "impresora",
            )
            return {"exito": True, "mensaje": f"Impreso en {ip}", "simulado": False}
        except Exception as err:
            logger.exception("Fallo impresión red %s: %s", ip, err)
            if MODO == "auto":
                try:
                    ruta = _guardar_ticket_archivo(ticket, meta, pedido_id)
                    return {
                        "exito": True,
                        "mensaje": f"Fallo red; ticket respaldo en {ruta}",
                        "simulado": True,
                        "error_red": str(err),
                        "ruta": str(ruta),
                    }
                except Exception as err2:
                    return {
                        "exito": False,
                        "error": f"No se pudo imprimir ni guardar: {err2}",
                    }
            return {"exito": False, "error": f"No se pudo imprimir en {ip}: {err}"}

    try:
        ruta = _guardar_ticket_archivo(ticket, meta, pedido_id)
        return {
            "exito": True,
            "mensaje": f"Sin IP — ticket en {ruta}",
            "simulado": True,
            "ruta": str(ruta),
        }
    except Exception as err:
        logger.exception("Fallo guardar ticket: %s", err)
        return {"exito": False, "error": str(err)}
