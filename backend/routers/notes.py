from fastapi import APIRouter, Depends, Header, HTTPException, Request

from auth.auth_middleware import require_firebase_user
from core.rate_limiter import LIMIT_GENERATION, limiter
from core.usage_limiter import check_and_increment_daily_usage
from database.notes_model import save_notes_entry
from models.notes_models import NotesEnvelopeResponse, NotesFollowUpRequest, NotesGenerateRequest
from services.llm import follow_up_notes, generate_notes
from utils.file_utils import resolve_scan_path, scan_path_to_relative

router = APIRouter(
    prefix="/notes",
    tags=["Notes"],
    dependencies=[Depends(require_firebase_user)],
)


@router.post("/generate", response_model=NotesEnvelopeResponse)
@limiter.limit(LIMIT_GENERATION)
async def generate_notes_route(
    request: Request,
    req: NotesGenerateRequest,
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
):
    user_id = request.state.user["uid"]
    await check_and_increment_daily_usage(user_id=user_id)

    local_path = None
    relative_path = None
    if req.image_path:
        try:
            local_path = resolve_scan_path(req.image_path)
            relative_path = scan_path_to_relative(local_path)
        except ValueError:
            pass

    try:
        notes = await generate_notes(
            topic=req.topic,
            variables=req.variables,
            ocr_text=req.ocr_text,
        )

        # Non-blocking DB save (fail-safe)
        try:
            await save_notes_entry(
                user_id=user_id,
                topic=req.topic,
                notes_payload=notes.model_dump(),
                image_path=relative_path or req.image_path,
            )
        except Exception:
            pass

        # Return format matching Flutter client expectations
        return NotesEnvelopeResponse(notes=notes)

    except Exception:
        raise HTTPException(status_code=500, detail="Failed to generate notes.")


@router.post("/ask", response_model=NotesEnvelopeResponse)
@limiter.limit(LIMIT_GENERATION)
async def follow_up_notes_route(
    request: Request,
    req: NotesFollowUpRequest,
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
):
    await check_and_increment_daily_usage(user_id=request.state.user["uid"])
    try:
        image_reference = None
        if isinstance(req.previous_notes, dict):
            raw_path = req.previous_notes.get("image_path")
            if isinstance(raw_path, str):
                try:
                    image_reference = scan_path_to_relative(resolve_scan_path(raw_path))
                except ValueError:
                    image_reference = None

        notes = await follow_up_notes(
            topic=req.topic,
            previous_notes=req.previous_notes,
            user_prompt=req.user_prompt,
        )

        try:
            await save_notes_entry(
                user_id=request.state.user["uid"],
                topic=req.topic,
                notes_payload=notes.model_dump(),
                image_path=image_reference,
            )
        except Exception:
            pass

        return NotesEnvelopeResponse(notes=notes)

    except Exception:
        raise HTTPException(status_code=500, detail="Failed to process follow-up question.")
