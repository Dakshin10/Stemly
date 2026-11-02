import uuid
from datetime import datetime
from typing import Any, Dict, List

# Temporary DB — replace with MongoDB/Postgres later
DATABASE: List[Dict[str, Any]] = []


def add_history(user_id: str, image_path: str, topic: str, variables: list) -> str:
    rec_id = str(uuid.uuid4())
    record: Dict[str, Any] = {
        "id": rec_id,
        "user_id": user_id,
        "image_path": image_path,
        "topic": topic,
        "variables": variables,
        "timestamp": datetime.now().isoformat(),
    }

    DATABASE.append(record)
    return rec_id


def get_user_history(user_id: str) -> List[Dict[str, Any]]:
    return [entry for entry in DATABASE if entry["user_id"] == user_id]
