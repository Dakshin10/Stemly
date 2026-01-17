from fastapi import APIRouter, HTTPException, Depends, Request, Header
from openai import AuthenticationError
from pydantic import BaseModel
from typing import Dict, Any, Optional
from services.visualiser_loader import get_template_by_topic, fill_template_defaults
from services.phet_service import phet_service
from database.visualiser_model import save_visualiser_entry, get_visualiser_entries
from auth.auth_middleware import require_firebase_user

router = APIRouter(
    prefix="/visualiser",
    tags=["Visualiser Engine"],
    dependencies=[Depends(require_firebase_user)],
)


class VisualiserGenerateRequest(BaseModel):
    topic: str
    variables: Optional[list] = None
    user_id: Optional[str] = None


class VisualiserUpdateRequest(BaseModel):
    template_id: str
    parameters: Dict[str, Any]
    user_prompt: Optional[str] = None
    user_id: Optional[str] = None
    history_id: Optional[str] = None


@router.post("/generate")
async def generate_visualiser_entry(req: VisualiserGenerateRequest, request: Request):
    topic = req.topic
    
    # 1. Try Internal Visualiser
    template = await get_template_by_topic(topic)
    
    if template:
        # Internal template found
        filled = fill_template_defaults(template, req.variables)
        template_id = filled["template_id"]
        parameters = filled["parameters"]
    else:
        # 2. Try PhET Fallback
        phet_match = phet_service.find_simulation(topic)
        
        if phet_match:
            template_id = "phet-webview"
            filled = {
                "template_id": template_id,
                "templateId": template_id, # Frontend compat
                "parameters": {},
                "metadata": {
                    "type": "phet",
                    "url": phet_match["url"],
                    "title": phet_match["title"],
                    "slug": phet_match["slug"],
                    "subject": phet_match.get("subject", "general")
                }
            }
            parameters = {}
        else:
            # 3. Last Resort
            template_id = "default-empty"
            filled = {
                "template_id": template_id,
                "templateId": template_id,
                "parameters": {},
                "metadata": {"type": "none"}
            }
            parameters = {}

    # Save to DB
    user_id = request.state.user["uid"]
    history_id = await save_visualiser_entry(
        user_id=user_id,
        template_id=template_id,
        parameters=parameters,
        history_id=None
    )
    
    # Ensure history_id is in the template metadata mostly for frontend reference?
    # Actually frontend expects history_id in the root response.
    
    # IMPORTANT: Save extra PhET metadata if needed. 
    # Current save_visualiser_entry only saves parameters. 
    # The doc for phet needs to save the URL somewhere.
    # The save_visualiser_entry saves the *entire doc*? 
    # Visualiser model code:
    # doc = { "user_id": ..., "template_id": ..., "parameters": ... }
    # It misses metadata! 
    # But for internal templates, metadata is part of the static file, not DB.
    # For PhET, metadata IS dynamic (the URL).
    # We should probably update the DB model to store metadata or hack it into parameters.
    # Hack: put url in parameters for now? No, messy.
    # Better: Update save_visualiser_entry to accept metadata?
    # Or just rely on the frontend getting it now.
    # BUT updates/reloads will fail if we don't save the PhET URL.
    # So we MUST update existing DB entry with metadata if it's PhET.
    
    if template_id == "phet-webview":
        # Retroactive update to add metadata to the just-created document
        from database.visualiser_model import visualiser_collection
        from bson import ObjectId
        if visualiser_collection:
            await visualiser_collection.update_one(
                {"_id": ObjectId(history_id)},
                {"$set": {"metadata": filled["metadata"]}}
            )

    return {
        "status": "success", 
        "template": filled,
        "history_id": history_id
    }


from config import FALLBACK_GROQ_API_KEY

@router.post("/update")
async def update_visualiser(
    req: VisualiserUpdateRequest, 
    request: Request,
    x_groq_api_key: str = Header(None, alias="x-groq-api-key")
):
    # Default values
    updated: Dict[str, Any] = {}
    ai_response: str = "No AI changes were applied."

    if req.template_id == "phet-webview":
        return {
             "template_id": req.template_id,
             "history_id": req.history_id,
             "parameters": req.parameters,
             "ai_updates": {},
             "ai_response": "AI control is not supported for interactive web simulations yet.",
        }

    if req.user_prompt and req.user_prompt.strip():
        print(f"DEBUG: Update Request - History ID: {req.history_id}")
        api_key_to_use = x_groq_api_key or FALLBACK_GROQ_API_KEY
        
        if not api_key_to_use:
             print("⚠ Missing API Key")
             ai_response = "Please configure Groq API Key settings."
        else:
            try:
                from services.ai_visualiser import adjust_parameters_with_ai
                ai_result = await adjust_parameters_with_ai(
                    req.template_id,
                    req.parameters,
                    req.user_prompt,
                    api_key=api_key_to_use
                )
                updated = ai_result.get("updated_parameters", {})
                ai_response = ai_result.get("ai_response", "Updated parameters.")
            except Exception as e:
                print(f"⚠ AI Update Error: {e}")
                updated = {}
                ai_response = "Error processing request."

    merged = dict(req.parameters)
    merged.update(updated)

    user_id = request.state.user["uid"]
    history_id = await save_visualiser_entry(
        user_id=user_id,
        template_id=req.template_id,
        parameters=merged,
        history_id=req.history_id
    )

    return {
        "template_id": req.template_id,
        "history_id": history_id,
        "parameters": merged,
        "ai_updates": updated,
        "ai_response": ai_response,
    }


from bson import ObjectId

@router.get("/{history_id}")
async def get_visualiser_entry(history_id: str, request: Request):
    from database.visualiser_model import visualiser_collection
    
    if not visualiser_collection:
        raise HTTPException(status_code=503, detail="Database disabled")
        
    try:
        doc = await visualiser_collection.find_one({"_id": ObjectId(history_id)})
        if not doc:
             raise HTTPException(status_code=404, detail="Entry not found")
        
        template_id = doc.get("template_id")
        
        # Helper to build response
        response_template = {}

        if template_id == "phet-webview":
            # Reconstruct PhET template from DB metadata
            response_template = {
                "template_id": template_id,
                "templateId": template_id,
                "parameters": doc.get("parameters", {}),
                "metadata": doc.get("metadata", {})
            }
        else:
            # Internal template: Load definition + merge params
            raw_template = await get_template_by_topic(template_id)
            if not raw_template:
                # Fallback check?
                pass
            
            if raw_template:
                filled = fill_template_defaults(raw_template)
                # Override params
                db_params = doc.get("parameters", {})
                for k, v in db_params.items():
                    if k in filled["parameters"]:
                        filled["parameters"][k]["value"] = v
                response_template = filled
            else:
                 # If template file missing but DB exists (e.g. old code version)
                 # Return partial 
                 response_template = {
                     "template_id": template_id,
                     "parameters": doc.get("parameters", {}),
                     "metadata": {"error": "Template definition missing"}
                 }

        return {
            "template_id": template_id,
            "history_id": str(doc["_id"]),
            "template": response_template
        }

    except Exception as e:
        print(f"Error fetching entry: {e}")
        raise HTTPException(status_code=400, detail="Invalid ID")


@router.get("/history")
async def visualiser_history(request: Request):
    user_id = request.state.user["uid"]
    history = await get_visualiser_entries(user_id)
    return {"history": history}
