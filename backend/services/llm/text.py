"""
Groq Text Generation Services for Notes, Quizzes, Parameter Control, and Tutor Chat.
Features:
- Structured outputs with Pydantic validation.
- Automatic single repair retry on malformed JSON.
- Exponential backoff on 429/5xx honoring Retry-After.
- Structured performance logging without logging prompts.
- Graceful local fallbacks tagged with degraded=true.
"""

import logging
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from config import settings
from prompts.notes_prompts import NOTES_FOLLOWUP_PROMPT_V1, NOTES_GENERATION_PROMPT_V1
from prompts.quiz_prompts import QUIZ_GENERATION_PROMPT_V1
from prompts.tutor_prompts import TUTOR_CHAT_PROMPT_V1
from prompts.visualiser_prompts import PARAM_UPDATE_PROMPT_V1, VISUALISER_CHAT_PROMPT_V1

from .cache import (
    get_cached_notes,
    get_cached_quiz,
    set_cached_notes,
    set_cached_quiz,
)
from .client import get_text_client
from .engine import call_groq_structured
from .fallback import get_fallback_quiz

logger = logging.getLogger("stemly.llm.text")


# ==============================================================================
# Pydantic Schemas
# ==============================================================================


class NotesResponse(BaseModel):
    explanation: str
    variable_breakdown: Dict[str, str] = Field(default_factory=dict)
    formulas: List[str] = Field(default_factory=list)
    example: str = ""
    mistakes: List[str] = Field(default_factory=list)
    practice_questions: List[str] = Field(default_factory=list)
    summary: List[str] = Field(default_factory=list)
    resources: List[str] = Field(default_factory=list)
    degraded: bool = Field(default=False)


class QuizQuestion(BaseModel):
    question: str
    options: List[str]
    correct_index: int = Field(default=0, ge=0, le=3)
    explanation: str = ""
    takeaway: str = ""


class QuizResponse(BaseModel):
    topic: str
    difficulty: str = "mixed"
    questions: List[QuizQuestion]
    degraded: bool = Field(default=False)


class ParameterUpdateResponse(BaseModel):
    updated_parameters: Dict[str, Any] = Field(default_factory=dict)
    ai_response: str
    degraded: bool = Field(default=False)


class TutorChatResponse(BaseModel):
    response: str
    parameter_updates: Optional[Dict[str, Any]] = None
    update_type: str = "explanation"
    degraded: bool = Field(default=False)


class VisualiserChatResponse(BaseModel):
    type: str = "chat"
    changes: Dict[str, Any] = Field(default_factory=dict)
    message: str = ""
    degraded: bool = Field(default=False)

    @property
    def parameter_updates(self) -> Dict[str, Any]:
        return self.changes

    @property
    def response(self) -> str:
        return self.message

    @property
    def update_type(self) -> str:
        return "parameters" if self.type == "update" else "none"


# ==============================================================================
# 1. Notes Generation & Follow-ups
# ==============================================================================


async def generate_notes(
    topic: str,
    variables: List[str],
    ocr_text: Optional[str] = None,
) -> NotesResponse:
    """
    Generates structured study notes using Groq Text model.
    Checks semantic cache first for repeated topics.
    Falls back to a structured local template if API call fails.
    """
    # 1. Semantic Cache check (skip LLM on duplicate requests)
    if not ocr_text:
        cached_data = await get_cached_notes(topic, variables)
        if cached_data:
            return NotesResponse.model_validate(cached_data)

    client = get_text_client()

    if not settings.GROQ_TEXT_API_KEY:
        logger.warning("GROQ_TEXT_API_KEY missing. Returning degraded notes.")
        return _fallback_notes(topic, variables)

    context = f"Topic: {topic}\nVariables: {', '.join(variables)}"
    if ocr_text:
        context += f"\n<untrusted_ocr_text>\n{ocr_text[:600]}\n</untrusted_ocr_text>"

    messages = [
        {"role": "system", "content": NOTES_GENERATION_PROMPT_V1},
        {"role": "user", "content": f"Generate study notes for:\n{context}"},
    ]

    try:
        result = await call_groq_structured(
            client=client,
            model=settings.GROQ_TEXT_MODEL,
            messages=messages,
            schema=NotesResponse,
            temperature=0.3,
            max_tokens=4000,
        )
        if result:
            result.degraded = False
            if not ocr_text:
                await set_cached_notes(topic, variables, result.model_dump())
            return result
    except Exception as exc:
        logger.error("Groq notes generation error: %s", exc)

    return _fallback_notes(topic, variables)


