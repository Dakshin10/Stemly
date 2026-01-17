from datetime import datetime
from typing import Any, Dict, List

from .db import db

# Handle case where db is None
visualiser_collection = db["visualiser"] if db is not None else None


async def save_visualiser_entry(user_id: str, template_id: str, parameters: Dict[str, Any], history_id: str = None):
    if not user_id:
        raise ValueError("user_id is required")

    doc = {
        "user_id": user_id,
        "template_id": template_id,
        "parameters": parameters,
        "timestamp": datetime.utcnow(),
    }

    if visualiser_collection is None:
        print("⚠ Database disabled, skipping save_visualiser_entry")
        return "no-db-record"

    if history_id:
        from bson import ObjectId
        try:
            # Update existing entry
            await visualiser_collection.update_one(
                {"_id": ObjectId(history_id), "user_id": user_id},
                {"$set": doc}
            )
            return history_id
        except Exception as e:
            print(f"Error updating visualiser entry: {e}")
            # Fallback to insert if update fails
    
    result = await visualiser_collection.insert_one(doc)
    return str(result.inserted_id)


async def get_visualiser_entries(user_id: str, limit: int = 20):
    if not user_id or visualiser_collection is None:
        return []

    cursor = (
        visualiser_collection.find({"user_id": user_id})
        .sort("timestamp", -1)
        .limit(limit)
    )

    entries: List[Dict[str, Any]] = []
    async for doc in cursor:
        doc["_id"] = str(doc["_id"])
        entries.append(doc)
    return entries
