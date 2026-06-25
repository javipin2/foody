#!/usr/bin/env python3
"""Servidor WebSocket de impresión Foody (Sprint 10 — MVP)."""
import asyncio
import json
import logging
import os

try:
    import websockets
except ImportError:
    print("Instala: pip install websockets")
    raise

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("foody_printer")

HOST = os.getenv("FOODY_PRINTER_HOST", "0.0.0.0")
PORT = int(os.getenv("FOODY_PRINTER_PORT", "8765"))


async def manejar_cliente(ws):
    logger.info("Cliente conectado: %s", ws.remote_address)
    try:
        async for mensaje in ws:
            try:
                datos = json.loads(mensaje)
            except json.JSONDecodeError:
                await ws.send(json.dumps({"exito": False, "error": "JSON inválido"}))
                continue
            ticket = datos.get("ticket") or datos.get("cuerpo") or str(datos)
            logger.info("Ticket recibido (%s chars): %s", len(ticket), ticket[:120])
            # TODO: python-escpos → impresora térmica local
            await ws.send(json.dumps({"exito": True, "mensaje": "Ticket encolado (simulado)"}))
    except websockets.ConnectionClosed:
        logger.info("Cliente desconectado")


async def main():
    logger.info("Foody Printer escuchando en ws://%s:%s", HOST, PORT)
    async with websockets.serve(manejar_cliente, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
