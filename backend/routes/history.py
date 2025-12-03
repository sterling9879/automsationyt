"""
History Routes
Manage video history and storage
"""

import os
from fastapi import APIRouter, HTTPException, Query
from typing import Optional

from database.db import (
    get_videos, get_video, delete_video, get_storage_stats
)

router = APIRouter()

STORAGE_PATH = "/home/user/automsationyt/storage"


@router.get("/history")
async def list_history(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None
):
    """
    Get paginated video history

    - page: Page number (starts at 1)
    - limit: Items per page (max 100)
    - search: Optional search term for prompts
    """
    result = await get_videos(page=page, limit=limit, search=search)
    return result


@router.get("/history/stats")
async def get_history_stats():
    """Get storage statistics"""
    stats = await get_storage_stats()
    return stats


@router.get("/history/{video_id}")
async def get_video_details(video_id: int):
    """Get details of a specific video"""
    video = await get_video(video_id)

    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    return {"success": True, "video": video}


@router.delete("/history/{video_id}")
async def delete_video_entry(video_id: int):
    """
    Delete a video and its associated files

    - Removes database entry
    - Deletes video file
    - Deletes thumbnail file
    """
    video = await get_video(video_id)

    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    # Delete files if they exist
    if video.get("video_path"):
        video_file = os.path.join(
            STORAGE_PATH,
            video["video_path"].replace("/storage/", "")
        )
        if os.path.exists(video_file):
            os.remove(video_file)

    if video.get("thumbnail_path"):
        thumbnail_file = os.path.join(
            STORAGE_PATH,
            video["thumbnail_path"].replace("/storage/", "")
        )
        if os.path.exists(thumbnail_file):
            os.remove(thumbnail_file)

    # Delete database entry
    deleted = await delete_video(video_id)

    if not deleted:
        raise HTTPException(status_code=500, detail="Failed to delete video")

    return {"success": True, "message": "Video deleted successfully"}


@router.delete("/history/bulk/all")
async def delete_all_videos():
    """Delete all videos (use with caution)"""
    import aiosqlite
    from database.db import DATABASE_PATH

    # Get all videos
    result = await get_videos(page=1, limit=10000)

    # Delete files
    for video in result["videos"]:
        if video.get("video_path"):
            video_file = os.path.join(
                STORAGE_PATH,
                video["video_path"].replace("/storage/", "")
            )
            if os.path.exists(video_file):
                os.remove(video_file)

        if video.get("thumbnail_path"):
            thumbnail_file = os.path.join(
                STORAGE_PATH,
                video["thumbnail_path"].replace("/storage/", "")
            )
            if os.path.exists(thumbnail_file):
                os.remove(thumbnail_file)

    # Clear database
    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute("DELETE FROM videos")
        await db.commit()

    return {"success": True, "message": "All videos deleted"}
