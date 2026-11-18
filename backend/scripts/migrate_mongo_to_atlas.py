#!/usr/bin/env python3
"""
MongoDB Local (Compass) to MongoDB Atlas Cloud Migration Script for Stemly.

Usage:
    python scripts/migrate_mongo_to_atlas.py --atlas-uri "mongodb+srv://<user>:<password>@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority"
    or set TARGET_ATLAS_URI in your environment / arguments.
"""

import argparse
import asyncio
import os
import sys
from pathlib import Path
from typing import Any, Dict, List

# Ensure backend root is on sys.path
CURRENT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = CURRENT_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import certifi
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import UpdateOne
from pymongo.server_api import ServerApi

LOCAL_URI_DEFAULT = "mongodb://localhost:27017"
DB_NAME = "stemly_db"


async def migrate_data(source_uri: str, target_uri: str, update_env: bool = False):
    print("=" * 70)
    print("🚀 STEMLY MONGODB LOCAL -> MONGODB ATLAS MIGRATION")
    print("=" * 70)
    print(f"Source (Local):  {source_uri}")
    print(f"Target (Atlas):  {target_uri[:35]}... (redacted)")

    # 1. Connect to Local Source
    try:
        source_client = AsyncIOMotorClient(source_uri, serverSelectionTimeoutMS=5000)
        await source_client.admin.command("ping")
        print("✅ Connected to Local MongoDB successfully.")
    except Exception as e:
        print(f"❌ Failed to connect to local MongoDB at {source_uri}: {e}")
        return False

    # 2. Connect to Target Atlas
    try:
        target_client = AsyncIOMotorClient(
            target_uri,
            tlsCAFile=certifi.where(),
            server_api=ServerApi("1"),
            serverSelectionTimeoutMS=10000,
            retryWrites=True,
        )
        await target_client.admin.command("ping")
        print("✅ Connected to MongoDB Atlas cluster successfully.")
    except Exception as e:
        print(f"❌ Failed to connect to MongoDB Atlas: {e}")
        print("\nTroubleshooting Tips:")
        print("1. Did you whitelist your IP address in Atlas (Network Access -> Add IP Address / Allow Anywhere 0.0.0.0/0)?")
        print("2. Are your Atlas username and password correct?")
        print("3. If password has special characters like '@', '#', '%', URL-encode them.")
        return False

    source_db = source_client[DB_NAME]
    target_db = target_client[DB_NAME]

    collections = await source_db.list_collection_names()
    print(f"\n📦 Found {len(collections)} collections in local '{DB_NAME}': {collections}\n")

    total_migrated = 0

    for col_name in collections:
        source_col = source_db[col_name]
        target_col = target_db[col_name]

        docs: List[Dict[str, Any]] = await source_col.find({}).to_list(length=None)
        doc_count = len(docs)

        if doc_count == 0:
            print(f"  • {col_name:20}: 0 documents (skipped)")
            continue

        # Upsert documents by _id to avoid duplicates
        operations = [
            UpdateOne({"_id": doc["_id"]}, {"$set": doc}, upsert=True)
            for doc in docs
        ]

        result = await target_col.bulk_write(operations, ordered=False)
        upserted_or_matched = result.upserted_count + result.matched_count + result.modified_count
        total_migrated += doc_count
        print(f"  • {col_name:20}: {doc_count} documents migrated (upserted/updated: {upserted_or_matched})")

    # 3. Initialize performance and TTL indexes on Atlas
    print("\n⚡ Initializing database indexes on MongoDB Atlas...")
    try:
        from database.indexes import init_db_indexes
        # Temporarily point database.db.client to target_client for index init
        import database.db as db_mod
        original_db = db_mod.db
        original_client = db_mod.client
        db_mod.db = target_db
        db_mod.client = target_client
        await init_db_indexes()
        db_mod.db = original_db
        db_mod.client = original_client
        print("✅ Indexes initialized successfully on Atlas.")
    except Exception as idx_err:
        print(f"⚠️  Index initialization note: {idx_err}")

    print("\n" + "=" * 70)
    print(f"🎉 MIGRATION COMPLETE! Total documents migrated: {total_migrated}")
    print("=" * 70)

    # 4. Optional: Update .env with new Atlas URI
    if update_env:
        env_path = BACKEND_DIR / ".env"
        if env_path.exists():
            with open(env_path, "r", encoding="utf-8") as f:
                content = f.read()

            import re
            new_content = re.sub(
                r"^MONGO_URI=.*$",
                f"MONGO_URI={target_uri}",
                content,
                flags=re.MULTILINE,
            )
            with open(env_path, "w", encoding="utf-8") as f:
                f.write(new_content)
            print("📝 Updated MONGO_URI in backend/.env with Atlas connection string.")

    return True


def main():
    parser = argparse.ArgumentParser(description="Migrate local MongoDB to MongoDB Atlas")
    parser.add_argument("--atlas-uri", type=str, help="Target MongoDB Atlas connection string", required=False)
    parser.add_argument("--source-uri", type=str, default=LOCAL_URI_DEFAULT, help="Local MongoDB connection string")
    parser.add_argument("--update-env", action="store_true", help="Update backend/.env with the new Atlas URI")
    args = parser.parse_args()

    atlas_uri = args.atlas_uri or os.environ.get("TARGET_ATLAS_URI")
    if not atlas_uri:
        print("❌ Error: MongoDB Atlas connection string is required.")
        print("Usage: python scripts/migrate_mongo_to_atlas.py --atlas-uri \"mongodb+srv://...\" [--update-env]")
        sys.exit(1)

    success = asyncio.run(migrate_data(args.source_uri, atlas_uri, update_env=args.update_env))
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
