#!/usr/bin/env python3
"""Servidor WebSocket de impresión Foody — NestJS → python-escpos / archivo."""
import asyncio
import json
import logging
import os

try:
    import websockets
except ImportError:
    print("Instala: pip install -r requirements.txt")
    raise

from impresor import MODO, imprimir_ticket

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

            if datos.get("accion") == "ping":
                await ws.send(
                    json.dumps(
                        {
                            "exito": True,
                            "pong": True,
                            "modo": MODO,
                            "mensaje": "foody_python_printer activo",
                        },
                        ensure_ascii=False,
                    )
                )
                continue

            ticket = datos.get("ticket") or datos.get("cuerpo") or ""
            meta = {
                "cocina_id": datos.get("cocina_id"),
                "pedido_id": datos.get("pedido_id"),
                "impresora": datos.get("impresora"),
            }
            resultado = imprimir_ticket(str(ticket), meta)
            await ws.send(json.dumps(resultado, ensure_ascii=False))
    except websockets.ConnectionClosed:
        logger.info("Cliente desconectado")


async def main():
    logger.info(
        "Foody Printer ws://%s:%s (modo=%s)",
        HOST,
        PORT,
        MODO,
    )
    async with websockets.serve(manejar_cliente, HOST, PORT):
        await asyncio.Future()


if __name__ == "__main__":
    asyncio.run(main())