async def follow_up_notes(
    topic: str,
    previous_notes: dict,
    user_prompt: str,
) -> NotesResponse:
    """
    Answers follow-up questions on study notes with schema consistency.
    """
    client = get_text_client()

    if not settings.GROQ_TEXT_API_KEY:
        return NotesResponse(
            explanation="AI assistant is operating in offline mode. Please review the summary above.",
            summary=["Follow-up service currently degraded"],
            degraded=True,
        )

    summary_bullets = previous_notes.get("summary", [])
    if isinstance(summary_bullets, list):
        prev_summary = "; ".join(summary_bullets[:3])
    else:
        prev_summary = str(summary_bullets)

    prompt = NOTES_FOLLOWUP_PROMPT_V1.format(
        topic=topic,
        previous_summary=prev_summary,
        user_prompt=user_prompt,
    )

    messages = [
        {"role": "user", "content": prompt},
    ]

    try:
        result = await call_groq_structured(
            client=client,
            model=settings.GROQ_TEXT_MODEL,
            messages=messages,
            schema=NotesResponse,
            temperature=0.3,
            max_tokens=2000,
        )
        if result:
            result.degraded = False
            return result
    except Exception as exc:
        logger.error("Groq follow-up notes error: %s", exc)

    return NotesResponse(
        explanation=f"Here is additional context regarding {topic}: The fundamental governing principles apply directly to '{user_prompt}'.",
        summary=[f"Follow-up insight on {topic}"],
        degraded=True,
    )


def _fallback_notes(topic: str, variables: List[str]) -> NotesResponse:
    var_dict = {v: f"Symbol for {v}" for v in variables} if variables else {"x": "variable parameter"}
    return NotesResponse(
        explanation=f"Core conceptual study guide for {topic}. Review standard principles and definitions.",
        variable_breakdown=var_dict,
        formulas=[f"Standard governing equations for {topic}"],
        example=f"Consider a typical scenario in {topic} with given initial conditions.",
        mistakes=["Ignoring sign conventions", "Confusing scalar and vector quantities"],
        practice_questions=[f"How do the core variables in {topic} relate under boundary conditions?"],
        summary=[f"Fundamental principle of {topic}", "Ensure correct SI units"],
        resources=[f"{topic} OpenStax Physics Guide"],
        degraded=True,
    )


# ==============================================================================
# 2. Quiz Generation
# ==============================================================================


async def generate_quiz(topic: str, num_questions: int = 5) -> QuizResponse:
    """
    Generates MCQ questions with explanations using Groq.
    Checks semantic cache first for repeated topics.
    Falls back to curated sample quizzes if unavailable.
    """
    num_q = max(1, min(num_questions, 20))

    # 1. Semantic Cache check
    cached_data = await get_cached_quiz(topic, num_q)
    if cached_data:
        return QuizResponse.model_validate(cached_data)

    client = get_text_client()

    if not settings.GROQ_TEXT_API_KEY:
        logger.warning("GROQ_TEXT_API_KEY missing. Using fallback quiz.")
        fallback = get_fallback_quiz(topic, count=num_q)
        return QuizResponse.model_validate(fallback)

    prompt = QUIZ_GENERATION_PROMPT_V1.format(topic=topic, num_questions=num_q)
    messages = [
        {"role": "user", "content": prompt},
    ]

    try:
        result = await call_groq_structured(
            client=client,
            model=settings.GROQ_TEXT_MODEL,
            messages=messages,
            schema=QuizResponse,
            temperature=0.4,
            max_tokens=3500,
        )
        if result and len(result.questions) > 0:
            result.degraded = False
            await set_cached_quiz(topic, num_q, result.model_dump())
            return result
    except Exception as exc:
        logger.error("Groq quiz generation error: %s", exc)

    fallback = get_fallback_quiz(topic, count=num_q)
    return QuizResponse.model_validate(fallback)


# ==============================================================================
# 3. Parameter Update Parser
# ==============================================================================


