"""
WebSocket Manager for real-time progress updates
"""

from typing import List, Dict, Any
from fastapi import WebSocket
import json


class ConnectionManager:
    """Manage WebSocket connections"""

    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        """Accept and store WebSocket connection"""
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        """Remove WebSocket connection"""
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def send_personal_message(self, message: str, websocket: WebSocket):
        """Send message to specific connection"""
        await websocket.send_text(message)

    async def broadcast(self, message: Dict[str, Any]):
        """Broadcast message to all connections"""
        message_str = json.dumps(message)
        disconnected = []

        for connection in self.active_connections:
            try:
                await connection.send_text(message_str)
            except Exception:
                disconnected.append(connection)

        # Clean up disconnected
        for conn in disconnected:
            self.disconnect(conn)

    async def send_progress(
        self,
        event_type: str,
        video_id: int = None,
        step: str = None,
        progress: int = None,
        message: str = None,
        data: Dict[str, Any] = None
    ):
        """Send progress update"""
        payload = {
            "type": event_type,
            "video_id": video_id,
            "step": step,
            "progress": progress,
            "message": message,
            "data": data or {}
        }
        await self.broadcast(payload)

    async def send_batch_progress(
        self,
        job_id: int,
        completed: int,
        total: int,
        current_video_id: int = None,
        status: str = "running",
        log_message: str = None
    ):
        """Send batch job progress update"""
        payload = {
            "type": "batch_progress",
            "job_id": job_id,
            "completed": completed,
            "total": total,
            "current_video_id": current_video_id,
            "status": status,
            "log_message": log_message,
            "percentage": (completed / total * 100) if total > 0 else 0
        }
        await self.broadcast(payload)

    async def send_error(self, error_message: str, video_id: int = None):
        """Send error message"""
        payload = {
            "type": "error",
            "video_id": video_id,
            "message": error_message
        }
        await self.broadcast(payload)

    async def send_completion(self, video_id: int, video_path: str, thumbnail_path: str = None):
        """Send completion message"""
        payload = {
            "type": "completed",
            "video_id": video_id,
            "video_path": video_path,
            "thumbnail_path": thumbnail_path
        }
        await self.broadcast(payload)


# Global manager instance
manager = ConnectionManager()
