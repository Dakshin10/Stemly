import json
import os
from typing import Any, Dict, Optional

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials

SERVICE_ACCOUNT_FILE_ENV = "FIREBASE_CREDENTIALS_FILE"
SERVICE_ACCOUNT_JSON_ENV = "FIREBASE_CREDENTIALS_JSON"


def _initialize_app() -> firebase_admin.App:
    if firebase_admin._apps:
        return firebase_admin.get_app()

    file_path = os.getenv(SERVICE_ACCOUNT_FILE_ENV)
    json_blob = os.getenv(SERVICE_ACCOUNT_JSON_ENV)

    if file_path and os.path.isfile(file_path):
        try:
            cred = credentials.Certificate(file_path)
            return firebase_admin.initialize_app(cred)
        except Exception as e:
            print(f"⚠️ Error loading Firebase service account from {file_path}: {e}")

    if json_blob:
        try:
            service_account_dict: Dict[str, Any] = json.loads(json_blob)
            cred = credentials.Certificate(service_account_dict)
            return firebase_admin.initialize_app(cred)
        except Exception as e:
            print(f"⚠️ Error loading Firebase service account from JSON: {e}")

    # Fallback to project-only initialization (verifies ID tokens via Google public certs)
    project_id = os.getenv("FIREBASE_PROJECT_ID", "stemly-929a6")
    return firebase_admin.initialize_app(options={"projectId": project_id})


def verify_firebase_token(id_token: str) -> Dict[str, Optional[str]]:
    """
    Verify the incoming Firebase ID token and return the normalized user info.
    """
    if not id_token:
        raise ValueError("Missing Firebase ID token")

    app = _initialize_app()
    try:
        decoded = firebase_auth.verify_id_token(id_token, app=app)
    except Exception as e:
        print(f"🔥 FIREBASE VERIFICATION ERROR: {str(e)}")
        raise e

    return {
        "uid": decoded.get("uid"),
        "email": decoded.get("email"),
        "name": decoded.get("name") or decoded.get("displayName"),
        "picture": decoded.get("picture"),
    }
