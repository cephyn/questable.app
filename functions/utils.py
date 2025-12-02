"""
Utility functions for the quest cards Firebase Functions.
"""

import logging
from firebase_admin import firestore
# Prefer direct client import (provided by google-cloud-secret-manager)
from google.cloud.secretmanager import SecretManagerServiceClient  # <-- fixed import

# Reuse a single client (Secret Manager clients are thread‑safe)
_secret_manager_client: SecretManagerServiceClient | None = None


def get_secret(secret_name, project_id="766749273273"):
    """Get a secret from Google Cloud Secret Manager."""
    global _secret_manager_client
    if _secret_manager_client is None:
        _secret_manager_client = SecretManagerServiceClient()
    secret_version_name = f"projects/{project_id}/secrets/{secret_name}/versions/latest"
    response = _secret_manager_client.access_secret_version(name=secret_version_name)
    return response.payload.data.decode("UTF-8")


def log_social_post_attempt(quest_id, platform, status, message, link=None, post_id=None):
    """Log social media post attempts to Firestore."""
    db = firestore.client()
    log_entry = {
        "questId": quest_id,
        "platform": platform,
        "status": status,
        "message": message,
        "timestamp": firestore.SERVER_TIMESTAMP,
    }
    if link:
        log_entry["link"] = link
    if post_id:
        log_entry["postId"] = post_id
    
    try:
        db.collection("social_post_logs").add(log_entry)
        logging.info(f"Logged social post attempt for quest {quest_id} on {platform}: {status}")
    except Exception as e:
        logging.error(f"Failed to log social post attempt for quest {quest_id} on {platform}: {e}")
