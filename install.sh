#!/bin/bash
# =============================================================================
# VIRAL VIDEO SAAS - INSTALADOR DE 1 CLIQUE
# Compativel com Ubuntu 20.04, 22.04, Debian 11, 12
# =============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuracoes
INSTALL_DIR="/opt/viral-video-saas"
SERVICE_NAME="viral-saas"
REPO_URL="https://github.com/sterling9879/automsationyt.git"
BRANCH="claude/setup-saas-video-environment-014XcsECmtTCkVc3jYdTh1B9"

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║   ██╗   ██╗██╗██████╗  █████╗ ██╗         ██╗   ██╗██╗██████╗ ███████╗   ║
║   ██║   ██║██║██╔══██╗██╔══██╗██║         ██║   ██║██║██╔══██╗██╔════╝   ║
║   ██║   ██║██║██████╔╝███████║██║         ██║   ██║██║██║  ██║█████╗     ║
║   ╚██╗ ██╔╝██║██╔══██╗██╔══██║██║         ╚██╗ ██╔╝██║██║  ██║██╔══╝     ║
║    ╚████╔╝ ██║██║  ██║██║  ██║███████╗     ╚████╔╝ ██║██████╔╝███████╗   ║
║     ╚═══╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝      ╚═══╝  ╚═╝╚═════╝ ╚══════╝   ║
║                                                                           ║
║                    SAAS - GERADOR DE VIDEOS VIRAIS                        ║
║                         Powered by Freepik AI                             ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Execute como root: sudo bash install.sh${NC}"
    exit 1
fi

log() { echo -e "${GREEN}[✓]${NC} $1"; }
log_step() { echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"; echo -e "${YELLOW}$1${NC}"; echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"; }
log_error() { echo -e "${RED}[✗] ERRO:${NC} $1"; }

# =============================================================================
# PASSO 1: ATUALIZAR SISTEMA
# =============================================================================
log_step "[1/7] Atualizando sistema..."
apt update -qq
apt install -y -qq nginx python3 python3-venv python3-pip curl git
log "Sistema atualizado e dependencias instaladas"

# =============================================================================
# PASSO 2: CRIAR DIRETORIOS
# =============================================================================
log_step "[2/7] Criando estrutura de diretorios..."
mkdir -p ${INSTALL_DIR}/{backend/{routes,services,database},frontend/{css,js,assets},storage/{images,videos,thumbnails}}
log "Diretorios criados"

# =============================================================================
# PASSO 3: CRIAR ARQUIVOS DO BACKEND
# =============================================================================
log_step "[3/7] Criando arquivos do backend..."

# requirements.txt
cat > ${INSTALL_DIR}/backend/requirements.txt << 'REQEOF'
fastapi==0.109.0
uvicorn[standard]==0.27.0
aiohttp==3.9.1
aiosqlite==0.19.0
python-multipart==0.0.6
websockets==12.0
pydantic==2.5.3
REQEOF

# database/db.py
cat > ${INSTALL_DIR}/backend/database/__init__.py << 'EOF'
# Database module
EOF

cat > ${INSTALL_DIR}/backend/database/db.py << 'DBEOF'
import aiosqlite
import os
from datetime import datetime
from typing import Optional, List, Dict, Any

DATABASE_PATH = "/opt/viral-video-saas/backend/database/viral_saas.db"

async def get_db():
    db = await aiosqlite.connect(DATABASE_PATH)
    db.row_factory = aiosqlite.Row
    return db

async def init_db():
    os.makedirs(os.path.dirname(DATABASE_PATH), exist_ok=True)
    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS videos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                prompt TEXT NOT NULL,
                image_model VARCHAR(100),
                video_model VARCHAR(100),
                image_url TEXT,
                video_url TEXT,
                video_path VARCHAR(500),
                thumbnail_path VARCHAR(500),
                status VARCHAR(50) DEFAULT 'pending',
                error_message TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                completed_at TIMESTAMP
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS batch_jobs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                prompt TEXT NOT NULL,
                image_model VARCHAR(100),
                video_model VARCHAR(100),
                total_quantity INTEGER DEFAULT 0,
                completed_count INTEGER DEFAULT 0,
                interval_seconds INTEGER DEFAULT 30,
                status VARCHAR(50) DEFAULT 'running',
                started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                stopped_at TIMESTAMP
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key VARCHAR(100) PRIMARY KEY,
                value TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        await db.commit()

async def create_video(prompt: str, image_model: str, video_model: str, status: str = "pending") -> int:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute(
            "INSERT INTO videos (prompt, image_model, video_model, status, created_at) VALUES (?, ?, ?, ?, ?)",
            (prompt, image_model, video_model, status, datetime.now().isoformat())
        )
        await db.commit()
        return cursor.lastrowid

async def update_video(video_id: int, **kwargs) -> None:
    if not kwargs:
        return
    set_clause = ", ".join([f"{k} = ?" for k in kwargs.keys()])
    values = list(kwargs.values()) + [video_id]
    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute(f"UPDATE videos SET {set_clause} WHERE id = ?", values)
        await db.commit()

async def get_video(video_id: int) -> Optional[Dict[str, Any]]:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute("SELECT * FROM videos WHERE id = ?", (video_id,))
        row = await cursor.fetchone()
        return dict(row) if row else None

