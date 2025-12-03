"""
Models Routes
Return available Freepik AI models
"""

from fastapi import APIRouter
from services.freepik_api import FreepikService

router = APIRouter()


@router.get("/models/image")
async def list_image_models():
    """Get available image generation models"""
    models = FreepikService.get_image_models()
    return {
        "success": True,
        "models": models
    }


@router.get("/models/video")
async def list_video_models():
    """Get available video generation models"""
    models = FreepikService.get_video_models()
    return {
        "success": True,
        "models": models
    }


@router.get("/models")
async def list_all_models():
    """Get all available models"""
    return {
        "success": True,
        "image_models": FreepikService.get_image_models(),
        "video_models": FreepikService.get_video_models()
    }
