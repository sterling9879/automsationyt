"""
Batch Generation Routes
Handle mass video generation in loops
"""

import os
import uuid
import asyncio
from datetime import datetime
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, Dict, Any

from database.db import (
    create_video, update_video, get_setting,
    create_batch_job, update_batch_job, get_batch_job, get_running_batch_job
)
from services.freepik_api import (
    FreepikService, download_image, download_video, image_to_base64
)
from services.websocket_manager import manager

router = APIRouter()

STORAGE_PATH = "/home/user/automsationyt/storage"

# Global batch job control
batch_jobs: Dict[int, Dict[str, Any]] = {}


class BatchStartRequest(BaseModel):
    prompt: str
    image_model: str = "mystic"
    video_model: str = "kling-std"
    quantity: int = 10  # 0 = infinite
    interval: int = 30  # seconds between generations
    api_key: Optional[str] = None


class BatchResponse(BaseModel):
    success: bool
    message: str
    job_id: Optional[int] = None


async def process_batch_generation(
    job_id: int,
    prompt: str,
    image_model: str,
    video_model: str,
    api_key: str,
    quantity: int,
    interval: int
):
    """Background task to process batch video generation"""
    global batch_jobs

    completed = 0
    freepik = FreepikService(api_key)

    try:
        while True:
            # Check if should stop
            if job_id in batch_jobs and batch_jobs[job_id].get("should_stop"):
                await update_batch_job(
                    job_id,
                    status="stopped",
                    stopped_at=datetime.now().isoformat()
                )
                await manager.send_batch_progress(
                    job_id=job_id,
                    completed=completed,
                    total=quantity,
                    status="stopped",
                    log_message="Batch job stopped by user"
                )
                break

            # Check if reached quantity limit
            if quantity > 0 and completed >= quantity:
                await update_batch_job(
                    job_id,
                    status="completed",
                    stopped_at=datetime.now().isoformat()
                )
                await manager.send_batch_progress(
                    job_id=job_id,
                    completed=completed,
                    total=quantity,
                    status="completed",
                    log_message="Batch job completed successfully!"
                )
                break

            current_number = completed + 1

            try:
                # Create video record
                video_id = await create_video(
                    prompt=prompt,
                    image_model=image_model,
                    video_model=video_model,
                    status="processing"
                )

                await manager.send_batch_progress(
                    job_id=job_id,
                    completed=completed,
                    total=quantity,
                    current_video_id=video_id,
                    status="running",
                    log_message=f"Starting video #{current_number}..."
                )

                # Generate image
                await manager.send_batch_progress(
                    job_id=job_id,
                    completed=completed,
                    total=quantity,
                    status="running",
                    log_message=f"Generating image #{current_number}..."
                )

                image_result = await freepik.generate_image(
                    prompt=prompt,
                    model=image_model,
                    resolution="2k",
                    aspect_ratio="square_1_1"
                )

                if not image_result["success"]:
                    raise Exception(f"Image generation failed: {image_result.get('error')}")

                # Wait for image
                image_status = await freepik.wait_for_image(image_result["task_id"])

                if not image_status["success"]:
                    raise Exception(f"Image processing failed: {image_status.get('error')}")

                image_url = image_status.get("image_url")
                await update_video(video_id, image_url=image_url)

                # Download image
                image_bytes = await download_image(image_url)
                if not image_bytes:
                    raise Exception("Failed to download image")

                # Save image
                image_filename = f"{uuid.uuid4()}.png"
                image_path = os.path.join(STORAGE_PATH, "images", image_filename)
                with open(image_path, "wb") as f:
                    f.write(image_bytes)

                image_base64 = image_to_base64(image_bytes)

                await manager.send_batch_progress(
                    job_id=job_id,
                    completed=completed,
                    total=quantity,
                    status="running",
                    log_message=f"Image #{current_number} validated, animating..."
                )

                # Generate video
                video_result = await freepik.generate_video(
                    image_base64=image_base64,
                    model=video_model,
                    prompt=prompt,
                    duration="5"
                )

                if not video_result["success"]:
                    raise Exception(f"Video generation failed: {video_result.get('error')}")

                # Wait for video
                video_status = await freepik.wait_for_video(
                    video_result["task_id"],
                    video_model
                )

                if not video_status["success"]:
                    raise Exception(f"Video processing failed: {video_status.get('error')}")

                video_url = video_status.get("video_url")

                # Download video
                video_bytes = await download_video(video_url)
                if not video_bytes:
                    raise Exception("Failed to download video")

                # Save video
                video_filename = f"{uuid.uuid4()}.mp4"
                video_path = os.path.join(STORAGE_PATH, "videos", video_filename)
                with open(video_path, "wb") as f:
                    f.write(video_bytes)

                # Save thumbnail
                thumbnail_filename = f"{uuid.uuid4()}.png"
                thumbnail_path = os.path.join(STORAGE_PATH, "thumbnails", thumbnail_filename)
                with open(thumbnail_path, "wb") as f:
                    f.write(image_bytes)

                # Update video record
                await update_video(
                    video_id,
                    video_url=video_url,
                    video_path=f"/storage/videos/{video_filename}",
                    thumbnail_path=f"/storage/thumbnails/{thumbnail_filename}",
                    status="completed",
                    completed_at=datetime.now().isoformat()
                )

                completed += 1

                # Update batch job
                await update_batch_job(job_id, completed_count=completed)

                await manager.send_batch_progress(
                    job_id=job_id,
                    completed=completed,
                    total=quantity,
                    status="running",
                    log_message=f"Video #{current_number} generated successfully!"
                )

                # Wait interval before next generation
                if quantity == 0 or completed < quantity:
                    await asyncio.sleep(interval)

            except Exception as e:
                error_msg = str(e)
                await manager.send_batch_progress(
                    job_id=job_id,
                    completed=completed,
                    total=quantity,
                    status="running",
                    log_message=f"Error on video #{current_number}: {error_msg}. Retrying..."
                )

                # Wait before retry
                await asyncio.sleep(5)
                continue

    except asyncio.CancelledError:
        await update_batch_job(
            job_id,
            status="stopped",
            stopped_at=datetime.now().isoformat()
        )
    except Exception as e:
        await update_batch_job(
            job_id,
            status="failed",
            stopped_at=datetime.now().isoformat()
        )
        await manager.send_batch_progress(
            job_id=job_id,
            completed=completed,
            total=quantity,
            status="failed",
            log_message=f"Batch job failed: {str(e)}"
        )
    finally:
        # Cleanup
        if job_id in batch_jobs:
            del batch_jobs[job_id]