async def get_videos(page: int = 1, limit: int = 20, search: Optional[str] = None) -> Dict[str, Any]:
    offset = (page - 1) * limit
    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        if search:
            cursor = await db.execute("SELECT COUNT(*) as count FROM videos WHERE prompt LIKE ?", (f"%{search}%",))
        else:
            cursor = await db.execute("SELECT COUNT(*) as count FROM videos")
        total_row = await cursor.fetchone()
        total = total_row[0]
        if search:
            cursor = await db.execute("SELECT * FROM videos WHERE prompt LIKE ? ORDER BY created_at DESC LIMIT ? OFFSET ?", (f"%{search}%", limit, offset))
        else:
            cursor = await db.execute("SELECT * FROM videos ORDER BY created_at DESC LIMIT ? OFFSET ?", (limit, offset))
        rows = await cursor.fetchall()
        videos = [dict(row) for row in rows]
        return {"videos": videos, "total": total, "page": page, "limit": limit, "total_pages": (total + limit - 1) // limit}

async def delete_video(video_id: int) -> bool:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute("DELETE FROM videos WHERE id = ?", (video_id,))
        await db.commit()
        return cursor.rowcount > 0

async def get_storage_stats() -> Dict[str, Any]:
    storage_path = "/opt/viral-video-saas/storage"
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(storage_path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            if os.path.exists(fp):
                total_size += os.path.getsize(fp)
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute("SELECT COUNT(*) as count FROM videos")
        row = await cursor.fetchone()
        total_videos = row[0]
    units = ['B', 'KB', 'MB', 'GB']
    size = total_size
    unit_index = 0
    while size >= 1024 and unit_index < len(units) - 1:
        size /= 1024
        unit_index += 1
    return {"total_videos": total_videos, "storage_used_bytes": total_size, "storage_used_formatted": f"{size:.1f} {units[unit_index]}"}

async def create_batch_job(prompt: str, image_model: str, video_model: str, total_quantity: int, interval_seconds: int) -> int:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute(
            "INSERT INTO batch_jobs (prompt, image_model, video_model, total_quantity, interval_seconds, status, started_at) VALUES (?, ?, ?, ?, ?, 'running', ?)",
            (prompt, image_model, video_model, total_quantity, interval_seconds, datetime.now().isoformat())
        )
        await db.commit()
        return cursor.lastrowid

async def update_batch_job(job_id: int, **kwargs) -> None:
    if not kwargs:
        return
    set_clause = ", ".join([f"{k} = ?" for k in kwargs.keys()])
    values = list(kwargs.values()) + [job_id]
    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute(f"UPDATE batch_jobs SET {set_clause} WHERE id = ?", values)
        await db.commit()

async def get_batch_job(job_id: int) -> Optional[Dict[str, Any]]:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute("SELECT * FROM batch_jobs WHERE id = ?", (job_id,))
        row = await cursor.fetchone()
        return dict(row) if row else None

async def get_running_batch_job() -> Optional[Dict[str, Any]]:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute("SELECT * FROM batch_jobs WHERE status = 'running' ORDER BY started_at DESC LIMIT 1")
        row = await cursor.fetchone()
        return dict(row) if row else None

async def get_setting(key: str) -> Optional[str]:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute("SELECT value FROM settings WHERE key = ?", (key,))
        row = await cursor.fetchone()
        return row[0] if row else None

async def set_setting(key: str, value: str) -> None:
    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute(
            "INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?) ON CONFLICT(key) DO UPDATE SET value = ?, updated_at = ?",
            (key, value, datetime.now().isoformat(), value, datetime.now().isoformat())
        )
        await db.commit()
DBEOF

# services/__init__.py
cat > ${INSTALL_DIR}/backend/services/__init__.py << 'EOF'
# Services module
EOF

# services/websocket_manager.py
cat > ${INSTALL_DIR}/backend/services/websocket_manager.py << 'WSEOF'
from typing import List, Dict, Any
from fastapi import WebSocket
import json

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: Dict[str, Any]):
        message_str = json.dumps(message)
        disconnected = []
        for connection in self.active_connections:
            try:
                await connection.send_text(message_str)
            except Exception:
                disconnected.append(connection)
        for conn in disconnected:
            self.disconnect(conn)

    async def send_progress(self, event_type: str, video_id: int = None, step: str = None, progress: int = None, message: str = None, data: Dict[str, Any] = None):
        payload = {"type": event_type, "video_id": video_id, "step": step, "progress": progress, "message": message, "data": data or {}}
        await self.broadcast(payload)

    async def send_batch_progress(self, job_id: int, completed: int, total: int, current_video_id: int = None, status: str = "running", log_message: str = None):
        payload = {"type": "batch_progress", "job_id": job_id, "completed": completed, "total": total, "current_video_id": current_video_id, "status": status, "log_message": log_message, "percentage": (completed / total * 100) if total > 0 else 0}
        await self.broadcast(payload)

    async def send_error(self, error_message: str, video_id: int = None):
        await self.broadcast({"type": "error", "video_id": video_id, "message": error_message})

    async def send_completion(self, video_id: int, video_path: str, thumbnail_path: str = None):
        await self.broadcast({"type": "completed", "video_id": video_id, "video_path": video_path, "thumbnail_path": thumbnail_path})

manager = ConnectionManager()
WSEOF

# services/freepik_api.py
cat > ${INSTALL_DIR}/backend/services/freepik_api.py << 'FPEOF'
import aiohttp
import asyncio
import base64
from typing import Optional, Dict, Any, List

class FreepikService:
    BASE_URL = "https://api.freepik.com/v1"
    IMAGE_MODELS = [
        {"id": "mystic", "name": "Mystic", "description": "Ultra-realistic high resolution"},
        {"id": "realism", "name": "Realism", "description": "Realistic photos"},
        {"id": "flux", "name": "Flux", "description": "Creative images"},
        {"id": "zen", "name": "Zen", "description": "Clean and minimalist"},
        {"id": "flexible", "name": "Flexible", "description": "Great for illustrations"},
    ]
    VIDEO_MODELS = [
        {"id": "kling-std", "name": "Kling Standard", "description": "Standard quality"},
        {"id": "kling-pro", "name": "Kling Pro", "description": "High quality"},
        {"id": "kling-v2", "name": "Kling V2", "description": "Latest model"},
    ]

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.headers = {"x-freepik-api-key": api_key, "Content-Type": "application/json"}

    async def validate_api_key(self) -> Dict[str, Any]:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.BASE_URL}/resources?limit=1", headers=self.headers, timeout=aiohttp.ClientTimeout(total=10)) as response:
                    if response.status == 200:
                        return {"valid": True, "message": "API key is valid"}
                    return {"valid": False, "message": f"Error: {response.status}"}
        except Exception as e:
            return {"valid": False, "message": str(e)}

    async def generate_image(self, prompt: str, model: str = "mystic", resolution: str = "2k", aspect_ratio: str = "square_1_1") -> Dict[str, Any]:
        payload = {"prompt": prompt, "resolution": resolution, "aspect_ratio": aspect_ratio, "creative_detailing": 50, "engine": "automatic"}
        if model and model != "mystic":
            payload["model"] = model
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(f"{self.BASE_URL}/ai/mystic", headers=self.headers, json=payload, timeout=aiohttp.ClientTimeout(total=60)) as response:
                    data = await response.json()
                    if response.status in [200, 201]:
                        return {"success": True, "task_id": data.get("data", {}).get("task_id"), "status": data.get("data", {}).get("status", "IN_PROGRESS")}
                    return {"success": False, "error": data.get("error", {}).get("message", "Unknown error")}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def check_image_status(self, task_id: str) -> Dict[str, Any]:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.BASE_URL}/ai/mystic/{task_id}", headers=self.headers, timeout=aiohttp.ClientTimeout(total=30)) as response:
                    data = await response.json()
                    if response.status == 200:
                        task_data = data.get("data", {})
                        status = task_data.get("status", "UNKNOWN")
                        result = {"success": True, "status": status, "task_id": task_id}
                        if status == "COMPLETED":
                            generated = task_data.get("generated", [])
                            if generated:
                                result["images"] = generated
                                result["image_url"] = generated[0].get("url")
                        return result
                    return {"success": False, "error": data.get("error", {}).get("message", "Unknown error")}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def wait_for_image(self, task_id: str, max_attempts: int = 60, interval: int = 2) -> Dict[str, Any]:
        for _ in range(max_attempts):
            result = await self.check_image_status(task_id)
            if not result["success"]:
                return result
            if result["status"] == "COMPLETED":
                return result
            if result["status"] == "FAILED":
                return {"success": False, "error": "Image generation failed"}
            await asyncio.sleep(interval)
        return {"success": False, "error": "Timeout"}

    async def generate_video(self, image_base64: str, model: str = "kling-std", prompt: str = "", duration: str = "5") -> Dict[str, Any]:
        endpoint = f"{self.BASE_URL}/ai/image-to-video/{model}"
        payload = {"image": image_base64, "duration": duration, "cfg_scale": 0.5}
        if prompt:
            payload["prompt"] = prompt
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(endpoint, headers=self.headers, json=payload, timeout=aiohttp.ClientTimeout(total=120)) as response:
                    data = await response.json()
                    if response.status in [200, 201]:
                        return {"success": True, "task_id": data.get("data", {}).get("task_id"), "status": "IN_PROGRESS"}
                    return {"success": False, "error": data.get("error", {}).get("message", "Unknown error")}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def check_video_status(self, task_id: str, model: str = "kling-std") -> Dict[str, Any]:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.BASE_URL}/ai/image-to-video/{model}/{task_id}", headers=self.headers, timeout=aiohttp.ClientTimeout(total=30)) as response:
                    data = await response.json()
                    if response.status == 200:
                        task_data = data.get("data", {})
                        status = task_data.get("status", "UNKNOWN")
                        result = {"success": True, "status": status, "task_id": task_id}
                        if status == "COMPLETED":
                            result["video_url"] = task_data.get("video", {}).get("url")
                        return result
                    return {"success": False, "error": data.get("error", {}).get("message", "Unknown error")}
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def wait_for_video(self, task_id: str, model: str = "kling-std", max_attempts: int = 120, interval: int = 3) -> Dict[str, Any]:
        for _ in range(max_attempts):
            result = await self.check_video_status(task_id, model)
            if not result["success"]:
                return result
            if result["status"] == "COMPLETED":
                return result
            if result["status"] == "FAILED":
                return {"success": False, "error": "Video generation failed"}
            await asyncio.sleep(interval)
        return {"success": False, "error": "Timeout"}

    @classmethod
    def get_image_models(cls):
        return cls.IMAGE_MODELS

    @classmethod
    def get_video_models(cls):
        return cls.VIDEO_MODELS

