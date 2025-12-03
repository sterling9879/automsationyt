"""
Settings Routes
Manage API keys and configuration
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional

from database.db import get_setting, set_setting
from services.freepik_api import FreepikService

router = APIRouter()


class ApiKeyRequest(BaseModel):
    api_key: str


class ApiKeyResponse(BaseModel):
    success: bool
    message: str
    masked_key: Optional[str] = None


@router.post("/settings/apikey", response_model=ApiKeyResponse)
async def save_api_key(request: ApiKeyRequest):
    """
    Save Freepik API key

    The key is stored in the database and used for all API requests.
    """
    if not request.api_key or len(request.api_key) < 10:
        raise HTTPException(
            status_code=400,
            detail="Invalid API key format"
        )

    # Validate API key
    freepik = FreepikService(request.api_key)
    validation = await freepik.validate_api_key()

    if not validation["valid"]:
        raise HTTPException(
            status_code=400,
            detail=f"API key validation failed: {validation['message']}"
        )

    # Save to database
    await set_setting("freepik_api_key", request.api_key)

    # Mask key for response
    masked = request.api_key[:4] + "..." + request.api_key[-4:]

    return ApiKeyResponse(
        success=True,
        message="API key saved successfully",
        masked_key=masked
    )


@router.get("/settings/apikey")
async def get_api_key_status():
    """
    Check if API key is configured

    Returns masked key if set, or empty if not configured.
    """
    api_key = await get_setting("freepik_api_key")

    if api_key:
        masked = api_key[:4] + "..." + api_key[-4:]
        return {
            "success": True,
            "configured": True,
            "masked_key": masked
        }
    else:
        return {
            "success": True,
            "configured": False,
            "masked_key": None
        }


@router.get("/settings/apikey/validate")
async def validate_api_key():
    """
    Validate the stored API key

    Tests the API key against Freepik API.
    """
    api_key = await get_setting("freepik_api_key")

    if not api_key:
        return {
            "success": False,
            "valid": False,
            "message": "No API key configured"
        }

    freepik = FreepikService(api_key)
    validation = await freepik.validate_api_key()

    return {
        "success": True,
        "valid": validation["valid"],
        "message": validation["message"]
    }


@router.delete("/settings/apikey")
async def delete_api_key():
    """Remove stored API key"""
    import aiosqlite
    from database.db import DATABASE_PATH

    async with aiosqlite.connect(DATABASE_PATH) as db:
        await db.execute("DELETE FROM settings WHERE key = 'freepik_api_key'")
        await db.commit()

    return {
        "success": True,
        "message": "API key removed"
    }
