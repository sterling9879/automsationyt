"""
Models Routes
Return available Freepik AI models - fetches dynamically from API
"""

from fastapi import APIRouter
from services.freepik_api import FreepikService
from database import get_setting

router = APIRouter()


async def get_freepik_service():
    """Get FreepikService instance with API key from settings"""
    api_key = await get_setting("freepik_api_key")
    if api_key:
        return FreepikService(api_key)
    return None


@router.get("/models/image")
async def list_image_models():
    """Get available image generation models - fetches from API if possible"""
    service = await get_freepik_service()

    if service:
        # Try to fetch from API
        models = await service.fetch_image_models()
    else:
        # No API key, return fallback models
        models = FreepikService.get_image_models()

    return {
        "success": True,
        "models": models
    }


@router.get("/models/video")
async def list_video_models():
    """Get available video generation models - fetches from API if possible"""
    service = await get_freepik_service()

    if service:
        # Try to fetch from API
        models = await service.fetch_video_models()
    else:
        # No API key, return fallback models
        models = FreepikService.get_video_models()

    return {
        "success": True,
        "models": models
    }


@router.get("/models")
async def list_all_models():
    """Get all available models - fetches from API if possible"""
    service = await get_freepik_service()

    if service:
        # Fetch both from API concurrently
        import asyncio
        image_models, video_models = await asyncio.gather(
            service.fetch_image_models(),
            service.fetch_video_models()
        )
    else:
        # No API key, return fallback models
        image_models = FreepikService.get_image_models()
        video_models = FreepikService.get_video_models()

    return {
        "success": True,
        "image_models": image_models,
        "video_models": video_models
    }
