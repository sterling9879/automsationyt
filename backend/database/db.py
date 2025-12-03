"""
Database configuration and models
Using SQLite with aiosqlite for async operations
"""

import aiosqlite
import os
from datetime import datetime
from typing import Optional, List, Dict, Any

DATABASE_PATH = "/home/user/automsationyt/backend/database/viral_saas.db"


async def get_db():
    """Get database connection"""
    db = await aiosqlite.connect(DATABASE_PATH)
    db.row_factory = aiosqlite.Row
    return db


async def init_db():
    """Initialize database tables"""
    os.makedirs(os.path.dirname(DATABASE_PATH), exist_ok=True)

    async with aiosqlite.connect(DATABASE_PATH) as db:
        # Videos table
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

        # Batch jobs table
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

        # Settings table
        await db.execute("""
            CREATE TABLE IF NOT EXISTS settings (
                key VARCHAR(100) PRIMARY KEY,
                value TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        await db.commit()
        print("Database initialized successfully")


# Video CRUD operations
async def create_video(
    prompt: str,
    image_model: str,
    video_model: str,
    status: str = "pending"
) -> int:
    """Create a new video record"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute(
            """
            INSERT INTO videos (prompt, image_model, video_model, status, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (prompt, image_model, video_model, status, datetime.now().isoformat())
        )
        await db.commit()
        return cursor.lastrowid


async def update_video(video_id: int, **kwargs) -> None:
    """Update video record"""
    if not kwargs:
        return

    set_clause = ", ".join([f"{k} = ?" for k in kwargs.keys()])
    values = list(kwargs.values()) + [video_id]

    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute(
            f"UPDATE videos SET {set_clause} WHERE id = ?",
            values
        )
        await db.commit()


async def get_video(video_id: int) -> Optional[Dict[str, Any]]:
    """Get video by ID"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute(
            "SELECT * FROM videos WHERE id = ?",
            (video_id,)
        )
        row = await cursor.fetchone()
        return dict(row) if row else None


async def get_videos(
    page: int = 1,
    limit: int = 20,
    search: Optional[str] = None
) -> Dict[str, Any]:
    """Get paginated videos list"""
    offset = (page - 1) * limit

    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row

        # Count total
        if search:
            cursor = await db.execute(
                "SELECT COUNT(*) as count FROM videos WHERE prompt LIKE ?",
                (f"%{search}%",)
            )
        else:
            cursor = await db.execute("SELECT COUNT(*) as count FROM videos")

        total_row = await cursor.fetchone()
        total = total_row['count']

        # Get videos
        if search:
            cursor = await db.execute(
                """
                SELECT * FROM videos
                WHERE prompt LIKE ?
                ORDER BY created_at DESC
                LIMIT ? OFFSET ?
                """,
                (f"%{search}%", limit, offset)
            )
        else:
            cursor = await db.execute(
                """
                SELECT * FROM videos
                ORDER BY created_at DESC
                LIMIT ? OFFSET ?
                """,
                (limit, offset)
            )

        rows = await cursor.fetchall()
        videos = [dict(row) for row in rows]

        return {
            "videos": videos,
            "total": total,
            "page": page,
            "limit": limit,
            "total_pages": (total + limit - 1) // limit
        }


async def delete_video(video_id: int) -> bool:
    """Delete video by ID"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute(
            "DELETE FROM videos WHERE id = ?",
            (video_id,)
        )
        await db.commit()
        return cursor.rowcount > 0


async def get_storage_stats() -> Dict[str, Any]:
    """Get storage statistics"""
    import os

    storage_path = "/home/user/automsationyt/storage"
    total_size = 0

    for dirpath, dirnames, filenames in os.walk(storage_path):
        for f in filenames:
            fp = os.path.join(dirpath, f)
            total_size += os.path.getsize(fp)

    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute("SELECT COUNT(*) as count FROM videos")
        row = await cursor.fetchone()
        total_videos = row[0]

    return {
        "total_videos": total_videos,
        "storage_used_bytes": total_size,
        "storage_used_formatted": format_size(total_size)
    }


def format_size(size_bytes: int) -> str:
    """Format bytes to human readable"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if size_bytes < 1024.0:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024.0
    return f"{size_bytes:.1f} PB"


# Batch job operations
async def create_batch_job(
    prompt: str,
    image_model: str,
    video_model: str,
    total_quantity: int,
    interval_seconds: int
) -> int:
    """Create a new batch job"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute(
            """
            INSERT INTO batch_jobs
            (prompt, image_model, video_model, total_quantity, interval_seconds, status, started_at)
            VALUES (?, ?, ?, ?, ?, 'running', ?)
            """,
            (prompt, image_model, video_model, total_quantity, interval_seconds, datetime.now().isoformat())
        )
        await db.commit()
        return cursor.lastrowid


async def update_batch_job(job_id: int, **kwargs) -> None:
    """Update batch job"""
    if not kwargs:
        return

    set_clause = ", ".join([f"{k} = ?" for k in kwargs.keys()])
    values = list(kwargs.values()) + [job_id]

    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute(
            f"UPDATE batch_jobs SET {set_clause} WHERE id = ?",
            values
        )
        await db.commit()


async def get_batch_job(job_id: int) -> Optional[Dict[str, Any]]:
    """Get batch job by ID"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute(
            "SELECT * FROM batch_jobs WHERE id = ?",
            (job_id,)
        )
        row = await cursor.fetchone()
        return dict(row) if row else None


async def get_running_batch_job() -> Optional[Dict[str, Any]]:
    """Get currently running batch job"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute(
            "SELECT * FROM batch_jobs WHERE status = 'running' ORDER BY started_at DESC LIMIT 1"
        )
        row = await cursor.fetchone()
        return dict(row) if row else None


# Settings operations
async def get_setting(key: str) -> Optional[str]:
    """Get setting value"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        cursor = await db.execute(
            "SELECT value FROM settings WHERE key = ?",
            (key,)
        )
        row = await cursor.fetchone()
        return row[0] if row else None


async def set_setting(key: str, value: str) -> None:
    """Set setting value"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute(
            """
            INSERT INTO settings (key, value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET value = ?, updated_at = ?
            """,
            (key, value, datetime.now().isoformat(), value, datetime.now().isoformat())
        )
        await db.commit()
