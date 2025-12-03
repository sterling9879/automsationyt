"""
Freepik API Integration Service
Handles image generation and video animation
Fetches models dynamically from API
"""

import aiohttp
import asyncio
import base64
from typing import Optional, Dict, Any, List
from datetime import datetime

# Cache for models
_models_cache = {
    "image_models": None,
    "video_models": None,
    "last_fetch": None
}


class FreepikService:
    """Service for interacting with Freepik API"""

    BASE_URL = "https://api.freepik.com/v1"

    # Fallback models if API fails
    FALLBACK_IMAGE_MODELS = [
        {"id": "realism", "name": "Realism", "description": "Realistic photos with natural colors"},
        {"id": "flux", "name": "Flux", "description": "Creative and artistic images (Google Imagen 3)"},
        {"id": "mystic", "name": "Mystic", "description": "Ultra-realistic high resolution images"},
        {"id": "zen", "name": "Zen", "description": "Clean and minimalist results"},
        {"id": "flexible", "name": "Flexible", "description": "Great for illustrations and fantasy"},
        {"id": "super_real", "name": "Super Real", "description": "Maximum realism priority"},
        {"id": "editorial_portraits", "name": "Editorial Portraits", "description": "Professional portrait photos"},
    ]

    FALLBACK_VIDEO_MODELS = [
        {"id": "kling-std", "name": "Kling Standard 1.6", "description": "Standard quality, faster rendering"},
        {"id": "kling-pro", "name": "Kling Pro 1.6", "description": "High quality professional videos"},
        {"id": "kling-v2", "name": "Kling V2", "description": "Latest Kling model with improvements"},
        {"id": "minimax-768p", "name": "MiniMax Hailuo 768p", "description": "Good for facial expressions"},
        {"id": "minimax-1080p", "name": "MiniMax Hailuo 1080p", "description": "High definition 1080p"},
    ]

    def __init__(self, api_key: str):
        self.api_key = api_key
        self.headers = {
            "x-freepik-api-key": api_key,
            "Content-Type": "application/json"
        }

    async def validate_api_key(self) -> Dict[str, Any]:
        """Validate API key by making a simple request"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.BASE_URL}/resources?limit=1",
                    headers=self.headers,
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as response:
                    if response.status == 200:
                        return {"valid": True, "message": "API key is valid"}
                    elif response.status == 401:
                        return {"valid": False, "message": "Invalid API key"}
                    else:
                        return {"valid": False, "message": f"Error: {response.status}"}
        except Exception as e:
            return {"valid": False, "message": str(e)}

    async def fetch_image_models(self) -> List[Dict[str, Any]]:
        """Fetch available image models from Freepik API"""
        global _models_cache

        # Return cache if fresh (less than 1 hour)
        if _models_cache["image_models"] and _models_cache["last_fetch"]:
            elapsed = (datetime.now() - _models_cache["last_fetch"]).seconds
            if elapsed < 3600:
                return _models_cache["image_models"]

        try:
            async with aiohttp.ClientSession() as session:
                # Try to get models from Mystic API info
                async with session.get(
                    f"{self.BASE_URL}/ai/mystic/models",
                    headers=self.headers,
                    timeout=aiohttp.ClientTimeout(total=15)
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        models = data.get("data", {}).get("models", [])
                        if models:
                            formatted_models = []
                            for model in models:
                                formatted_models.append({
                                    "id": model.get("id", model.get("name", "")),
                                    "name": model.get("name", model.get("id", "")),
                                    "description": model.get("description", "")
                                })
                            _models_cache["image_models"] = formatted_models
                            _models_cache["last_fetch"] = datetime.now()
                            return formatted_models
        except Exception:
            pass

        # Fallback to hardcoded models
        return self.FALLBACK_IMAGE_MODELS

    async def fetch_video_models(self) -> List[Dict[str, Any]]:
        """Fetch available video models from Freepik API"""
        global _models_cache

        # Return cache if fresh (less than 1 hour)
        if _models_cache["video_models"] and _models_cache["last_fetch"]:
            elapsed = (datetime.now() - _models_cache["last_fetch"]).seconds
            if elapsed < 3600:
                return _models_cache["video_models"]

        try:
            async with aiohttp.ClientSession() as session:
                # Try to get video models info
                async with session.get(
                    f"{self.BASE_URL}/ai/image-to-video/models",
                    headers=self.headers,
                    timeout=aiohttp.ClientTimeout(total=15)
                ) as response:
                    if response.status == 200:
                        data = await response.json()
                        models = data.get("data", {}).get("models", [])
                        if models:
                            formatted_models = []
                            for model in models:
                                formatted_models.append({
                                    "id": model.get("id", model.get("name", "")),
                                    "name": model.get("name", model.get("id", "")),
                                    "description": model.get("description", "")
                                })
                            _models_cache["video_models"] = formatted_models
                            _models_cache["last_fetch"] = datetime.now()
                            return formatted_models
        except Exception:
            pass

        # Fallback to hardcoded models
        return self.FALLBACK_VIDEO_MODELS

    async def generate_image(
        self,
        prompt: str,
        model: str = "mystic",
        resolution: str = "2k",
        aspect_ratio: str = "square_1_1"
    ) -> Dict[str, Any]:
        """Generate image using Freepik Mystic API"""
        endpoint = f"{self.BASE_URL}/ai/mystic"

        payload = {
            "prompt": prompt,
            "resolution": resolution,
            "aspect_ratio": aspect_ratio,
            "creative_detailing": 50,
            "engine": "automatic"
        }

        # Add model if not default mystic
        if model and model != "mystic":
            payload["model"] = model

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    endpoint,
                    headers=self.headers,
                    json=payload,
                    timeout=aiohttp.ClientTimeout(total=60)
                ) as response:
                    data = await response.json()

                    if response.status == 200 or response.status == 201:
                        return {
                            "success": True,
                            "task_id": data.get("data", {}).get("task_id"),
                            "status": data.get("data", {}).get("status", "IN_PROGRESS"),
                            "data": data
                        }
                    else:
                        return {
                            "success": False,
                            "error": data.get("error", {}).get("message", "Unknown error"),
                            "status_code": response.status
                        }
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def check_image_status(self, task_id: str) -> Dict[str, Any]:
        """Check status of image generation task"""
        endpoint = f"{self.BASE_URL}/ai/mystic/{task_id}"

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    endpoint,
                    headers=self.headers,
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    data = await response.json()

                    if response.status == 200:
                        task_data = data.get("data", {})
                        status = task_data.get("status", "UNKNOWN")

                        result = {
                            "success": True,
                            "status": status,
                            "task_id": task_id
                        }

                        if status == "COMPLETED":
                            generated = task_data.get("generated", [])
                            if generated:
                                result["images"] = generated
                                result["image_url"] = generated[0].get("url") if generated else None

                        return result
                    else:
                        return {
                            "success": False,
                            "error": data.get("error", {}).get("message", "Unknown error")
                        }
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def wait_for_image(
        self,
        task_id: str,
        max_attempts: int = 60,
        interval: int = 2
    ) -> Dict[str, Any]:
        """Poll for image completion"""
        for attempt in range(max_attempts):
            result = await self.check_image_status(task_id)

            if not result["success"]:
                return result

            if result["status"] == "COMPLETED":
                return result
            elif result["status"] == "FAILED":
                return {"success": False, "error": "Image generation failed"}

            await asyncio.sleep(interval)

        return {"success": False, "error": "Timeout waiting for image generation"}

    async def generate_video(
        self,
        image_base64: str,
        model: str = "kling-std",
        prompt: str = "",
        duration: str = "5"
    ) -> Dict[str, Any]:
        """Generate video from image using Freepik API"""
        model_endpoints = {
            "kling-std": "kling-std",
            "kling-pro": "kling-pro",
            "kling-v2": "kling-v2",
            "minimax-768p": "minimax-768p",
            "minimax-1080p": "minimax-1080p"
        }

        endpoint_suffix = model_endpoints.get(model, "kling-std")
        endpoint = f"{self.BASE_URL}/ai/image-to-video/{endpoint_suffix}"

        payload = {
            "image": image_base64,
            "duration": duration,
            "cfg_scale": 0.5
        }

        if prompt:
            payload["prompt"] = prompt

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    endpoint,
                    headers=self.headers,
                    json=payload,
                    timeout=aiohttp.ClientTimeout(total=120)
                ) as response:
                    data = await response.json()

                    if response.status == 200 or response.status == 201:
                        return {
                            "success": True,
                            "task_id": data.get("data", {}).get("task_id"),
                            "status": data.get("data", {}).get("status", "IN_PROGRESS"),
                            "data": data
                        }
                    else:
                        return {
                            "success": False,
                            "error": data.get("error", {}).get("message", "Unknown error"),
                            "status_code": response.status
                        }
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def check_video_status(self, task_id: str, model: str = "kling-std") -> Dict[str, Any]:
        """Check status of video generation task"""
        model_endpoints = {
            "kling-std": "kling-std",
            "kling-pro": "kling-pro",
            "kling-v2": "kling-v2",
            "minimax-768p": "minimax-768p",
            "minimax-1080p": "minimax-1080p"
        }

        endpoint_suffix = model_endpoints.get(model, "kling-std")
        endpoint = f"{self.BASE_URL}/ai/image-to-video/{endpoint_suffix}/{task_id}"

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    endpoint,
                    headers=self.headers,
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    data = await response.json()

                    if response.status == 200:
                        task_data = data.get("data", {})
                        status = task_data.get("status", "UNKNOWN")

                        result = {
                            "success": True,
                            "status": status,
                            "task_id": task_id
                        }

                        if status == "COMPLETED":
                            video_url = task_data.get("video", {}).get("url")
                            if video_url:
                                result["video_url"] = video_url

                        return result
                    else:
                        return {
                            "success": False,
                            "error": data.get("error", {}).get("message", "Unknown error")
                        }
        except Exception as e:
            return {"success": False, "error": str(e)}

    async def wait_for_video(
        self,
        task_id: str,
        model: str = "kling-std",
        max_attempts: int = 120,
        interval: int = 3
    ) -> Dict[str, Any]:
        """Poll for video completion"""
        for attempt in range(max_attempts):
            result = await self.check_video_status(task_id, model)

            if not result["success"]:
                return result

            if result["status"] == "COMPLETED":
                return result
            elif result["status"] == "FAILED":
                return {"success": False, "error": "Video generation failed"}

            await asyncio.sleep(interval)

        return {"success": False, "error": "Timeout waiting for video generation"}

    @classmethod
    def get_image_models(cls) -> List[Dict[str, str]]:
        """Return fallback image models (sync)"""
        return cls.FALLBACK_IMAGE_MODELS

    @classmethod
    def get_video_models(cls) -> List[Dict[str, str]]:
        """Return fallback video models (sync)"""
        return cls.FALLBACK_VIDEO_MODELS


async def download_image(url: str) -> Optional[bytes]:
    """Download image from URL"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=60)) as response:
                if response.status == 200:
                    return await response.read()
                return None
    except Exception:
        return None


async def download_video(url: str) -> Optional[bytes]:
    """Download video from URL"""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=300)) as response:
                if response.status == 200:
                    return await response.read()
                return None
    except Exception:
        return None


def image_to_base64(image_bytes: bytes) -> str:
    """Convert image bytes to base64 string"""
    return base64.b64encode(image_bytes).decode('utf-8')
