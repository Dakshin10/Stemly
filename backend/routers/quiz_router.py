from typing import List

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request

from auth.auth_middleware import require_firebase_user
from core.rate_limiter import LIMIT_GENERATION, LIMIT_STANDARD, limiter
from core.usage_limiter import check_and_increment_daily_usage
from models.quiz import QuizQuestion, QuizResult, QuizSubmission
from services.llm import generate_quiz
from services.llm.text import QuizResponse
from services.quiz_service import QuizService

router = APIRouter(
    prefix="/quiz",
    tags=["Quiz"],
    dependencies=[Depends(require_firebase_user)],
)

service = QuizService()


@router.get("/questions/{topic_id}", response_model=List[QuizQuestion])
@limiter.limit(LIMIT_STANDARD)
async def get_static_questions(
    request: Request,
    topic_id: int,
    count: int = Query(10, ge=1, le=50),
):
    return service.get_questions(topic_id, limit=count)


@router.get("/generate", response_model=QuizResponse)
@limiter.limit(LIMIT_GENERATION)
async def ai_generate_quiz(
    request: Request,
    topic: str = Query(..., min_length=1, max_length=150),
    count: int = Query(5, ge=1, le=20),
    x_ai_api_key: str = Header(None, alias="X-AI-API-Key"),
):
    """
    Generates fresh MCQ questions using Groq LLM (with emergency fallback).
    """
    await check_and_increment_daily_usage(user_id=request.state.user["uid"])
    try:
        return await generate_quiz(topic=topic, num_questions=count)
    except Exception:
        raise HTTPException(status_code=500, detail="Failed to generate quiz")


@router.post("/submit", response_model=QuizResult)
@limiter.limit(LIMIT_STANDARD)
def submit_static_quiz(
    request: Request,
    submission: QuizSubmission,
):
    return service.evaluate(submission)
