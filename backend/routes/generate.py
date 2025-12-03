"""
Video Generation Routes
Handles single video generation requests
"""

import os
import uuid
import asyncio
from datetime import datetime
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional

from database.db import (
    create_video, update_video, get_video, get_setting
)
from services.freepik_api import (
    FreepikService, download_image, download_video, image_to_base64
)
from services.websocket_manager import manager

router = APIRouter()

STORAGE_PATH = "/home/user/automsationyt/storage"


class GenerateRequest(BaseModel):
    prompt: str
    image_model: str = "mystic"
    video_model: str = "kling-std"
    api_key: Optional[str] = None


class GenerateResponse(BaseModel):
    success: bool
    video_id: Optional[int] = None
    message: str
    task_id: Optional[str] = None


async def process_video_generation(
    video_id: int,
    prompt: str,
    image_model: str,
    video_model: str,
    api_key: str
):
    """Background task to process video generation"""
    try:
        freepik = FreepikService(api_key)

        # Step 1: Generate image
        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="image_generating",
            progress=10,
            message="Generating image..."
        )

        image_result = await freepik.generate_image(
            prompt=prompt,
            model=image_model,
            resolution="2k",
            aspect_ratio="square_1_1"
        )

        if not image_result["success"]:
            raise Exception(f"Image generation failed: {image_result.get('error')}")

        task_id = image_result["task_id"]

        # Step 2: Wait for image completion
        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="image_processing",
            progress=25,
            message="Processing image..."
        )

        image_status = await freepik.wait_for_image(task_id)

        if not image_status["success"]:
            raise Exception(f"Image processing failed: {image_status.get('error')}")

        image_url = image_status.get("image_url")
        if not image_url:
            raise Exception("No image URL returned")

        # Update database with image URL
        await update_video(video_id, image_url=image_url)

        # Step 3: Download and convert image to base64
        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="image_downloading",
            progress=40,
            message="Downloading image..."
        )

        image_bytes = await download_image(image_url)
        if not image_bytes:
            raise Exception("Failed to download generated image")

        # Save image locally
        image_filename = f"{uuid.uuid4()}.png"
        image_path = os.path.join(STORAGE_PATH, "images", image_filename)
        with open(image_path, "wb") as f:
            f.write(image_bytes)

        image_base64 = image_to_base64(image_bytes)

        # Step 4: Generate video from image
        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="video_generating",
            progress=55,
            message="Generating video..."
        )

        video_result = await freepik.generate_video(
            image_base64=image_base64,
            model=video_model,
            prompt=prompt,
            duration="5"
        )

        if not video_result["success"]:
            raise Exception(f"Video generation failed: {video_result.get('error')}")

        video_task_id = video_result["task_id"]

        # Step 5: Wait for video completion
        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="video_processing",
            progress=70,
            message="Processing video..."
        )

        video_status = await freepik.wait_for_video(video_task_id, video_model)

        if not video_status["success"]:
            raise Exception(f"Video processing failed: {video_status.get('error')}")

        video_url = video_status.get("video_url")
        if not video_url:
            raise Exception("No video URL returned")

        # Step 6: Download video
        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="video_downloading",
            progress=85,
            message="Downloading video..."
        )

        video_bytes = await download_video(video_url)
        if not video_bytes:
            raise Exception("Failed to download generated video")

        # Save video locally
        video_filename = f"{uuid.uuid4()}.mp4"
        video_path = os.path.join(STORAGE_PATH, "videos", video_filename)
        with open(video_path, "wb") as f:
            f.write(video_bytes)

        # Create thumbnail (use the image as thumbnail)
        thumbnail_filename = f"{uuid.uuid4()}.png"
        thumbnail_path = os.path.join(STORAGE_PATH, "thumbnails", thumbnail_filename)
        with open(thumbnail_path, "wb") as f:
            f.write(image_bytes)

        # Step 7: Finalize
        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="finalizing",
            progress=95,
            message="Finalizing..."
        )

        # Update database
        await update_video(
            video_id,
            video_url=video_url,
            video_path=f"/storage/videos/{video_filename}",
            thumbnail_path=f"/storage/thumbnails/{thumbnail_filename}",
            status="completed",
            completed_at=datetime.now().isoformat()
        )

        # Send completion
        await manager.send_completion(
            video_id=video_id,
            video_path=f"/storage/videos/{video_filename}",
            thumbnail_path=f"/storage/thumbnails/{thumbnail_filename}"
        )

        await manager.send_progress(
            "progress",
            video_id=video_id,
            step="completed",
            progress=100,
            message="Video generated successfully!"
        )

    except Exception as e:
        error_message = str(e)
        await update_video(
            video_id,
            status="failed",
            error_message=error_message
        )
        await manager.send_error(error_message, video_id)


@router.post("/generate", response_model=GenerateResponse)
async def generate_video(request: GenerateRequest, background_tasks: BackgroundTasks):
    """
    Generate a video from prompt

    1. Creates a database record
    2. Starts background generation process
    3. Returns video_id for tracking
    """
    # Get API key
    api_key = request.api_key
    if not api_key:
        api_key = await get_setting("freepik_api_key")

    if not api_key:
        raise HTTPException(
            status_code=400,
            detail="No API key provided. Please save your Freepik API key first."
        )

    # Create video record
    video_id = await create_video(
        prompt=request.prompt,
        image_model=request.image_model,
        video_model=request.video_model,
        status="processing"
    )

    # Start background generation
    background_tasks.add_task(
        process_video_generation,
        video_id=video_id,
        prompt=request.prompt,
        image_model=request.image_model,
        video_model=request.video_model,
        api_key=api_key
    )

    return GenerateResponse(
        success=True,
        video_id=video_id,
        message="Video generation started"
    )


@router.get("/generate/{video_id}")
async def get_generation_status(video_id: int):
    """Get status of video generation"""
    video = await get_video(video_id)

    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    return {
        "success": True,
        "video": video
    }
