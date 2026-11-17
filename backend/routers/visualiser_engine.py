from typing import Any, Dict
from urllib.parse import urlparse

from bson import ObjectId
from fastapi import APIRouter, Depends, Header, HTTPException, Query, Request

from auth.auth_middleware import require_firebase_user
from core.parameter_sanitizer import sanitize_simulation_parameters
from core.rate_limiter import LIMIT_CHAT, LIMIT_STANDARD, limiter
from core.usage_limiter import check_and_increment_daily_usage
from database.visualiser_model import (
    get_visualiser_entries_paginated,
    save_visualiser_entry,
    visualiser_collection,
)
from models.visualiser_models import (
    VisualiserGenerateRequest,
    VisualiserGenerateResponse,
    VisualiserSandboxRequest,
    VisualiserSandboxResponse,
    VisualiserStatesListResponse,
    VisualiserUpdateRequest,
    VisualiserUpdateResponse,
)
from services.llm import (
    clean_raw_equation,
    detect_or_resolve_equation_plotter,
    generate_sandbox_simulation,
)
from services.phet_service import phet_service
from services.visualiser_loader import fill_template_defaults, get_template_by_topic

router = APIRouter(
    prefix="/visualiser",
    tags=["Visualiser Engine"],
    dependencies=[Depends(require_firebase_user)],
)


WHITELISTED_TEMPLATE_IDS = {
    "projectile_motion",
    "projectile",
    "free_fall",
    "freefall",
    "shm",
    "harmonic",
    "optics_lens",
    "optics",
    "kinematics_1d",
    "kinematics",
    "atom_bohr",
    "atom",
    "graph_quadratic",
    "graph",
    "equation_plotter",
    "inclined_plane",
    "pulley",
    "collision",
    "mechanics_2d",
    "declarative_physics",
    "generic_diagram",
    "phet-webview",
    "sandbox",
    "ai_canvas",
    "micro_simulation",
    "default-empty",
}


def _is_allowed_phet_url(url: str) -> bool:
    if not url or not isinstance(url, str):
        return False
    try:
        parsed = urlparse(url)
        return (
            parsed.scheme == "https" and parsed.netloc == "phet.colorado.edu" and parsed.path.startswith("/sims/html/")
        )
    except Exception:
        return False


@router.post("/generate", response_model=VisualiserGenerateResponse)
@limiter.limit(LIMIT_STANDARD)
async def generate_visualiser_entry(request: Request, req: VisualiserGenerateRequest):
    topic = req.topic

    # 1. Step 2: Try Equation & Math Function Plotter Detection
    equation_template = await detect_or_resolve_equation_plotter(topic, req.variables)

    if equation_template and equation_template.get("template_id") in WHITELISTED_TEMPLATE_IDS:
        template_id = equation_template["template_id"]
        filled = equation_template
        parameters = filled.get("parameters", {})
    else:
        # 2. Try Internal Visualiser
        template = await get_template_by_topic(topic)

        if template and template.get("template_id") in WHITELISTED_TEMPLATE_IDS:
            filled = fill_template_defaults(template, req.variables)
            template_id = filled["template_id"]
            parameters = filled.get("parameters", {})
        else:
            # 3. Step 1: Try PhET Simulation Fallback (124+ official sims)
            phet_match = phet_service.find_simulation(topic)

            if phet_match and _is_allowed_phet_url(phet_match.get("url", "")):
                template_id = "phet-webview"
                filled = {
                    "template_id": template_id,
                    "templateId": template_id,
                    "parameters": {},
                    "metadata": {
                        "type": "phet",
                        "url": phet_match["url"],
                        "title": phet_match["title"],
                        "slug": phet_match["slug"],
                        "subject": phet_match.get("subject", "general"),
                    },
                }
                parameters = {}
            elif req.allow_sandbox_fallback:
                # 4. Step 3: AI Micro-Simulation Sandbox for long-tail topics
                sandbox_data = await generate_sandbox_simulation(
                    topic=topic,
                    variables=req.variables,
                )
                template_id = "sandbox"
                parameters = sanitize_simulation_parameters(sandbox_data.get("parameters", {}))
                filled = {
                    "template_id": template_id,
                    "templateId": template_id,
                    "title": sandbox_data["title"],
                    "animation_type": "canvas_sandbox",
                    "description": sandbox_data.get("description", ""),
                    "parameters": parameters,
                    "metadata": {
                        "type": "sandbox",
                        "html": sandbox_data["html"],
                        "topic": topic,
                    },
                }
            else:
                # 5. Safe Whitelisted Fallback
                template_id = "default-empty"
                filled = {
                    "template_id": template_id,
                    "templateId": template_id,
                    "parameters": {},
                    "metadata": {"type": "none"},
                }
                parameters = {}

    # Clamp parameters for safety
    parameters = sanitize_simulation_parameters(parameters)

    # Save to DB
    user_id = request.state.user["uid"]
    history_id = await save_visualiser_entry(
        user_id=user_id,
        template_id=template_id,
        parameters=parameters,
        history_id=None,
    )

    if (template_id in {"phet-webview", "equation_plotter", "sandbox", "ai_canvas"}) and visualiser_collection is not None and history_id:
        try:
            await visualiser_collection.update_one(
                {"_id": ObjectId(history_id)},
                {"$set": {"metadata": filled.get("metadata", {}), "title": filled.get("title", "")}},
            )
        except Exception:
            pass

    return VisualiserGenerateResponse(
        status="success",
        template=filled,
        history_id=history_id,
    )


