"""
Groq Text Generation Services for Notes, Quizzes, Parameter Control, and Tutor Chat.
Features:
- Structured outputs with Pydantic validation.
- Automatic single repair retry on malformed JSON.
- Exponential backoff on 429/5xx honoring Retry-After.
- Structured performance logging without logging prompts.
- Graceful local fallbacks tagged with degraded=true.
"""

import asyncio
import json
import logging
import re
import time
import uuid
from typing import Any, AsyncGenerator, Awaitable, Callable, Dict, List, Optional

import httpx
from pydantic import BaseModel, Field

from config import settings
from core.parameter_sanitizer import sanitize_simulation_parameters
from models.chat_protocol import StreamEventEnvelope
from models.tools import TUTOR_TOOLS, SuggestFollowupsArgs, UpdateSimulationArgs
from prompts.notes_prompts import NOTES_FOLLOWUP_PROMPT_V1, NOTES_GENERATION_PROMPT_V1
from prompts.quiz_prompts import QUIZ_GENERATION_PROMPT_V1
from prompts.tutor_prompts import TUTOR_CHAT_PROMPT_V1, TUTOR_STREAM_SYSTEM_PROMPT
from prompts.visualiser_prompts import PARAM_UPDATE_PROMPT_V1, VISUALISER_CHAT_PROMPT_V1

from .cache import (
    get_cached_notes,
    get_cached_quiz,
    set_cached_notes,
    set_cached_quiz,
)
from .client import get_text_client
from .context_manager import build_conversation_context
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
    suggested_followups: List[str] = Field(
        default_factory=list, description="3 dynamic follow-up questions"
    )
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

    topic_str = topic or "General STEM"
    vars_str = ", ".join(variables) if variables else "None specified"
    template_str = template_id or "Standard Canvas"
    params_str = str(current_params) if current_params else "{}"

    default_followups = [
        f"Explain the governing formula for {topic_str}",
        f"How do variables relate to each other?",
        "Show me a step-by-step example problem",
    ]

    if not settings.GROQ_TEXT_API_KEY:
        return TutorChatResponse(
            response="Tutor chat is currently operating in offline mode. Please try again shortly.",
            parameter_updates=None,
            update_type="explanation",
            suggested_followups=default_followups,
            degraded=True,
        )

    prompt = TUTOR_CHAT_PROMPT_V1.format(
        topic=topic_str,
        variables=vars_str,
        template_id=template_str,
        current_params=params_str,
        user_prompt=message,
    )

    messages: List[Dict[str, Any]] = []

    # Include recent chat history (up to 8 turns) if provided
    if history:
        for turn in history[-8:]:
            role = turn.get("role") or ("user" if turn.get("isUser") else "assistant")
            content = turn.get("content") or turn.get("text", "")
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
            if not result.suggested_followups:
                result.suggested_followups = default_followups
            return result
    except Exception as exc:
        logger.error("Groq tutor chat error: %s", exc)

    return TutorChatResponse(
        response=f"Regarding {topic_str}: Keep in mind the underlying relations between the key variables ({vars_str}).",
        parameter_updates=None,
        update_type="explanation",
        suggested_followups=default_followups,
        degraded=True,
    )