async def download_image(url: str) -> Optional[bytes]:
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=60)) as response:
                if response.status == 200:
                    return await response.read()
    except:
        pass
    return None

async def download_video(url: str) -> Optional[bytes]:
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=300)) as response:
                if response.status == 200:
                    return await response.read()
    except:
        pass
    return None

def image_to_base64(image_bytes: bytes) -> str:
    return base64.b64encode(image_bytes).decode('utf-8')
FPEOF

# routes/__init__.py
cat > ${INSTALL_DIR}/backend/routes/__init__.py << 'EOF'
# Routes module
EOF

# routes/models.py
cat > ${INSTALL_DIR}/backend/routes/models.py << 'MODEOF'
from fastapi import APIRouter
from services.freepik_api import FreepikService

router = APIRouter()

@router.get("/models/image")
async def list_image_models():
    return {"success": True, "models": FreepikService.get_image_models()}

@router.get("/models/video")
async def list_video_models():
    return {"success": True, "models": FreepikService.get_video_models()}

@router.get("/models")
async def list_all_models():
    return {"success": True, "image_models": FreepikService.get_image_models(), "video_models": FreepikService.get_video_models()}
MODEOF

# routes/settings.py
cat > ${INSTALL_DIR}/backend/routes/settings.py << 'SETEOF'
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from database.db import get_setting, set_setting
from services.freepik_api import FreepikService

router = APIRouter()

class ApiKeyRequest(BaseModel):
    api_key: str

@router.post("/settings/apikey")
async def save_api_key(request: ApiKeyRequest):
    if not request.api_key or len(request.api_key) < 10:
        raise HTTPException(status_code=400, detail="Invalid API key format")
    freepik = FreepikService(request.api_key)
    validation = await freepik.validate_api_key()
    if not validation["valid"]:
        raise HTTPException(status_code=400, detail=f"API key validation failed: {validation['message']}")
    await set_setting("freepik_api_key", request.api_key)
    masked = request.api_key[:4] + "..." + request.api_key[-4:]
    return {"success": True, "message": "API key saved", "masked_key": masked}

@router.get("/settings/apikey")
async def get_api_key_status():
    api_key = await get_setting("freepik_api_key")
    if api_key:
        return {"success": True, "configured": True, "masked_key": api_key[:4] + "..." + api_key[-4:]}
    return {"success": True, "configured": False, "masked_key": None}

@router.get("/settings/apikey/validate")
async def validate_api_key():
    api_key = await get_setting("freepik_api_key")
    if not api_key:
        return {"success": False, "valid": False, "message": "No API key configured"}
    freepik = FreepikService(api_key)
    validation = await freepik.validate_api_key()
    return {"success": True, "valid": validation["valid"], "message": validation["message"]}
SETEOF

# routes/history.py
cat > ${INSTALL_DIR}/backend/routes/history.py << 'HISTEOF'
import os
from fastapi import APIRouter, HTTPException, Query
from typing import Optional
from database.db import get_videos, get_video, delete_video, get_storage_stats

router = APIRouter()
STORAGE_PATH = "/opt/viral-video-saas/storage"

@router.get("/history")
async def list_history(page: int = Query(1, ge=1), limit: int = Query(20, ge=1, le=100), search: Optional[str] = None):
    return await get_videos(page=page, limit=limit, search=search)

@router.get("/history/stats")
async def get_history_stats():
    return await get_storage_stats()