@router.post("/generate-sandbox", response_model=VisualiserSandboxResponse)
@limiter.limit(LIMIT_STANDARD)
async def generate_sandbox_entry(request: Request, req: VisualiserSandboxRequest):
    """
    Step 3: Dedicated endpoint to generate dynamic HTML5 Canvas animations
    inside a secured sandbox container for any STEM topic.
    """
    user_id = request.state.user["uid"]
    sandbox_data = await generate_sandbox_simulation(
        topic=req.topic,
        user_prompt=req.prompt,
        variables=req.variables,
    )
    template_id = "sandbox"
    parameters = sanitize_simulation_parameters(sandbox_data.get("parameters", {}))
    template_dict = {
        "template_id": template_id,
        "templateId": template_id,
        "title": sandbox_data["title"],
        "animation_type": "canvas_sandbox",
        "description": sandbox_data.get("description", ""),
        "parameters": parameters,
        "metadata": {
            "type": "sandbox",
            "html": sandbox_data["html"],
            "topic": req.topic,
        },
    }

    history_id = await save_visualiser_entry(
        user_id=user_id,
        template_id=template_id,
        parameters=parameters,
        history_id=None,
    )

    if visualiser_collection is not None and history_id:
        try:
            await visualiser_collection.update_one(
                {"_id": ObjectId(history_id)},
                {"$set": {"metadata": template_dict["metadata"], "title": sandbox_data["title"]}},
            )
        except Exception:
            pass

    return VisualiserSandboxResponse(
        status="success",
        template_id=template_id,
        title=sandbox_data["title"],
        topic=req.topic,
        html=sandbox_data["html"],
        template=template_dict,
        parameters=parameters,
        history_id=history_id,
        degraded=sandbox_data.get("degraded", False),
    )


@router.post("/update", response_model=VisualiserUpdateResponse)
@limiter.limit(LIMIT_CHAT)
async def update_visualiser(
    request: Request,
    req: VisualiserUpdateRequest,
    x_groq_api_key: str = Header(None, alias="x-groq-api-key"),
):
    clamped_params = sanitize_simulation_parameters(req.parameters)
    updated: Dict[str, Any] = {}
    ai_response: str = "No AI changes were applied."

    if req.template_id == "phet-webview":
        return VisualiserUpdateResponse(
            template_id=req.template_id,
            history_id=req.history_id or "",
            parameters=clamped_params,
            ai_updates={},
            ai_response="AI control is not supported for interactive web simulations yet.",
        )

    user_id = request.state.user["uid"]

    if req.user_prompt and req.user_prompt.strip():
        await check_and_increment_daily_usage(user_id=user_id)
        try:
            from services.llm import parse_param_update

            result = await parse_param_update(
                template_id=req.template_id,
                current_params=clamped_params,
                user_prompt=req.user_prompt,
            )
            # Server-side clamp the AI-generated updates
            updated = sanitize_simulation_parameters(result.updated_parameters)
            ai_response = result.ai_response

            # Special support for equation updates in equation_plotter
            if req.template_id == "equation_plotter" and req.history_id and visualiser_collection is not None:
                # Check if prompt requests a new formula
                if "equation" in result.updated_parameters:
                    new_eq = clean_raw_equation(str(result.updated_parameters["equation"]))
                    await visualiser_collection.update_one(
                        {"_id": ObjectId(req.history_id)},
                        {"$set": {"metadata.equation": new_eq}},
                    )
        except Exception:
            updated = {}
            ai_response = "Error processing request."

    merged = dict(clamped_params)
    merged.update(updated)
    merged = sanitize_simulation_parameters(merged)

    history_id = await save_visualiser_entry(
        user_id=user_id,
        template_id=req.template_id,
        parameters=merged,
        history_id=req.history_id,
    )

    return VisualiserUpdateResponse(
        template_id=req.template_id,
        history_id=history_id,
        parameters=merged,
        ai_updates=updated,
        ai_response=ai_response,
    )


@router.get("/history", response_model=VisualiserStatesListResponse)
@limiter.limit(LIMIT_STANDARD)
async def visualiser_history(
    request: Request,
    limit: int = Query(20, ge=1, le=100),
    skip: int = Query(0, ge=0),
):
    user_id = request.state.user["uid"]
    entries, total = await get_visualiser_entries_paginated(user_id, limit=limit, skip=skip)
    has_more = (skip + len(entries)) < total
    return VisualiserStatesListResponse(
        items=entries,
        history=entries,
        total=total,
        limit=limit,
        skip=skip,
        has_more=has_more,
    )


@router.get("/entry/{history_id}")
@limiter.limit(LIMIT_STANDARD)
async def get_visualiser_entry(request: Request, history_id: str):
    if not visualiser_collection:
        raise HTTPException(
            status_code=503,
            detail="Visualiser database is currently unavailable",
        )

    user_id = request.state.user["uid"]
    try:
        query = {"_id": ObjectId(history_id), "user_id": user_id}
        doc = await visualiser_collection.find_one(query)
        if not doc:
            raise HTTPException(status_code=404, detail="Entry not found")

        doc["id"] = str(doc["_id"])
        doc.pop("_id", None)
        return doc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid entry ID") from exc
