from typing import Any, Dict

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from auth.auth_middleware import require_firebase_user
from core.rate_limiter import LIMIT_STANDARD, limiter
from core.usage_limiter import delete_user_usage_records
from database.history_model import delete_user_scans
from database.notes_model import delete_user_notes
from database.user_model import delete_user_profile
from database.visualiser_model import delete_user_visualiser_entries

router = APIRouter(prefix="/auth", tags=["Auth"])


class UserMeResponse(BaseModel):
    user: Dict[str, Any] = Field(description="Authenticated Firebase user claims")


class DeleteMyDataResponse(BaseModel):
    status: str = Field(default="success")
    message: str = Field(default="All user data has been permanently deleted.")
    deleted_counts: Dict[str, int] = Field(default_factory=dict)


@router.get("/me", response_model=UserMeResponse)
@limiter.limit(LIMIT_STANDARD)
async def read_current_user(request: Request, user=Depends(require_firebase_user)):
    return UserMeResponse(user=user)


@router.delete("/me/data", response_model=DeleteMyDataResponse)
@limiter.limit(LIMIT_STANDARD)
async def delete_my_data(request: Request, user=Depends(require_firebase_user)):
    """
    Permanently deletes all personal data belonging to the authenticated user.
    Complies with GDPR and CCPA 'Right to Erasure'.
    """
    user_id = user["uid"]

    deleted_scans = await delete_user_scans(user_id)
    deleted_notes = await delete_user_notes(user_id)
    deleted_visualiser = await delete_user_visualiser_entries(user_id)
    deleted_profile = await delete_user_profile(user_id)
    deleted_usage = await delete_user_usage_records(user_id)

    return DeleteMyDataResponse(
        status="success",
        message="All user data has been permanently deleted.",
        deleted_counts={
            "scans": deleted_scans,
            "notes": deleted_notes,
            "visualiser_entries": deleted_visualiser,
            "profile": deleted_profile,
            "usage_records": deleted_usage,
        },
    )