async def parse_param_update(
    template_id: str,
    current_params: Dict[str, Any],
    user_prompt: str,
) -> ParameterUpdateResponse:
    """
    Parses natural language simulation commands into parameter adjustments.
    """
    client = get_text_client()

    if not settings.GROQ_TEXT_API_KEY:
        return ParameterUpdateResponse(
            updated_parameters={},
            ai_response="Simulation assistant operating offline.",
            degraded=True,
        )

    prompt = PARAM_UPDATE_PROMPT_V1.format(
        template_id=template_id,
        current_params=current_params,
        user_prompt=user_prompt,
    )
    messages = [{"role": "user", "content": prompt}]

    try:
        result = await call_groq_structured(
            client=client,
            model=settings.GROQ_TEXT_MODEL,
            messages=messages,
            schema=ParameterUpdateResponse,
            temperature=0.1,
            max_tokens=800,
        )
        if result:
            result.degraded = False
            return result
    except Exception as exc:
        logger.error("Groq parameter update error: %s", exc)

    return ParameterUpdateResponse(
        updated_parameters={},
        ai_response="Could not adjust parameters at this time.",
        degraded=True,
    )


# ==============================================================================
# 4. Tutor Chat
# ==============================================================================


async def tutor_chat(
    message: str,
    topic: Optional[str] = None,
    variables: Optional[List[str]] = None,
    current_params: Optional[Dict[str, Any]] = None,
    template_id: Optional[str] = None,
    history: Optional[List[Dict[str, Any]]] = None,
) -> TutorChatResponse:
    """
    Unified AI STEM tutor chat supporting concept explanations and simulation controls.
    """
    client = get_text_client()

    if not settings.GROQ_TEXT_API_KEY:
        return TutorChatResponse(
            response="Tutor chat is currently operating in offline mode. Please try again shortly.",
            parameter_updates=None,
            update_type="explanation",
            degraded=True,
        )

    topic_str = topic or "General STEM"
    vars_str = ", ".join(variables) if variables else "None specified"
    template_str = template_id or "Standard Canvas"
    params_str = str(current_params) if current_params else "{}"

    prompt = TUTOR_CHAT_PROMPT_V1.format(
        topic=topic_str,
        variables=vars_str,
        template_id=template_str,
        current_params=params_str,
        user_prompt=message,
    )

    messages: List[Dict[str, Any]] = []

    # Include recent chat history (up to 4 turns) if provided
    if history:
        for turn in history[-4:]:
            role = "user" if turn.get("isUser") else "assistant"
            content = turn.get("text", "")
            if content:
                messages.append({"role": role, "content": content})

    messages.append({"role": "user", "content": prompt})

    try:
        result = await call_groq_structured(
            client=client,
            model=settings.GROQ_TEXT_MODEL,
            messages=messages,
            schema=TutorChatResponse,
            temperature=0.3,
            max_tokens=1500,
        )
        if result:
            result.degraded = False
            return result
    except Exception as exc:
        logger.error("Groq tutor chat error: %s", exc)

    return TutorChatResponse(
        response=f"Regarding {topic_str}: Keep in mind the underlying relations between the key variables ({vars_str}).",
        parameter_updates=None,
        update_type="explanation",
        degraded=True,
    )


async def process_visualiser_chat_llm(
    user_message: str,
    topic: str,
    parameters: dict,
    chat_history: Optional[List[Dict[str, Any]]] = None,
) -> VisualiserChatResponse:
    """
    Processes chat requests directly from the visualizer UI (Mode 1: update, Mode 2: chat).
    """
    client = get_text_client()

    if not settings.GROQ_TEXT_API_KEY:
        return VisualiserChatResponse(
            type="chat",
            changes={},
            message="Visualizer AI currently offline.",
            degraded=True,
        )

    prompt = VISUALISER_CHAT_PROMPT_V1.format(
        topic=topic,
        parameters=parameters,
        user_message=user_message,
    )
    messages = [{"role": "user", "content": prompt}]

    try:
        result = await call_groq_structured(
            client=client,
            model=settings.GROQ_TEXT_MODEL,
            messages=messages,
            schema=VisualiserChatResponse,
            temperature=0.2,
            max_tokens=1000,
        )
        if result:
            result.degraded = False
            return result
    except Exception as exc:
        logger.error("Groq visualizer chat error: %s", exc)

    return VisualiserChatResponse(
        type="chat",
        changes={},
        message="I could not process the visualizer request.",
        degraded=True,
    )