@router.post("/batch/start", response_model=BatchResponse)
async def start_batch_generation(request: BatchStartRequest, background_tasks: BackgroundTasks):
    """
    Start batch video generation

    - quantity: Number of videos to generate (0 = infinite loop)
    - interval: Seconds to wait between generations
    """
    global batch_jobs

    # Check for existing running job
    running = await get_running_batch_job()
    if running:
        raise HTTPException(
            status_code=400,
            detail="A batch job is already running. Stop it first."
        )

    # Get API key
    api_key = request.api_key
    if not api_key:
        api_key = await get_setting("freepik_api_key")

    if not api_key:
        raise HTTPException(
            status_code=400,
            detail="No API key provided. Please save your Freepik API key first."
        )

    # Create batch job record
    job_id = await create_batch_job(
        prompt=request.prompt,
        image_model=request.image_model,
        video_model=request.video_model,
        total_quantity=request.quantity,
        interval_seconds=request.interval
    )

    # Initialize job control
    batch_jobs[job_id] = {"should_stop": False}

    # Start background task
    task = asyncio.create_task(
        process_batch_generation(
            job_id=job_id,
            prompt=request.prompt,
            image_model=request.image_model,
            video_model=request.video_model,
            api_key=api_key,
            quantity=request.quantity,
            interval=request.interval
        )
    )

    batch_jobs[job_id]["task"] = task

    return BatchResponse(
        success=True,
        message="Batch generation started",
        job_id=job_id
    )


@router.post("/batch/stop")
async def stop_batch_generation():
    """Stop the currently running batch job"""
    global batch_jobs

    running = await get_running_batch_job()

    if not running:
        raise HTTPException(
            status_code=400,
            detail="No batch job is currently running"
        )

    job_id = running["id"]

    # Signal to stop
    if job_id in batch_jobs:
        batch_jobs[job_id]["should_stop"] = True

        # Give it a moment to stop gracefully
        await asyncio.sleep(1)

        # Force cancel if still running
        if "task" in batch_jobs[job_id] and not batch_jobs[job_id]["task"].done():
            batch_jobs[job_id]["task"].cancel()

    # Update database
    await update_batch_job(
        job_id,
        status="stopped",
        stopped_at=datetime.now().isoformat()
    )

    return {
        "success": True,
        "message": "Batch job stopped",
        "job_id": job_id
    }


@router.get("/batch/status")
async def get_batch_status():
    """Get status of current/recent batch job"""
    running = await get_running_batch_job()

    if running:
        return {
            "success": True,
            "running": True,
            "job": running
        }

    # Get most recent job
    import aiosqlite
    from database.db import DATABASE_PATH

    async with aiosqlite.connect(DATABASE_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute(
            "SELECT * FROM batch_jobs ORDER BY started_at DESC LIMIT 1"
        )
        row = await cursor.fetchone()

        if row:
            return {
                "success": True,
                "running": False,
                "job": dict(row)
            }

    return {
        "success": True,
        "running": False,
        "job": None
    }


@router.get("/batch/{job_id}")
async def get_batch_job_details(job_id: int):
    """Get details of a specific batch job"""
    job = await get_batch_job(job_id)

    if not job:
        raise HTTPException(status_code=404, detail="Batch job not found")

    return {
        "success": True,
        "job": job
    }
