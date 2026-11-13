"""Delayed failure fixture for the Godot connection-dialog regression test."""
import asyncio
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()

@app.get('/health')
async def health():
    await asyncio.sleep(0.6)
    return JSONResponse({'ok': False, 'error': 'delayed test failure'}, status_code=503)