@router.get("/history/{video_id}")
async def get_video_details(video_id: int):
    video = await get_video(video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    return {"success": True, "video": video}

@router.delete("/history/{video_id}")
async def delete_video_entry(video_id: int):
    video = await get_video(video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    if video.get("video_path"):
        video_file = os.path.join(STORAGE_PATH, video["video_path"].replace("/storage/", ""))
        if os.path.exists(video_file):
            os.remove(video_file)
    if video.get("thumbnail_path"):
        thumb_file = os.path.join(STORAGE_PATH, video["thumbnail_path"].replace("/storage/", ""))
        if os.path.exists(thumb_file):
            os.remove(thumb_file)
    await delete_video(video_id)
    return {"success": True, "message": "Video deleted"}
HISTEOF

# routes/generate.py
cat > ${INSTALL_DIR}/backend/routes/generate.py << 'GENEOF'
import os
import uuid
from datetime import datetime
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
from database.db import create_video, update_video, get_video, get_setting
from services.freepik_api import FreepikService, download_image, download_video, image_to_base64
from services.websocket_manager import manager

router = APIRouter()
STORAGE_PATH = "/opt/viral-video-saas/storage"

class GenerateRequest(BaseModel):
    prompt: str
    image_model: str = "mystic"
    video_model: str = "kling-std"
    api_key: Optional[str] = None

async def process_video_generation(video_id: int, prompt: str, image_model: str, video_model: str, api_key: str):
    try:
        freepik = FreepikService(api_key)
        await manager.send_progress("progress", video_id=video_id, step="image_generating", progress=10, message="Generating image...")
        image_result = await freepik.generate_image(prompt=prompt, model=image_model)
        if not image_result["success"]:
            raise Exception(f"Image generation failed: {image_result.get('error')}")
        await manager.send_progress("progress", video_id=video_id, step="image_processing", progress=25, message="Processing image...")
        image_status = await freepik.wait_for_image(image_result["task_id"])
        if not image_status["success"]:
            raise Exception(f"Image processing failed: {image_status.get('error')}")
        image_url = image_status.get("image_url")
        if not image_url:
            raise Exception("No image URL returned")
        await update_video(video_id, image_url=image_url)
        await manager.send_progress("progress", video_id=video_id, step="image_downloading", progress=40, message="Downloading image...")
        image_bytes = await download_image(image_url)
        if not image_bytes:
            raise Exception("Failed to download image")
        image_filename = f"{uuid.uuid4()}.png"
        with open(os.path.join(STORAGE_PATH, "images", image_filename), "wb") as f:
            f.write(image_bytes)
        image_base64 = image_to_base64(image_bytes)
        await manager.send_progress("progress", video_id=video_id, step="video_generating", progress=55, message="Generating video...")
        video_result = await freepik.generate_video(image_base64=image_base64, model=video_model, prompt=prompt)
        if not video_result["success"]:
            raise Exception(f"Video generation failed: {video_result.get('error')}")
        await manager.send_progress("progress", video_id=video_id, step="video_processing", progress=70, message="Processing video...")
        video_status = await freepik.wait_for_video(video_result["task_id"], video_model)
        if not video_status["success"]:
            raise Exception(f"Video processing failed: {video_status.get('error')}")
        video_url = video_status.get("video_url")
        if not video_url:
            raise Exception("No video URL returned")
        await manager.send_progress("progress", video_id=video_id, step="video_downloading", progress=85, message="Downloading video...")
        video_bytes = await download_video(video_url)
        if not video_bytes:
            raise Exception("Failed to download video")
        video_filename = f"{uuid.uuid4()}.mp4"
        with open(os.path.join(STORAGE_PATH, "videos", video_filename), "wb") as f:
            f.write(video_bytes)
        thumbnail_filename = f"{uuid.uuid4()}.png"
        with open(os.path.join(STORAGE_PATH, "thumbnails", thumbnail_filename), "wb") as f:
            f.write(image_bytes)
        await update_video(video_id, video_url=video_url, video_path=f"/storage/videos/{video_filename}", thumbnail_path=f"/storage/thumbnails/{thumbnail_filename}", status="completed", completed_at=datetime.now().isoformat())
        await manager.send_completion(video_id=video_id, video_path=f"/storage/videos/{video_filename}", thumbnail_path=f"/storage/thumbnails/{thumbnail_filename}")
        await manager.send_progress("progress", video_id=video_id, step="completed", progress=100, message="Done!")
    except Exception as e:
        await update_video(video_id, status="failed", error_message=str(e))
        await manager.send_error(str(e), video_id)

@router.post("/generate")
async def generate_video(request: GenerateRequest, background_tasks: BackgroundTasks):
    api_key = request.api_key or await get_setting("freepik_api_key")
    if not api_key:
        raise HTTPException(status_code=400, detail="No API key. Please save your Freepik API key first.")
    video_id = await create_video(prompt=request.prompt, image_model=request.image_model, video_model=request.video_model, status="processing")
    background_tasks.add_task(process_video_generation, video_id, request.prompt, request.image_model, request.video_model, api_key)
    return {"success": True, "video_id": video_id, "message": "Video generation started"}

@router.get("/generate/{video_id}")
async def get_generation_status(video_id: int):
    video = await get_video(video_id)
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")
    return {"success": True, "video": video}
GENEOF

# routes/batch.py
cat > ${INSTALL_DIR}/backend/routes/batch.py << 'BATEOF'
import os
import uuid
import asyncio
from datetime import datetime
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, Dict, Any
from database.db import create_video, update_video, get_setting, create_batch_job, update_batch_job, get_batch_job, get_running_batch_job
from services.freepik_api import FreepikService, download_image, download_video, image_to_base64
from services.websocket_manager import manager

router = APIRouter()
STORAGE_PATH = "/opt/viral-video-saas/storage"
batch_jobs: Dict[int, Dict[str, Any]] = {}

class BatchStartRequest(BaseModel):
    prompt: str
    image_model: str = "mystic"
    video_model: str = "kling-std"
    quantity: int = 10
    interval: int = 30
    api_key: Optional[str] = None

async def process_batch_generation(job_id: int, prompt: str, image_model: str, video_model: str, api_key: str, quantity: int, interval: int):
    global batch_jobs
    completed = 0
    freepik = FreepikService(api_key)
    try:
        while True:
            if job_id in batch_jobs and batch_jobs[job_id].get("should_stop"):
                await update_batch_job(job_id, status="stopped", stopped_at=datetime.now().isoformat())
                await manager.send_batch_progress(job_id=job_id, completed=completed, total=quantity, status="stopped", log_message="Stopped by user")
                break
            if quantity > 0 and completed >= quantity:
                await update_batch_job(job_id, status="completed", stopped_at=datetime.now().isoformat())
                await manager.send_batch_progress(job_id=job_id, completed=completed, total=quantity, status="completed", log_message="Completed!")
                break
            current = completed + 1
            try:
                video_id = await create_video(prompt=prompt, image_model=image_model, video_model=video_model, status="processing")
                await manager.send_batch_progress(job_id=job_id, completed=completed, total=quantity, status="running", log_message=f"Generating image #{current}...")
                image_result = await freepik.generate_image(prompt=prompt, model=image_model)
                if not image_result["success"]:
                    raise Exception(image_result.get("error"))
                image_status = await freepik.wait_for_image(image_result["task_id"])
                if not image_status["success"]:
                    raise Exception(image_status.get("error"))
                image_url = image_status.get("image_url")
                await update_video(video_id, image_url=image_url)
                image_bytes = await download_image(image_url)
                if not image_bytes:
                    raise Exception("Download failed")
                image_filename = f"{uuid.uuid4()}.png"
                with open(os.path.join(STORAGE_PATH, "images", image_filename), "wb") as f:
                    f.write(image_bytes)
                image_base64 = image_to_base64(image_bytes)
                await manager.send_batch_progress(job_id=job_id, completed=completed, total=quantity, status="running", log_message=f"Animating #{current}...")
                video_result = await freepik.generate_video(image_base64=image_base64, model=video_model, prompt=prompt)
                if not video_result["success"]:
                    raise Exception(video_result.get("error"))
                video_status = await freepik.wait_for_video(video_result["task_id"], video_model)
                if not video_status["success"]:
                    raise Exception(video_status.get("error"))
                video_url = video_status.get("video_url")
                video_bytes = await download_video(video_url)
                if not video_bytes:
                    raise Exception("Video download failed")
                video_filename = f"{uuid.uuid4()}.mp4"
                with open(os.path.join(STORAGE_PATH, "videos", video_filename), "wb") as f:
                    f.write(video_bytes)
                thumbnail_filename = f"{uuid.uuid4()}.png"
                with open(os.path.join(STORAGE_PATH, "thumbnails", thumbnail_filename), "wb") as f:
                    f.write(image_bytes)
                await update_video(video_id, video_url=video_url, video_path=f"/storage/videos/{video_filename}", thumbnail_path=f"/storage/thumbnails/{thumbnail_filename}", status="completed", completed_at=datetime.now().isoformat())
                completed += 1
                await update_batch_job(job_id, completed_count=completed)
                await manager.send_batch_progress(job_id=job_id, completed=completed, total=quantity, status="running", log_message=f"Video #{current} done!")
                if quantity == 0 or completed < quantity:
                    await asyncio.sleep(interval)
            except Exception as e:
                await manager.send_batch_progress(job_id=job_id, completed=completed, total=quantity, status="running", log_message=f"Error #{current}: {str(e)[:50]}. Retrying...")
                await asyncio.sleep(5)
    except asyncio.CancelledError:
        await update_batch_job(job_id, status="stopped", stopped_at=datetime.now().isoformat())
    finally:
        if job_id in batch_jobs:
            del batch_jobs[job_id]

@router.post("/batch/start")
async def start_batch(request: BatchStartRequest, background_tasks: BackgroundTasks):
    global batch_jobs
    running = await get_running_batch_job()
    if running:
        raise HTTPException(status_code=400, detail="A batch job is already running")
    api_key = request.api_key or await get_setting("freepik_api_key")
    if not api_key:
        raise HTTPException(status_code=400, detail="No API key configured")
    job_id = await create_batch_job(prompt=request.prompt, image_model=request.image_model, video_model=request.video_model, total_quantity=request.quantity, interval_seconds=request.interval)
    batch_jobs[job_id] = {"should_stop": False}
    task = asyncio.create_task(process_batch_generation(job_id, request.prompt, request.image_model, request.video_model, api_key, request.quantity, request.interval))
    batch_jobs[job_id]["task"] = task
    return {"success": True, "message": "Batch started", "job_id": job_id}

@router.post("/batch/stop")
async def stop_batch():
    global batch_jobs
    running = await get_running_batch_job()
    if not running:
        raise HTTPException(status_code=400, detail="No batch job running")
    job_id = running["id"]
    if job_id in batch_jobs:
        batch_jobs[job_id]["should_stop"] = True
        await asyncio.sleep(1)
        if "task" in batch_jobs[job_id] and not batch_jobs[job_id]["task"].done():
            batch_jobs[job_id]["task"].cancel()
    await update_batch_job(job_id, status="stopped", stopped_at=datetime.now().isoformat())
    return {"success": True, "message": "Batch stopped", "job_id": job_id}

@router.get("/batch/status")
async def get_batch_status():
    running = await get_running_batch_job()
    if running:
        return {"success": True, "running": True, "job": running}
    return {"success": True, "running": False, "job": None}
BATEOF

# app.py
cat > ${INSTALL_DIR}/backend/app.py << 'APPEOF'
import os
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from database.db import init_db
from routes.generate import router as generate_router
from routes.history import router as history_router
from routes.models import router as models_router
from routes.settings import router as settings_router
from routes.batch import router as batch_router
from services.websocket_manager import manager

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    os.makedirs("/opt/viral-video-saas/storage/images", exist_ok=True)
    os.makedirs("/opt/viral-video-saas/storage/videos", exist_ok=True)
    os.makedirs("/opt/viral-video-saas/storage/thumbnails", exist_ok=True)
    yield

app = FastAPI(title="Viral Video SaaS", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(generate_router, prefix="/api", tags=["Generation"])
app.include_router(history_router, prefix="/api", tags=["History"])
app.include_router(models_router, prefix="/api", tags=["Models"])
app.include_router(settings_router, prefix="/api", tags=["Settings"])
app.include_router(batch_router, prefix="/api", tags=["Batch"])
app.mount("/storage", StaticFiles(directory="/opt/viral-video-saas/storage"), name="storage")

@app.get("/api/health")
async def health():
    return {"status": "healthy"}

@app.websocket("/ws/progress")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
APPEOF

log "Backend criado"

# =============================================================================
# PASSO 4: CRIAR FRONTEND
# =============================================================================
log_step "[4/7] Criando frontend..."

cat > ${INSTALL_DIR}/frontend/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="pt-BR" x-data="app()" x-init="init()">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Viral Video SaaS</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script>
    <style>
        [x-cloak] { display: none !important; }
        .animate-spin { animation: spin 1s linear infinite; }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
    </style>
</head>
<body class="bg-gray-900 text-white min-h-screen">
    <header class="bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div class="max-w-6xl mx-auto flex items-center justify-between">
            <h1 class="text-2xl font-bold text-indigo-400">Viral Video SaaS</h1>
            <div class="flex items-center gap-4">
                <span x-show="apiKeyConfigured" class="text-green-400 text-sm" x-text="'API: ' + maskedApiKey"></span>
                <span x-show="!apiKeyConfigured" class="text-yellow-400 text-sm">API nao configurada</span>
                <button @click="showSettings = true" class="p-2 bg-gray-700 hover:bg-gray-600 rounded-lg">⚙️</button>
            </div>
        </div>
    </header>
    <main class="max-w-6xl mx-auto px-6 py-8">
        <div class="flex gap-2 mb-8 bg-gray-800 rounded-lg p-1 max-w-md">
            <button @click="activeTab = 'generate'" :class="activeTab === 'generate' ? 'bg-indigo-600' : 'hover:bg-gray-700'" class="flex-1 px-4 py-2 rounded-md">Gerar</button>
            <button @click="activeTab = 'batch'" :class="activeTab === 'batch' ? 'bg-indigo-600' : 'hover:bg-gray-700'" class="flex-1 px-4 py-2 rounded-md">Lote</button>
            <button @click="activeTab = 'history'; loadHistory()" :class="activeTab === 'history' ? 'bg-indigo-600' : 'hover:bg-gray-700'" class="flex-1 px-4 py-2 rounded-md">Historico</button>
        </div>
        <div x-show="activeTab === 'generate'" class="bg-gray-800 rounded-xl p-6 border border-gray-700">
            <h2 class="text-xl font-semibold mb-6">Gerar Video</h2>
            <div class="grid grid-cols-2 gap-4 mb-4">
                <div>
                    <label class="block text-sm text-gray-400 mb-2">Modelo de Imagem</label>
                    <select x-model="generateForm.imageModel" class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2">
                        <template x-for="m in imageModels" :key="m.id"><option :value="m.id" x-text="m.name"></option></template>
                    </select>
                </div>
                <div>
                    <label class="block text-sm text-gray-400 mb-2">Modelo de Video</label>
                    <select x-model="generateForm.videoModel" class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2">
                        <template x-for="m in videoModels" :key="m.id"><option :value="m.id" x-text="m.name"></option></template>
                    </select>
                </div>
            </div>
            <div class="mb-4">
                <label class="block text-sm text-gray-400 mb-2">Prompt</label>
                <textarea x-model="generateForm.prompt" rows="3" placeholder="Descreva o video..." class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-3"></textarea>
            </div>
            <button @click="generateVideo()" :disabled="isGenerating || !generateForm.prompt" :class="isGenerating ? 'opacity-50' : 'hover:bg-indigo-700'" class="w-full bg-indigo-600 font-semibold py-3 rounded-lg">
                <span x-show="!isGenerating">🚀 Gerar Video</span>
                <span x-show="isGenerating" class="animate-spin inline-block">⏳</span>
                <span x-show="isGenerating"> Gerando...</span>
            </button>
            <div x-show="isGenerating" class="mt-6">
                <div class="bg-gray-700 rounded-full h-2 mb-4"><div class="bg-indigo-500 h-2 rounded-full transition-all" :style="'width:' + progress + '%'"></div></div>
                <p class="text-center text-gray-400" x-text="statusMessage"></p>
            </div>
            <div x-show="lastGeneratedVideo" class="mt-6">
                <h3 class="text-lg font-semibold mb-4">Video Gerado:</h3>
                <video :src="lastGeneratedVideo" controls class="w-full rounded-lg"></video>
                <a :href="lastGeneratedVideo" download class="mt-4 block text-center bg-green-600 hover:bg-green-700 py-2 rounded-lg">⬇️ Download</a>
            </div>
        </div>
        <div x-show="activeTab === 'batch'" class="bg-gray-800 rounded-xl p-6 border border-gray-700">
            <h2 class="text-xl font-semibold mb-6">Geracao em Lote</h2>
            <div class="grid grid-cols-2 gap-4 mb-4">
                <div>
                    <label class="block text-sm text-gray-400 mb-2">Modelo de Imagem</label>
                    <select x-model="batchForm.imageModel" :disabled="batchRunning" class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2">
                        <template x-for="m in imageModels" :key="m.id"><option :value="m.id" x-text="m.name"></option></template>
                    </select>
                </div>
                <div>
                    <label class="block text-sm text-gray-400 mb-2">Modelo de Video</label>
                    <select x-model="batchForm.videoModel" :disabled="batchRunning" class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2">
                        <template x-for="m in videoModels" :key="m.id"><option :value="m.id" x-text="m.name"></option></template>
                    </select>
                </div>
            </div>
            <div class="mb-4">
                <label class="block text-sm text-gray-400 mb-2">Prompt</label>
                <textarea x-model="batchForm.prompt" :disabled="batchRunning" rows="2" class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-3"></textarea>
            </div>
            <div class="grid grid-cols-2 gap-4 mb-4">
                <div>
                    <label class="block text-sm text-gray-400 mb-2">Quantidade (0=infinito)</label>
                    <input type="number" x-model.number="batchForm.quantity" :disabled="batchRunning" min="0" class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2">
                </div>
                <div>
                    <label class="block text-sm text-gray-400 mb-2">Intervalo (seg)</label>
                    <input type="number" x-model.number="batchForm.interval" :disabled="batchRunning" min="10" class="w-full bg-gray-700 border border-gray-600 rounded-lg px-4 py-2">
                </div>
            </div>
            <div class="flex gap-3">
                <button @click="startBatch()" :disabled="batchRunning || !batchForm.prompt" :class="batchRunning ? 'opacity-50' : 'hover:bg-green-700'" class="flex-1 bg-green-600 font-semibold py-3 rounded-lg">▶️ Iniciar</button>
                <button @click="stopBatch()" :disabled="!batchRunning" :class="!batchRunning ? 'opacity-50' : 'hover:bg-red-700'" class="flex-1 bg-red-600 font-semibold py-3 rounded-lg">⏹️ Parar</button>
            </div>
            <div x-show="batchRunning || batchLogs.length" class="mt-6">
                <div class="flex justify-between text-sm mb-2">
                    <span>Progresso:</span>
                    <span x-text="batchCompleted + '/' + (batchTotal || '∞')"></span>
                </div>
                <div class="bg-gray-700 rounded-full h-3 mb-4"><div class="bg-green-500 h-3 rounded-full transition-all" :style="'width:' + batchPercentage + '%'"></div></div>
                <div class="bg-gray-900 rounded-lg p-4 h-40 overflow-y-auto font-mono text-sm">
                    <template x-for="(log, i) in batchLogs" :key="i"><div class="py-1" :class="log.includes('done') ? 'text-green-400' : 'text-gray-400'" x-text="log"></div></template>
                </div>
            </div>
        </div>
        <div x-show="activeTab === 'history'" class="bg-gray-800 rounded-xl p-6 border border-gray-700">
            <div class="flex justify-between items-center mb-6">
                <h2 class="text-xl font-semibold">Historico</h2>
                <button @click="loadHistory()" class="p-2 bg-gray-700 hover:bg-gray-600 rounded-lg">🔄</button>
            </div>
            <div class="text-sm text-gray-400 mb-4">
                Total: <span x-text="historyStats.total_videos || 0"></span> videos |
                Armazenamento: <span x-text="historyStats.storage_used_formatted || '0 B'"></span>
            </div>
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <template x-for="video in historyVideos" :key="video.id">
                    <div class="bg-gray-700 rounded-lg overflow-hidden group">
                        <div class="aspect-square relative">
                            <img :src="video.thumbnail_path || '/storage/thumbnails/placeholder.png'" class="w-full h-full object-cover">
                            <div class="absolute inset-0 bg-black/50 flex items-center justify-center opacity-0 group-hover:opacity-100 transition">
                                <button @click="playVideo(video)" class="p-2 bg-white/20 rounded-full">▶️</button>
                            </div>
                        </div>
                        <div class="p-2 flex justify-between">
                            <a :href="video.video_path" download class="text-indigo-400 text-sm">⬇️</a>
                            <button @click="deleteVideo(video.id)" class="text-red-400 text-sm">🗑️</button>
                        </div>
                    </div>
                </template>
            </div>
            <div x-show="historyVideos.length === 0" class="text-center py-12 text-gray-500">Nenhum video ainda</div>
        </div>
    </main>
    <div x-show="showSettings" x-cloak class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
        <div class="bg-gray-800 rounded-xl p-6 w-full max-w-md mx-4 border border-gray-700" @click.away="showSettings = false">
            <h3 class="text-xl font-semibold mb-6">Configuracoes</h3>
            <div class="mb-6">
                <label class="block text-sm text-gray-400 mb-2">API Key Freepik</label>
                <div class="flex gap-2">
                    <input type="password" x-model="newApiKey" placeholder="Cole sua API key" class="flex-1 bg-gray-700 border border-gray-600 rounded-lg px-4 py-2">
                    <button @click="saveApiKey()" :disabled="!newApiKey" class="px-4 py-2 bg-green-600 hover:bg-green-700 rounded-lg">Salvar</button>
                </div>
                <p x-show="apiKeyConfigured" class="mt-2 text-sm text-green-400">✓ Configurada: <span x-text="maskedApiKey"></span></p>
            </div>
            <div class="p-4 bg-gray-700 rounded-lg mb-6">
                <p class="text-sm text-gray-400 mb-2">Nao tem API key?</p>
                <a href="https://www.freepik.com/api" target="_blank" class="text-indigo-400 hover:text-indigo-300">Obter em freepik.com/api →</a>
            </div>
            <button @click="showSettings = false" class="w-full bg-gray-700 hover:bg-gray-600 py-2 rounded-lg">Fechar</button>
        </div>
    </div>
    <div x-show="showVideoPlayer" x-cloak class="fixed inset-0 bg-black/90 flex items-center justify-center z-50" @click.self="showVideoPlayer = false">
        <div class="w-full max-w-4xl mx-4">
            <video :src="currentVideo?.video_path" controls autoplay class="w-full rounded-lg"></video>
            <div class="mt-4 flex justify-end gap-3">
                <a :href="currentVideo?.video_path" download class="px-4 py-2 bg-green-600 hover:bg-green-700 rounded-lg">⬇️ Download</a>
                <button @click="showVideoPlayer = false" class="px-4 py-2 bg-gray-700 hover:bg-gray-600 rounded-lg">Fechar</button>
            </div>
        </div>
    </div>
    <div class="fixed bottom-4 right-4 z-50 space-y-2">
        <template x-for="(toast, i) in toasts" :key="i">
            <div x-show="toast.show" x-transition :class="toast.type === 'error' ? 'bg-red-600' : 'bg-green-600'" class="px-4 py-3 rounded-lg shadow-lg" x-text="toast.message"></div>
        </template>
    </div>
<script>
function app() {
    return {
        activeTab: 'generate', showSettings: false, showVideoPlayer: false,
        apiKeyConfigured: false, maskedApiKey: '', newApiKey: '',
        imageModels: [], videoModels: [],
        generateForm: { prompt: '', imageModel: 'mystic', videoModel: 'kling-std' },
        isGenerating: false, progress: 0, statusMessage: '', lastGeneratedVideo: null, currentVideoId: null,
        batchForm: { prompt: '', imageModel: 'mystic', videoModel: 'kling-std', quantity: 10, interval: 30 },
        batchRunning: false, batchCompleted: 0, batchTotal: 0, batchPercentage: 0, batchLogs: [], batchJobId: null,
        historyVideos: [], historyStats: {}, currentVideo: null, toasts: [], ws: null,
        async init() {
            await this.loadModels();
            await this.checkApiKey();
            await this.loadHistory();
            this.connectWebSocket();
        },
        connectWebSocket() {
            const wsUrl = `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}/ws/progress`;
            this.ws = new WebSocket(wsUrl);
            this.ws.onmessage = (e) => this.handleWsMessage(JSON.parse(e.data));
            this.ws.onclose = () => setTimeout(() => this.connectWebSocket(), 3000);
        },
        handleWsMessage(data) {
            if (data.type === 'progress' && data.video_id === this.currentVideoId) {
                this.progress = data.progress || 0;
                this.statusMessage = data.message || '';
            } else if (data.type === 'completed' && data.video_id === this.currentVideoId) {
                this.isGenerating = false;
                this.progress = 100;
                this.lastGeneratedVideo = data.video_path;
                this.showToast('Video gerado!', 'success');
                this.loadHistory();
            } else if (data.type === 'error' && data.video_id === this.currentVideoId) {
                this.isGenerating = false;
                this.showToast(data.message, 'error');
            } else if (data.type === 'batch_progress' && data.job_id === this.batchJobId) {
                this.batchCompleted = data.completed || 0;
                this.batchTotal = data.total || 0;
                this.batchPercentage = data.percentage || 0;
                if (data.log_message) {
                    this.batchLogs.unshift(`[${new Date().toLocaleTimeString()}] ${data.log_message}`);
                    if (this.batchLogs.length > 50) this.batchLogs.pop();
                }
                if (data.status === 'completed' || data.status === 'stopped') {
                    this.batchRunning = false;
                    this.loadHistory();
                }
            }
        },
        async loadModels() {
            try {
                const res = await fetch('/api/models');
                const data = await res.json();
                this.imageModels = data.image_models || [];
                this.videoModels = data.video_models || [];
            } catch {
                this.imageModels = [{ id: 'mystic', name: 'Mystic' }];
                this.videoModels = [{ id: 'kling-std', name: 'Kling Standard' }];
            }
        },
        async checkApiKey() {
            try {
                const res = await fetch('/api/settings/apikey');
                const data = await res.json();
                this.apiKeyConfigured = data.configured || false;
                this.maskedApiKey = data.masked_key || '';
            } catch {}
        },
        async saveApiKey() {
            if (!this.newApiKey) return;
            try {
                const res = await fetch('/api/settings/apikey', {
                    method: 'POST', headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ api_key: this.newApiKey })
                });
                const data = await res.json();
                if (res.ok) {
                    this.apiKeyConfigured = true;
                    this.maskedApiKey = data.masked_key;
                    this.newApiKey = '';
                    this.showToast('API Key salva!', 'success');
                } else {
                    this.showToast(data.detail || 'Erro', 'error');
                }
            } catch { this.showToast('Erro ao salvar', 'error'); }
        },
        async generateVideo() {
            if (!this.generateForm.prompt || !this.apiKeyConfigured) {
                if (!this.apiKeyConfigured) this.showSettings = true;
                return;
            }
            this.isGenerating = true;
            this.progress = 0;
            this.statusMessage = 'Iniciando...';
            this.lastGeneratedVideo = null;
            try {
                const res = await fetch('/api/generate', {
                    method: 'POST', headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(this.generateForm)
                });
                const data = await res.json();
                if (res.ok) {
                    this.currentVideoId = data.video_id;
                } else {
                    this.isGenerating = false;
                    this.showToast(data.detail || 'Erro', 'error');
                }
            } catch {
                this.isGenerating = false;
                this.showToast('Erro ao iniciar', 'error');
            }
        },
        async startBatch() {
            if (!this.batchForm.prompt || !this.apiKeyConfigured) return;
            try {
                const res = await fetch('/api/batch/start', {
                    method: 'POST', headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(this.batchForm)
                });
                const data = await res.json();
                if (res.ok) {
                    this.batchRunning = true;
                    this.batchJobId = data.job_id;
                    this.batchCompleted = 0;
                    this.batchTotal = this.batchForm.quantity;
                    this.batchLogs = [];
                } else {
                    this.showToast(data.detail || 'Erro', 'error');
                }
            } catch { this.showToast('Erro', 'error'); }
        },
        async stopBatch() {
            try {
                await fetch('/api/batch/stop', { method: 'POST' });
                this.batchRunning = false;
            } catch {}
        },
        async loadHistory() {
            try {
                const [histRes, statsRes] = await Promise.all([fetch('/api/history?limit=20'), fetch('/api/history/stats')]);
                const histData = await histRes.json();
                const statsData = await statsRes.json();
                this.historyVideos = histData.videos || [];
                this.historyStats = statsData;
            } catch {}
        },
        playVideo(video) { this.currentVideo = video; this.showVideoPlayer = true; },
        async deleteVideo(id) {
            if (!confirm('Deletar video?')) return;
            try {
                await fetch(`/api/history/${id}`, { method: 'DELETE' });
                this.loadHistory();
            } catch {}
        },
        showToast(message, type = 'info') {
            const toast = { message, type, show: true };
            this.toasts.push(toast);
            setTimeout(() => { toast.show = false; setTimeout(() => this.toasts.splice(this.toasts.indexOf(toast), 1), 300); }, 4000);
        }
    };
}
</script>
</body>
</html>
HTMLEOF

log "Frontend criado"

# =============================================================================
# PASSO 5: CONFIGURAR AMBIENTE PYTHON
# =============================================================================
log_step "[5/7] Configurando Python..."
cd ${INSTALL_DIR}
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r backend/requirements.txt -q
log "Python configurado"

# =============================================================================
# PASSO 6: CONFIGURAR NGINX
# =============================================================================
log_step "[6/7] Configurando Nginx..."

cat > /etc/nginx/sites-available/${SERVICE_NAME} << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location / {
        root /opt/viral-video-saas/frontend;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    location /ws {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 86400s;
    }

    location /storage {
        alias /opt/viral-video-saas/storage;
        expires 30d;
    }

    client_max_body_size 100M;
}
NGINXEOF

ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx && systemctl enable nginx
log "Nginx configurado"

# =============================================================================
# PASSO 7: CRIAR E INICIAR SERVICO
# =============================================================================
log_step "[7/7] Criando servico..."

cat > /etc/systemd/system/${SERVICE_NAME}.service << SVCEOF
[Unit]
Description=Viral Video SaaS
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=${INSTALL_DIR}/backend
Environment="PATH=${INSTALL_DIR}/venv/bin"
Environment="PYTHONPATH=${INSTALL_DIR}/backend"
ExecStart=${INSTALL_DIR}/venv/bin/uvicorn app:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

chown -R www-data:www-data ${INSTALL_DIR}
chmod -R 755 ${INSTALL_DIR}
chmod -R 775 ${INSTALL_DIR}/storage

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

sleep 3

# =============================================================================
# RESULTADO
# =============================================================================
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║                    ✅ INSTALACAO CONCLUIDA!                               ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${YELLOW}ACESSE:${NC} http://${IP}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Proximos passos:${NC}"
echo "  1. Abra http://${IP} no navegador"
echo "  2. Clique em ⚙️ (configuracoes)"
echo "  3. Cole sua API Key do Freepik"
echo "  4. Comece a gerar videos!"
echo ""
echo -e "  ${YELLOW}Obtenha sua API Key em:${NC}"
echo "  https://www.freepik.com/api"
echo "  (Voce ganha 5 EUR em creditos gratis!)"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo "  Comandos uteis:"
echo "    sudo systemctl status ${SERVICE_NAME}"
echo "    sudo journalctl -u ${SERVICE_NAME} -f"
echo "    sudo systemctl restart ${SERVICE_NAME}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