async def stream_tutor_chat(
    message: str,
    topic: Optional[str] = None,
    variables: Optional[List[str]] = None,
    current_params: Optional[Dict[str, Any]] = None,
    template_id: Optional[str] = None,
    history: Optional[List[Dict[str, Any]]] = None,
    session_id: Optional[str] = None,
    is_disconnected_fn: Optional[Callable[[], Awaitable[bool]]] = None,
) -> AsyncGenerator[StreamEventEnvelope, None]:
    """
    Streams ChatGPT-grade AI STEM tutor responses token-by-token via Server-Sent Events (SSE).
    Adheres to Streaming Protocol v2 envelope specification:
      {v: 1, id: str, seq: int, type: str, data: dict}
    Event types:
      - meta: request_id, session_id, model, created_at
      - token: delta token string
      - parameters: sanitized simulation parameter updates
      - followups: 3 one-tap suggestion chips
      - usage: prompt_tokens, completion_tokens, total_tokens, latency_ms, ttft_ms
      - done: finish_reason
      - error: stable code, message, retryable
    """
    request_id = str(uuid.uuid4())
    active_session_id = session_id or request_id
    topic_str = topic or "General STEM"
    vars_str = ", ".join(variables) if variables else "None specified"
    template_str = template_id or "Standard Canvas"
    params_str = json.dumps(current_params) if current_params else "{}"

    default_followups = [
        f"Explain the governing formula for {topic_str}",
        "How do variables relate to each other?",
        "Show me a step-by-step example problem",
    ]

    seq = 0
    start_time = time.perf_counter()
    ttft_ms: Optional[float] = None
    prompt_tokens_est = len(message.split()) + 40
    completion_tokens = 0

    # 1. First event is ALWAYS meta, sent immediately
    yield StreamEventEnvelope(
        v=1,
        id=request_id,
        seq=seq,
        type="meta",
        data={
            "request_id": request_id,
            "session_id": active_session_id,
            "model": settings.GROQ_TEXT_MODEL,
            "created_at": int(time.time()),
        },
    )
    seq += 1

    # Check client disconnect immediately
    if is_disconnected_fn and await is_disconnected_fn():
        logger.info("Client disconnected immediately after meta frame. Aborting stream.")
        return

    # 2. Check offline mode / missing API key
    if not settings.GROQ_TEXT_API_KEY:
        offline_text = (
            f"I am currently operating in offline mode. For **{topic_str}**, review the core equations connecting: {vars_str}."
        )
        yield StreamEventEnvelope(
            v=1,
            id=request_id,
            seq=seq,
            type="token",
            data={"delta": offline_text},
        )
        seq += 1
        yield StreamEventEnvelope(
            v=1,
            id=request_id,
            seq=seq,
            type="followups",
            data={"suggestions": default_followups},
        )
        seq += 1
        dur_ms = (time.perf_counter() - start_time) * 1000.0
        yield StreamEventEnvelope(
            v=1,
            id=request_id,
            seq=seq,
            type="usage",
            data={
                "prompt_tokens": 0,
                "completion_tokens": len(offline_text.split()),
                "total_tokens": len(offline_text.split()),
                "latency_ms": round(dur_ms, 2),
                "ttft_ms": round(dur_ms, 2),
            },
        )
        seq += 1
        yield StreamEventEnvelope(
            v=1,
            id=request_id,
            seq=seq,
            type="done",
            data={"finish_reason": "stop"},
        )
        return

    # 3. Construct prompt and message context via token-budgeted context manager
    system_prompt = TUTOR_STREAM_SYSTEM_PROMPT.format(current_params=params_str)
    user_query = (
        f"Topic: {topic_str}\n"
        f"Variables: {vars_str}\n"
        f"Active Template: {template_str}\n\n"
        f"Student Question: {message}"
    )
    messages, _ = build_conversation_context(
        system_prompt=system_prompt,
        history=history,
        user_query=user_query,
    )

    payload = {
        "model": settings.GROQ_TEXT_MODEL,
        "messages": messages,
        "temperature": 0.3,
        "max_tokens": 1500,
        "stream": True,
        "stream_options": {"include_usage": True},
        "tools": TUTOR_TOOLS,
        "tool_choice": "auto",
    }

    client = get_text_client()
    tail_buffer = ""
    emitted_followups = False
    accumulated_tool_calls: Dict[int, Dict[str, str]] = {}

    try:
        async with client.stream("POST", "/chat/completions", json=payload) as resp:
            if resp.status_code != 200:
                logger.warning("Groq stream returned status %d. Falling back.", resp.status_code)
                yield StreamEventEnvelope(
                    v=1,
                    id=request_id,
                    seq=seq,
                    type="error",
                    data={
                        "code": f"upstream_{resp.status_code}",
                        "message": "AI tutoring service temporarily degraded. Please try again.",
                        "retryable": True,
                    },
                )
                seq += 1
                yield StreamEventEnvelope(
                    v=1,
                    id=request_id,
                    seq=seq,
                    type="done",
                    data={"finish_reason": "error"},
                )
                return

            aiter = resp.aiter_lines().__aiter__()
            while True:
                # Disconnect check
                if is_disconnected_fn and await is_disconnected_fn():
                    logger.info("Client disconnected during stream. Cancelling upstream Groq call.")
                    return

                try:
                    # 15s idle check
                    line = await asyncio.wait_for(aiter.__anext__(), timeout=15.0)
                except asyncio.TimeoutError:
                    if is_disconnected_fn and await is_disconnected_fn():
                        logger.info("Client disconnected during idle wait. Cancelling stream.")
                        return
                    continue
                except StopAsyncIteration:
                    break

                if not line or not line.startswith("data: "):
                    continue

                raw_data = line[6:].strip()
                if raw_data == "[DONE]":
                    break

                try:
                    chunk = json.loads(raw_data)
                except json.JSONDecodeError:
                    continue

                # Parse usage if Groq provided it in stream
                if "usage" in chunk and chunk["usage"]:
                    u = chunk["usage"]
                    prompt_tokens_est = u.get("prompt_tokens", prompt_tokens_est)
                    completion_tokens = u.get("completion_tokens", completion_tokens)

                choices = chunk.get("choices", [])
                if not choices:
                    continue

                delta = choices[0].get("delta", {})

                # Accumulate tool calls deltas across chunks
                tool_calls_delta = delta.get("tool_calls")
                if tool_calls_delta:
                    for tc in tool_calls_delta:
                        idx = tc.get("index", 0)
                        if idx not in accumulated_tool_calls:
                            accumulated_tool_calls[idx] = {
                                "id": tc.get("id", ""),
                                "name": tc.get("function", {}).get("name", "") if tc.get("function") else "",
                                "arguments": tc.get("function", {}).get("arguments", "") if tc.get("function") else "",
                            }
                        else:
                            fn = tc.get("function")
                            if fn:
                                if fn.get("name"):
                                    accumulated_tool_calls[idx]["name"] += fn["name"]
                                if fn.get("arguments"):
                                    accumulated_tool_calls[idx]["arguments"] += fn["arguments"]

                token = delta.get("content", "")
                if not token:
                    continue

                if ttft_ms is None:
                    ttft_ms = (time.perf_counter() - start_time) * 1000.0

                completion_tokens += 1
                tail_buffer += token

                # Parse control tags if any
                if "<<<" in tail_buffer:
                    if ">>>" in tail_buffer:
                        param_match = re.search(r"<<<PARAMS:\s*(\{.*?\})\s*>>>", tail_buffer, re.DOTALL)
                        if param_match:
                            try:
                                params = json.loads(param_match.group(1))
                                if isinstance(params, dict):
                                    clamped = sanitize_simulation_parameters(params)
                                    if clamped:
                                        yield StreamEventEnvelope(
                                            v=1,
                                            id=request_id,
                                            seq=seq,
                                            type="parameters",
                                            data={"updates": clamped},
                                        )
                                        seq += 1
                            except Exception:
                                pass

                        followup_match = re.search(r"<<<FOLLOWUPS:\s*(\[.*?\])\s*>>>", tail_buffer, re.DOTALL)
                        if followup_match:
                            try:
                                f_list = json.loads(followup_match.group(1))
                                if isinstance(f_list, list) and f_list:
                                    yield StreamEventEnvelope(
                                        v=1,
                                        id=request_id,
                                        seq=seq,
                                        type="followups",
                                        data={"suggestions": [str(x) for x in f_list[:3]]},
                                    )
                                    seq += 1
                                    emitted_followups = True
                            except Exception:
                                pass

                        tail_buffer = re.sub(r"<<<PARAMS:.*?>>>", "", tail_buffer, flags=re.DOTALL)
                        tail_buffer = re.sub(r"<<<FOLLOWUPS:.*?>>>", "", tail_buffer, flags=re.DOTALL)
                else:
                    if len(tail_buffer) > 4:
                        safe_to_emit = tail_buffer[:-4]
                        tail_buffer = tail_buffer[-4:]
                        yield StreamEventEnvelope(
                            v=1,
                            id=request_id,
                            seq=seq,
                            type="token",
                            data={"delta": safe_to_emit},
                        )
                        seq += 1

            clean_tail = re.sub(r"<<<.*?>>>", "", tail_buffer, flags=re.DOTALL)
            clean_tail = clean_tail.replace("<<<", "").strip()
            if clean_tail:
                yield StreamEventEnvelope(
                    v=1,
                    id=request_id,
                    seq=seq,
                    type="token",
                    data={"delta": clean_tail},
                )
                seq += 1

            # Dispatch accumulated native tool calls
            for tc in accumulated_tool_calls.values():
                fn_name = tc.get("name", "").strip()
                raw_args = tc.get("arguments", "").strip()
                if not fn_name:
                    continue

                if fn_name == "update_simulation":
                    try:
                        parsed_sim = json.loads(raw_args) if raw_args else {}
                        sim_args = UpdateSimulationArgs.model_validate(parsed_sim)
                        clamped = sanitize_simulation_parameters(sim_args.parameters)
                        if clamped:
                            yield StreamEventEnvelope(
                                v=1,
                                id=request_id,
                                seq=seq,
                                type="parameters",
                                data={
                                    "updates": clamped,
                                    "explanation": sim_args.explanation or "",
                                    "visual_cue": sim_args.visual_cue or "",
                                },
                            )
                            seq += 1
                    except Exception as err:
                        logger.warning("Failed to validate update_simulation tool args: %s", err)
                        # Graceful regex fallback on malformed JSON
                        param_fallback = re.search(r"\{.*\}", raw_args)
                        if param_fallback:
                            try:
                                p = json.loads(param_fallback.group(0))
                                if isinstance(p, dict):
                                    clamped = sanitize_simulation_parameters(p.get("parameters", p))
                                    if clamped:
                                        yield StreamEventEnvelope(
                                            v=1,
                                            id=request_id,
                                            seq=seq,
                                            type="parameters",
                                            data={"updates": clamped},
                                        )
                                        seq += 1
                            except Exception:
                                pass

                elif fn_name == "suggest_followups":
                    try:
                        parsed_fu = json.loads(raw_args) if raw_args else {}
                        followup_args = SuggestFollowupsArgs.model_validate(parsed_fu)
                        if followup_args.questions:
                            yield StreamEventEnvelope(
                                v=1,
                                id=request_id,
                                seq=seq,
                                type="followups",
                                data={"suggestions": followup_args.questions},
                            )
                            seq += 1
                            emitted_followups = True
                    except Exception as err:
                        logger.warning("Failed to validate suggest_followups tool args: %s", err)
                        list_fallback = re.search(r"\[.*\]", raw_args)
                        if list_fallback:
                            try:
                                ql = json.loads(list_fallback.group(0))
                                if isinstance(ql, list) and ql:
                                    yield StreamEventEnvelope(
                                        v=1,
                                        id=request_id,
                                        seq=seq,
                                        type="followups",
                                        data={"suggestions": [str(x) for x in ql[:3]]},
                                    )
                                    seq += 1
                                    emitted_followups = True
                            except Exception:
                                pass

            if not emitted_followups:
                yield StreamEventEnvelope(
                    v=1,
                    id=request_id,
                    seq=seq,
                    type="followups",
                    data={"suggestions": default_followups},
                )
                seq += 1

            # Emit usage event
            total_lat = (time.perf_counter() - start_time) * 1000.0
            yield StreamEventEnvelope(
                v=1,
                id=request_id,
                seq=seq,
                type="usage",
                data={
                    "prompt_tokens": prompt_tokens_est,
                    "completion_tokens": completion_tokens,
                    "total_tokens": prompt_tokens_est + completion_tokens,
                    "latency_ms": round(total_lat, 2),
                    "ttft_ms": round(ttft_ms or total_lat, 2),
                },
            )
            seq += 1

            # Emit done event
            yield StreamEventEnvelope(
                v=1,
                id=request_id,
                seq=seq,
                type="done",
                data={"finish_reason": "stop"},
            )

    except Exception as exc:
        logger.error("Error during tutor chat streaming: %s", exc)
        yield StreamEventEnvelope(
            v=1,
            id=request_id,
            seq=seq,
            type="error",
            data={
                "code": "stream_internal_error",
                "message": "An error occurred while streaming the tutor response.",
                "retryable": True,
            },
        )
        seq += 1
        yield StreamEventEnvelope(
            v=1,
            id=request_id,
            seq=seq,
            type="done",
            data={"finish_reason": "error"},
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
