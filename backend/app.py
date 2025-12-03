"""
Viral Video SaaS - Main Application
FastAPI backend for generating viral videos using Freepik API
"""

import os
import asyncio
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager

from database.db import init_db, get_db
from routes.generate import router as generate_router
from routes.history import router as history_router
from routes.models import router as models_router
from routes.settings import router as settings_router
from routes.batch import router as batch_router
from services.websocket_manager import manager

# Batch job control
batch_jobs = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    # Startup
    print("Starting Viral Video SaaS...")
    await init_db()

    # Create storage directories
    os.makedirs("/home/user/automsationyt/storage/images", exist_ok=True)
    os.makedirs("/home/user/automsationyt/storage/videos", exist_ok=True)
    os.makedirs("/home/user/automsationyt/storage/thumbnails", exist_ok=True)

    yield

    # Shutdown
    print("Shutting down Viral Video SaaS...")
    # Cancel any running batch jobs
    for job_id, job in batch_jobs.items():
        if 'task' in job and not job['task'].done():
            job['task'].cancel()


app = FastAPI(
    title="Viral Video SaaS",
    description="Generate viral videos using Freepik AI API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(generate_router, prefix="/api", tags=["Generation"])
app.include_router(history_router, prefix="/api", tags=["History"])
app.include_router(models_router, prefix="/api", tags=["Models"])
app.include_router(settings_router, prefix="/api", tags=["Settings"])
app.include_router(batch_router, prefix="/api", tags=["Batch"])

# Mount static files for storage
app.mount("/storage", StaticFiles(directory="/home/user/automsationyt/storage"), name="storage")


@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "viral-video-saas"}


@app.websocket("/ws/progress")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time progress updates"""
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive
            data = await websocket.receive_text()
            # Echo back for ping/pong
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
