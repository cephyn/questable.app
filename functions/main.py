# Welcome to Cloud Functions for Firebase for Python!
# To get started, simply uncomment the below code or create your own.
# Deploy with `firebase deploy`

from firebase_functions import (
    params,
    scheduler_fn,
    https_fn,
    firestore_fn,
    options,  # Added options for memory allocation
    # auth_fn, # Commented out or removed if no other 1st gen auth functions exist
)
from firebase_admin import (
    initialize_app,
    firestore,
)
import logging  # Added
import datetime  # Added
import random  # Added
import re  # Added

# from markitdown import MarkItDown # Commented out as it's likely an uninstalled library and not used by core features
from google.cloud import secretmanager  # Added for Secret Manager
from io import BytesIO
from atproto import Client, models, client_utils  # For Bluesky, added client_utils
import google.generativeai as genai  # Added for Gemini

# Set root logger level to INFO for better visibility in Cloud Run if default is higher
logging.getLogger().setLevel(logging.INFO)

# Configure the root logger to handle INFO and higher severity messages
# logging.basicConfig(level=logging.INFO)
# If you also need DEBUG messages, use:
logging.basicConfig(level=logging.DEBUG)

initialize_app()


@https_fn.on_call()
def on_call_example(req: https_fn.CallableRequest) -> any:
    return {"text": req.data["text"]}


# @https_fn.on_call()
# def pdf_to_md(req: https_fn.CallableRequest) -> any:
#     url = req.data["url"]
#     md = MarkItDown(enable_plugins=False)  # Set to True to enable plugins
#     result = md.convert(url)
#
#     return result.text_content


# Game System Standardization Functions
# Move db initialization inside functions to avoid auth errors during local development


# Helper functions for game system standardization
def normalize_game_system_name(name):
    """Normalize a game system name for comparison"""
    if name is None:
        return None
    return name.strip().lower()


def find_matching_standard_system(game_system_name):
    """Find a matching standard game system based on name or aliases"""
    if not game_system_name:
        return None

    normalized_name = normalize_game_system_name(game_system_name)

    # Step 1: Try exact match on standard name
    db = firestore.client()
    standard_systems = db.collection("game_systems")

    # First try exact match on standard name
    exact_match_query = standard_systems.where(
        "standardName", "==", game_system_name
    ).limit(1)
    exact_matches = exact_match_query.stream()

    for system in exact_matches:
        return {
            "id": system.id,
            "standardName": system.get("standardName"),
            "matchType": "exact",
            "confidence": 1.0,
        }

    # Step 2: Search in aliases (this is an inefficient approach in Firestore,
    # but we'll use it for simplicity - in production, consider a different approach)
    all_systems = standard_systems.stream()
    for system in all_systems:
        system_data = system.to_dict()

        # Check standard name with case-insensitive match
        if (
            normalize_game_system_name(system_data.get("standardName"))
            == normalized_name
        ):
            return {
                "id": system.id,
                "standardName": system_data.get("standardName"),
                "matchType": "case_insensitive",
                "confidence": 0.99,
            }

        # Check aliases
        aliases = system_data.get("aliases", [])
        for alias in aliases:
            if normalize_game_system_name(alias) == normalized_name:
                return {
                    "id": system.id,
                    "standardName": system_data.get("standardName"),
                    "matchType": "alias",
                    "confidence": 0.98,
                }

    # Step 3: Basic substring check for partial matches
    potential_match = None
    highest_confidence = 0.0

    for system in all_systems:
        system_data = system.to_dict()
        standard_name = system_data.get("standardName", "")
        normalized_standard = normalize_game_system_name(standard_name)

        # Check if one is substring of the other
        if normalized_name and normalized_standard:
            if (
                normalized_name in normalized_standard
                or normalized_standard in normalized_name
            ):
                confidence = 0.85  # Reasonable confidence for substring match
                if confidence > highest_confidence:
                    highest_confidence = confidence
                    potential_match = {
                        "id": system.id,
                        "standardName": standard_name,
                        "matchType": "substring",
                        "confidence": confidence,
                    }

        # Check for acronym match (e.g., "D&D" for "Dungeons & Dragons")
        if normalized_name and normalized_standard:
            words = re.split(r"\s|&", normalized_standard)
            acronym = "".join([word[0] for word in words if word])
            if acronym == normalized_name:
                confidence = 0.90  # High confidence for acronym match
                if confidence > highest_confidence:
                    highest_confidence = confidence
                    potential_match = {
                        "id": system.id,
                        "standardName": standard_name,
                        "matchType": "acronym",
                        "confidence": confidence,
                    }

    return potential_match


def record_system_mapping_metrics(match_result, original_system):
    """Record metrics for system mappings for continuous improvement"""
    if not match_result:
        return

    db = firestore.client()
    # Record this mapping in metrics
    today = datetime.datetime.now().strftime("%Y-%m-%d")
    metrics_ref = db.collection("migration_metrics").document(today)

    # Create or update the daily metrics document
    metrics_ref.set(
        {"date": today, "lastUpdated": firestore.SERVER_TIMESTAMP}, merge=True
    )

    # Update system-specific metrics
    system_metrics_ref = metrics_ref.collection("systems").document(
        match_result["standardName"]
    )
    system_metrics_ref.set(
        {
            "standardName": match_result["standardName"],
            "count": firestore.Increment(1),
            "lastUpdated": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )

    # Record the mapping for learning purposes
    mapping_ref = db.collection("system_mappings").document()
    mapping_ref.set(
        {
            "originalSystem": original_system,
            "standardSystem": match_result["standardName"],
            "confidence": match_result["confidence"],
            "matchType": match_result["matchType"],
            "timestamp": firestore.SERVER_TIMESTAMP,
        }
    )


# On Create - Ingestion-time standardization for new quest cards
@firestore_fn.on_document_created(
    document="questCards/{questId}"
)  # Temporarily disabled for testing scheduled_game_system_cleanup
def standardize_new_quest_card(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Automatically standardize game system when a new quest card is created"""
    try:
        # Get the new quest card data
        quest_data = event.data.to_dict()
        if not quest_data:
            return

        # Check if game system field exists
        original_game_system = quest_data.get("gameSystem")
        if not original_game_system:
            return

        # Skip if already standardized
        if (
            "standardizedGameSystem" in quest_data
            and quest_data["standardizedGameSystem"]
        ):
            return

        # Find matching standard system
        match_result = find_matching_standard_system(original_game_system)

        # If no match or low confidence, mark for manual review
        update_data = {}

        if match_result and match_result["confidence"] >= 0.85:
            # High confidence match - apply standardization
            update_data = {
                "standardizedGameSystem": match_result["standardName"],
                "systemMigrationStatus": "completed",
                "systemMigrationConfidence": match_result["confidence"],
                "systemMigrationMatchType": match_result["matchType"],
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }

            # Record metrics
            record_system_mapping_metrics(match_result, original_game_system)
        elif match_result and match_result["confidence"] >= 0.6:
            # Medium confidence - mark for review but suggest a system
            update_data = {
                "suggestedSystem": match_result["standardName"],
                "systemMigrationStatus": "needs_review",
                "systemMigrationConfidence": match_result["confidence"],
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }
        else:
            # No match or very low confidence
            update_data = {
                "systemMigrationStatus": "no_match",
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }

        # Update the quest card
        event.data.reference.update(update_data)

    except Exception as e:
        logging.error(f"Error in standardize_new_quest_card: {e}")
        event.data.reference.update(
            {
                "systemMigrationStatus": "failed",
                "systemMigrationError": str(e),
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }
        )


# On Update - Handle game system changes in quest cards
@firestore_fn.on_document_updated(
    document="questCards/{questId}"
)  # Temporarily disabled for testing scheduled_game_system_cleanup
def handle_quest_card_update(
    event: firestore_fn.Event[firestore_fn.Change[firestore_fn.DocumentSnapshot]],
) -> None:
    """Handle game system changes when a quest card is updated"""
    try:
        before_data = event.data.before.to_dict() or {}
        after_data = event.data.after.to_dict() or {}

        # Check if the game system field was changed
        if (
            "gameSystem" not in before_data
            or "gameSystem" not in after_data
            or before_data.get("gameSystem") == after_data.get("gameSystem")
        ):
            return

        # Game system was changed, re-standardize
        original_game_system = after_data.get("gameSystem")

        # Find matching standard system
        match_result = find_matching_standard_system(original_game_system)

        # If no match or low confidence, mark for manual review
        update_data = {}

        if match_result and match_result["confidence"] >= 0.85:
            # High confidence match - apply standardization
            update_data = {
                "standardizedGameSystem": match_result["standardName"],
                "systemMigrationStatus": "completed",
                "systemMigrationConfidence": match_result["confidence"],
                "systemMigrationMatchType": match_result["matchType"],
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }

            # Record metrics
            record_system_mapping_metrics(match_result, original_game_system)
        elif match_result and match_result["confidence"] >= 0.6:
            # Medium confidence - mark for review but suggest a system
            update_data = {
                "suggestedSystem": match_result["standardName"],
                "systemMigrationStatus": "needs_review",
                "systemMigrationConfidence": match_result["confidence"],
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }
        else:
            # No match or very low confidence
            update_data = {
                "systemMigrationStatus": "no_match",
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }

        # Update the quest card
        event.data.after.reference.update(update_data)

    except Exception as e:
        logging.error(f"Error in handle_quest_card_update: {e}")
        event.data.after.reference.update(
            {
                "systemMigrationStatus": "failed",
                "systemMigrationError": str(e),
                "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
            }
        )


# Scheduled Background Cleanup Process - runs daily at midnight
@scheduler_fn.on_schedule(schedule="0 0 * * *")
def scheduled_game_system_cleanup(event: scheduler_fn.ScheduledEvent) -> None:
    """Daily scheduled job to clean up game system standardization"""
    try:
        batch_size = 100
        processed = 0
        successful = 0
        failed = 0
        needs_review = 0

        # Create a migration log entry
        migration_id = f"scheduled_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}"
        migration_ref = (
            firestore.client().collection("migration_logs").document(migration_id)
        )
        migration_ref.set(
            {
                "timestamp": firestore.SERVER_TIMESTAMP,
                "type": "scheduled",
                "status": "in_progress",
            }
        )

        # Get quest cards that need standardization
        query = (
            firestore.client()
            .collection("questCards")
            .where("systemMigrationStatus", "in", ["pending", "failed", None])
            .limit(batch_size)
        )

        docs = list(query.stream())

        while docs:
            batch = firestore.client().batch()

            for doc in docs:
                processed += 1
                quest_data = doc.to_dict()
                original_game_system = quest_data.get("gameSystem")

                if not original_game_system:
                    continue

                # Find matching standard system
                match_result = find_matching_standard_system(original_game_system)

                if match_result and match_result["confidence"] >= 0.85:
                    # High confidence match - apply standardization
                    batch.update(
                        doc.reference,
                        {
                            "standardizedGameSystem": match_result["standardName"],
                            "systemMigrationStatus": "completed",
                            "systemMigrationConfidence": match_result["confidence"],
                            "systemMigrationMatchType": match_result["matchType"],
                            "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
                            "migrationId": migration_id,
                        },
                    )
                    successful += 1

                    # Record metrics
                    record_system_mapping_metrics(match_result, original_game_system)
                elif match_result and match_result["confidence"] >= 0.6:
                    # Medium confidence - mark for review
                    batch.update(
                        doc.reference,
                        {
                            "suggestedSystem": match_result["standardName"],
                            "systemMigrationStatus": "needs_review",
                            "systemMigrationConfidence": match_result["confidence"],
                            "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
                            "migrationId": migration_id,
                        },
                    )
                    needs_review += 1
                else:
                    # No match or very low confidence
                    batch.update(
                        doc.reference,
                        {
                            "systemMigrationStatus": "no_match",
                            "systemMigrationTimestamp": firestore.SERVER_TIMESTAMP,
                            "migrationId": migration_id,
                        },
                    )
                    failed += 1

            # Commit the batch
            batch.commit()

            # Update the migration log
            migration_ref.update(
                {
                    "processed": processed,
                    "successful": successful,
                    "failed": failed,
                    "needsReview": needs_review,
                    "lastUpdated": firestore.SERVER_TIMESTAMP,
                }
            )

            # Get next batch
            last_doc = docs[-1]
            docs = list(query.start_after(last_doc).stream())

            # Break if no more docs to avoid infinite loop
            if not docs:
                break

        # Update final status
        migration_ref.update(
            {
                "status": "completed",
                "completedAt": firestore.SERVER_TIMESTAMP,
                "processed": processed,
                "successful": successful,
                "failed": failed,
                "needsReview": needs_review,
            }
        )

        # Generate daily report
        today = datetime.datetime.now().strftime("%Y-%m-%d")
        # Call the internal helper function directly
        stats = _calculate_standardization_stats()

        # Check if stats calculation resulted in an error before proceeding
        if "error" in stats:
            # Log the error from stats calculation but don't necessarily stop the whole process
            # The main error handling block below will catch larger issues
            logging.error(f"Error generating stats for report: {stats['error']}")
            # Optionally, decide if you want to skip report generation on stats error
            # For now, we'll let it proceed and potentially store the error in the report

        report_ref = (
            firestore.client().collection("standardization_reports").document(today)
        )
        report_ref.set(
            {
                "date": today,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "stats": stats,  # Store the stats dict (might contain the error)
                "migrationId": migration_id,
            }
        )

    except Exception as e:
        logging.error(f"Error in scheduled_game_system_cleanup: {e}")
        if "migration_ref" in locals():
            migration_ref.update(
                {
                    "status": "error",
                    "error": str(e),
                    "completedAt": firestore.SERVER_TIMESTAMP,
                }
            )


# NEW Internal helper function for calculating stats
def _calculate_standardization_stats() -> dict:
    """Calculates and returns current statistics for game system standardization."""
    try:
        db = firestore.client()
        # Get counts for different statuses
        standardized_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "completed")
            .count()
            .get()[0][0]  # Added extra [0]
            .value
        )

        pending_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "pending")
            .count()
            .get()[0][0]  # Added extra [0]
            .value
        )

        failed_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "failed")
            .count()
            .get()[0][0]  # Added extra [0]
            .value
        )

        needs_review_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "needs_review")
            .count()
            .get()[0][0]  # Added extra [0]
            .value
        )

        no_match_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "no_match")
            .count()
            .get()[0][0]  # Added extra [0]
            .value
        )

        # Add count for 'flagged' status if it exists
        flagged_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "flagged")
            .count()
            .get()[0][0]  # Added extra [0]
            .value
        )

        total_count = (
            db.collection("questCards").count().get()[0][0].value  # Added extra [0]
        )

        # Calculate the number of unprocessed cards (those without any status field or with null/other values)
        processed_statuses_count = (
            standardized_count
            + pending_count
            + failed_count
            + needs_review_count
            + no_match_count
            + flagged_count
        )
        unprocessed_count = total_count - processed_statuses_count

        return {
            "standardized": standardized_count,
            "pending": pending_count,
            "failed": failed_count,
            "needsReview": needs_review_count,
            "noMatch": no_match_count,
            "flagged": flagged_count,  # Added flagged count
            "unprocessed": unprocessed_count,
            "total": total_count,
            "coverage": (standardized_count / total_count) if total_count > 0 else 0,
        }

    except Exception as e:
        logging.error(f"Error calculating standardization stats: {e}")
        # Return error within the dictionary for consistency
        return {"error": str(e)}


# MODIFIED Callable function to get current standardization stats
@https_fn.on_call()
def get_standardization_stats(req: https_fn.CallableRequest = None) -> dict:
    """Get current statistics for game system standardization (calls helper)."""
    # Simply call the internal helper function
    return _calculate_standardization_stats()


# Callable function for users to report incorrect mappings
@https_fn.on_call()
def report_incorrect_mapping(req: https_fn.CallableRequest) -> dict:
    """Allow users to report incorrect game system mappings"""
    try:
        db = firestore.client()
        # Get request data
        data = req.data
        quest_id = data.get("questId")
        original_system = data.get("originalSystem")
        suggested_system = data.get("suggestedSystem")
        user_id = req.auth.uid if req.auth else "anonymous"

        if not quest_id or not original_system:
            return {"success": False, "error": "Missing required data"}

        # Record the feedback
        feedback_ref = db.collection("system_mapping_feedback").document()
        feedback_ref.set(
            {
                "questId": quest_id,
                "originalSystem": original_system,
                "currentStandardizedSystem": data.get("currentStandardizedSystem"),
                "suggestedSystem": suggested_system,
                "userId": user_id,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "status": "pending",
            }
        )

        # Update the quest card to mark it for review
        quest_ref = db.collection("questCards").document(quest_id)
        quest_ref.update(
            {
                "systemMigrationStatus": "flagged",
                "suggestedSystem": suggested_system,
                "flaggedBy": user_id,
                "flaggedAt": firestore.SERVER_TIMESTAMP,
            }
        )

        return {"success": True, "feedbackId": feedback_ref.id}

    except Exception as e:
        logging.error(f"Error reporting incorrect mapping: {e}")
        return {"success": False, "error": str(e)}


# Trigger to process user feedback and improve the system
@firestore_fn.on_document_created(document="system_mapping_feedback/{feedbackId}")
def process_system_mapping_feedback(
    event: firestore_fn.Event[firestore_fn.DocumentSnapshot],
) -> None:
    """Process user feedback on incorrect mappings to improve the system"""
    feedback_id = event.resource.split("/")[-1]
    logging.info(f"Processing system mapping feedback for ID: {feedback_id}")

    try:
        db = firestore.client()
        logging.info("Firestore client initialized.")

        # Get the feedback data
        feedback_data = event.data.to_dict()
        if not feedback_data:
            logging.warning(f"Feedback data is empty for ID: {feedback_id}. Exiting.")
            return

        logging.info(f"Feedback data retrieved: {feedback_data}")

        original_system = feedback_data.get("originalSystem")
        suggested_system = feedback_data.get("suggestedSystem")

        if not original_system or not suggested_system:
            logging.warning(
                f"Missing originalSystem or suggestedSystem for ID: {feedback_id}. Exiting."
            )
            return

        logging.info(f"Original: {original_system}, Suggested: {suggested_system}")

        # Find the suggested system in the standard systems
        logging.info(f"Querying game_systems for standardName == {suggested_system}")
        standard_system_query = (
            db.collection("game_systems")
            .where("standardName", "==", suggested_system)
            .limit(1)
        )

        standard_systems = list(standard_system_query.stream())
        logging.info(
            f"Found {len(standard_systems)} standard system(s) matching '{suggested_system}'."
        )

        if not standard_systems:
            # If suggested system doesn't exist, mark feedback for admin review
            logging.warning(
                f"Suggested system '{suggested_system}' not found. Marking feedback {feedback_id} for admin review."
            )
            event.data.reference.update(
                {
                    "status": "needs_admin_review",
                    "processedAt": firestore.SERVER_TIMESTAMP,
                    "note": "Suggested system does not exist in standard systems",
                }
            )
            logging.info(f"Feedback {feedback_id} updated for admin review.")
            return

        standard_system = standard_systems[0]
        standard_system_data = standard_system.to_dict()
        standard_system_id = standard_system.id
        logging.info(f"Found standard system ID: {standard_system_id}")

        # Check if original system is already in aliases
        aliases = standard_system_data.get("aliases", [])
        logging.info(f"Current aliases for {standard_system_id}: {aliases}")
        if original_system in aliases:
            # Already an alias, just mark feedback as processed
            logging.info(
                f"'{original_system}' already in aliases for {standard_system_id}. Marking feedback {feedback_id} as processed."
            )
            event.data.reference.update(
                {
                    "status": "processed",
                    "processedAt": firestore.SERVER_TIMESTAMP,
                    "note": "Original system already in aliases",
                }
            )
            logging.info(f"Feedback {feedback_id} updated as already processed.")
            return

        # Add original system to aliases
        logging.info(f"Adding '{original_system}' to aliases for {standard_system_id}.")
        aliases.append(original_system)
        standard_system.reference.update(
            {"aliases": aliases, "updatedAt": firestore.SERVER_TIMESTAMP}
        )
        logging.info(f"Updated aliases for {standard_system_id}.")

        # Mark feedback as processed
        logging.info(f"Marking feedback {feedback_id} as processed (alias added).")
        event.data.reference.update(
            {
                "status": "processed",
                "processedAt": firestore.SERVER_TIMESTAMP,
                "note": "Added original system to aliases",
            }
        )
        logging.info(f"Feedback {feedback_id} updated as processed.")

        # Update related quest cards that use this original system
        # This is a potentially expensive operation, so we limit it
        logging.info(
            f"Querying questCards where gameSystem == '{original_system}' (limit 100)."
        )
        query = (
            db.collection("questCards")
            .where("gameSystem", "==", original_system)
            .limit(100)
        )

        docs = list(query.stream())
        logging.info(f"Found {len(docs)} quest cards matching '{original_system}'.")

        if docs:
            batch = db.batch()
            logging.info(f"Starting batch update for {len(docs)} quest cards.")
            # --- THIS IS WHERE THE BATCH UPDATE LOGIC SHOULD BE ---
            # You need to iterate through 'docs' and add update operations to the batch
            # For example:
            # for doc in docs:
            #     batch.update(doc.reference, {"gameSystem": suggested_system, "standardizedAt": firestore.SERVER_TIMESTAMP})
            # logging.info(f"Committing batch update for {len(docs)} quest cards.")
            # batch.commit()
            # logging.info("Batch update committed successfully.")
            # ------------------------------------------------------
            # Placeholder: Log that batch logic is missing/incomplete if needed
            logging.warning(
                "Batch update logic for questCards is not implemented in this snippet."
            )

    except Exception as e:
        # Log the full exception details, including traceback
        logging.exception(
            f"Error processing system mapping feedback ID {feedback_id}: {e}"
        )
        # Attempt to update the feedback document with error status, if possible
        try:
            if event and event.data and event.data.reference:
                logging.info(f"Attempting to mark feedback {feedback_id} as errored.")
                event.data.reference.update(
                    {
                        "status": "error",
                        "processedAt": firestore.SERVER_TIMESTAMP,
                        "errorDetails": str(e),
                    }
                )
                logging.info(f"Successfully marked feedback {feedback_id} as errored.")
            else:
                logging.error(
                    "Could not update feedback status: event data or reference missing."
                )
        except Exception as update_error:
            logging.error(
                f"Failed to update feedback {feedback_id} status to error: {update_error}"
            )


# --- New Function: User Deletion Cleanup ---


# Helper function to delete subcollections recursively (adjust batch size as needed)
def delete_collection(coll_ref, batch_size):
    docs = coll_ref.limit(batch_size).stream()
    deleted = 0

    while True:
        batch = firestore.client().batch()
        doc_count = 0
        for doc in docs:
            batch.delete(doc.reference)
            doc_count += 1
            deleted += 1

        if doc_count == 0:
            break  # No more documents found

        batch.commit()
        # Get the next batch
        docs = coll_ref.limit(batch_size).stream()

    return deleted


@firestore_fn.on_document_deleted(document="users/{userId}")  # Changed decorator
def on_user_delete(event: firestore_fn.Event) -> None:  # Changed signature
    """Cleans up user data from Firestore when a user document is deleted."""  # Updated docstring
    userId = event.params["userId"]  # Changed to get userId from event.params
    logging.info(
        f"Starting cleanup for deleted user document: users/{userId}"
    )  # Updated log

    try:
        db = firestore.client()

        # The user document users/{userId} is already deleted by the trigger.
        # We need its reference to access subcollections.
        user_doc_ref = db.collection("users").document(userId)
        # user_doc_ref.delete() # This line is removed
        # logging.info(f"Deleted user document: users/{userId}") # This log is removed

        # 1. Delete the 'ownedQuests' subcollection (was 2)
        owned_quests_ref = user_doc_ref.collection("ownedQuests")
        deleted_owned_count = delete_collection(owned_quests_ref, 50)  # Batch size 50
        logging.info(
            f"Deleted {deleted_owned_count} documents from ownedQuests subcollection for user {userId}"  # Use userId
        )

        # 2. Anonymize submitted quest cards (was 3)
        quests_query = db.collection("questCards").where(
            "uploadedBy", "==", userId
        )  # Use userId
        submitted_quests = quests_query.stream()

        anonymized_count = 0
        batch = db.batch()
        batch_count = 0
        max_batch_size = 400  # Firestore batch limit is 500 operations

        for quest in submitted_quests:
            batch.update(quest.reference, {"uploadedBy": None})
            anonymized_count += 1
            batch_count += 1
            if batch_count >= max_batch_size:
                batch.commit()
                logging.info(
                    f"Committed batch of {batch_count} quest anonymizations for user {userId}"  # Use userId
                )
                batch = db.batch()  # Start a new batch
                batch_count = 0

        # Commit any remaining updates in the last batch
        if batch_count > 0:
            batch.commit()
            logging.info(
                f"Committed final batch of {batch_count} quest anonymizations for user {userId}"  # Use userId
            )

        logging.info(
            f"Anonymized {anonymized_count} quest cards submitted by user {userId}"  # Use userId
        )
        logging.info(
            f"Successfully completed cleanup for deleted user document: users/{userId}"
        )  # Updated log

    except Exception as e:
        logging.error(
            f"Error during cleanup for user document users/{userId}: {e}"
        )  # Updated log
        # Depending on the error, you might want to add retry logic or specific handling
        # For now, just log the error.


@scheduler_fn.on_schedule(
    schedule="0 14,23 * * *",  # Runs at 14:00 UTC (10 AM ET) and 23:00 UTC (7 PM ET)
    memory=options.MemoryOption.MB_512,  # Corrected memory allocation
)
def select_quest_and_post_to_bluesky(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Selects a random public quest card from Firestore and prepares it for posting.
    This function will be triggered twice a day.
    """
    db = firestore.client()
    quests_ref = db.collection("questCards")  # Corrected collection name

    # Eligibility criteria
    query = quests_ref.where("isPublic", "==", True)
    logging.info("Querying for public quest cards...")

    eligible_quests = []
    processed_count = 0
    for doc in query.stream():
        processed_count += 1
        quest_data = doc.to_dict()
        quest_data["id"] = doc.id  # Ensure 'id' is in quest_data for the deep link
        logging.info(f"Processing quest document ID: {doc.id}")

        # Log the presence of each required field
        has_system = bool(quest_data.get("gameSystem"))
        has_standardized_game_system = bool(quest_data.get("standardizedGameSystem"))
        has_title = bool(quest_data.get("title"))
        has_product_title = bool(quest_data.get("productTitle"))
        has_summary = bool(quest_data.get("summary"))
        has_genre = bool(quest_data.get("genre"))

        logging.info(
            f"Quest ID: {doc.id} - Fields check: system({has_system}), standardizedGameSystem({has_standardized_game_system}), title({has_title}), productTitle({has_product_title}), summary({has_summary}), genre({has_genre})"
        )
        logging.debug(f"Quest ID: {doc.id} - Full data: {quest_data}")

        # Check for essential fields required for posting
        if (
            quest_data.get("gameSystem")  # Check for existence and non-empty
            and quest_data.get("standardizedGameSystem")
            and quest_data.get("title")
            and quest_data.get("productTitle")
            and quest_data.get("summary")
            and quest_data.get("genre")
        ):
            logging.info(f"Quest ID: {doc.id} is eligible.")
            eligible_quests.append(quest_data)
        else:
            logging.warning(
                f"Quest ID: {doc.id} is NOT eligible due to missing fields."
            )

    logging.info(f"Total public quests processed: {processed_count}")
    if not eligible_quests:
        logging.error(
            "No eligible quests found for posting after checking all processed public quests."
        )
        return

    selected_quest = random.choice(eligible_quests)
    logging.info(
        f"Selected quest for posting: {selected_quest.get('title')} (ID: {selected_quest.get('id')})"
    )

    generated_content = generate_post_content(selected_quest)

    logging.info(
        f"Quest selected: {selected_quest.get('title')}"
    )  # console log for quick check
    logging.info(f"Generated content: {generated_content}")  # console log

    try:
        post_to_bluesky(generated_content)
    except Exception as e:
        logging.error(
            f"Error posting to Bluesky for quest ID {selected_quest.get('id')}: {e}"
        )
        # TODO: Implement email notification to admin on error


def access_secret_version(
    project_id: str, secret_id: str, version_id: str = "latest"
) -> str | None:
    """
    Accesses a secret version from Google Cloud Secret Manager.

    Args:
        project_id: The Google Cloud project ID.
        secret_id: The ID of the secret.
        version_id: The version of the secret (defaults to "latest").

    Returns:
        The secret value as a string, or None if an error occurs.
    """
    try:
        client = secretmanager.SecretManagerServiceClient()
        secret_name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
        response = client.access_secret_version(name=secret_name)
        return response.payload.data.decode("UTF-8")
    except Exception as e:
        logging.error(
            f"Error accessing secret {secret_id} (version {version_id}) in project {project_id}: {e}"
        )
        # Depending on requirements, you might want to raise the exception
        # or handle it more gracefully (e.g., return a specific error indicator).
        return None


@https_fn.on_call()
def get_google_search_config(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """
    Fetches Google API Key and Search Engine ID from Google Cloud Secret Manager.
    """
    project_id = "766749273273"  # Your Google Cloud Project ID
    google_api_key_secret_id = "GOOGLE_API_KEY"
    google_search_engine_id_secret_id = "GOOGLE_SEARCH_ENGINE_ID"

    try:
        api_key = access_secret_version(project_id, google_api_key_secret_id)
        search_engine_id = access_secret_version(
            project_id, google_search_engine_id_secret_id
        )

        if not api_key:
            logging.error(
                f"Secret {google_api_key_secret_id} not found in project {project_id}."
            )
            # Return an error or handle as appropriate for your application
            # For callable functions, you can raise an HttpsError
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message=f"Google API Key secret ({google_api_key_secret_id}) not found.",
            )

        if not search_engine_id:
            logging.error(
                f"Secret {google_search_engine_id_secret_id} not found in project {project_id}."
            )
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message=f"Google Search Engine ID secret ({google_search_engine_id_secret_id}) not found.",
            )

        return {"apiKey": api_key, "searchEngineId": search_engine_id}

    except https_fn.HttpsError as e:
        # Re-raise HttpsError to be properly handled by the client
        raise e
    except Exception as e:
        logging.error(f"Error fetching Google search config: {e}")
        # For other types of errors, wrap them in an HttpsError
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An internal error occurred while fetching Google search configuration.",
            details=str(e),
        )


def get_gemini_api_key() -> str | None:
    """Fetches the Gemini API key from Google Cloud Secret Manager."""
    project_id = "766749273273"  # Your Google Cloud Project ID
    gemini_api_key_secret_id = (
        "gemini_api_key"  # Ensure this secret exists in Secret Manager
    )

    api_key = access_secret_version(project_id, gemini_api_key_secret_id)
    if not api_key:
        logging.error(
            f"Gemini API Key secret ({gemini_api_key_secret_id}) not found in project {project_id}."
        )
    return api_key


def get_bluesky_credentials() -> dict:
    """Fetches Bluesky credentials using the utility function."""
    project_id = "766749273273"  # Your Google Cloud Project ID
    bluesky_handle_secret_id = "bluesky_handle"
    bluesky_password_secret_id = "bluesky_password"

    bluesky_handle = access_secret_version(project_id, bluesky_handle_secret_id)
    bluesky_password = access_secret_version(project_id, bluesky_password_secret_id)

    if not bluesky_handle or not bluesky_password:
        logging.error("Bluesky handle or password not found in Secret Manager.")
        raise ValueError(
            "Bluesky credentials not configured correctly in Google Cloud Secret Manager."
        )

    return {"handle": bluesky_handle, "password": bluesky_password}


def post_to_bluesky(content: dict):
    """Posts the given content to Bluesky using TextBuilder for rich text."""
    credentials = get_bluesky_credentials()
    client = Client()

    # Extract components from the content dictionary
    text_segments = content.get("text_segments", [])
    hashtag_terms = content.get("hashtag_terms", [])
    link_url = content.get("link")
    quest_title_for_embed = content.get("quest_title", "View Quest")
    # For logging purposes, join text segments for a readable version of the post text
    # This won't be the exact text sent, as TextBuilder handles spacing and facets.
    log_text_preview = " ".join(text_segments)

    try:
        profile = client.login(credentials["handle"], credentials["password"])
        logging.info(f"Successfully logged in to Bluesky as {profile.handle}")

        text_builder = client_utils.TextBuilder()
        first_segment = True
        for segment in text_segments:
            if not first_segment:
                text_builder.text(" ")  # Add space between segments
            text_builder.text(segment)
            first_segment = False

        # Add hashtags
        for term in hashtag_terms:
            if term:  # Ensure term is not empty
                text_builder.text(" ").tag(
                    term, term
                )  # Adds a space before the hashtag text and then the tag itself

        # Add the link at the end of the text part if it exists
        # The visual card embed is separate
        if link_url:
            text_builder.text(" ").link(link_url, link_url)

        # Prepare the embed card for the link
        embed_payload = None
        if link_url:
            embed_external = models.AppBskyEmbedExternal.Main(
                external=models.AppBskyEmbedExternal.External(
                    uri=link_url,
                    title=quest_title_for_embed,
                    description="Check out this quest on Questable!",  # Generic description for the card
                )
            )
            embed_payload = embed_external

        # Build post record
        # Note: Bluesky has a 300 grapheme limit for the post text.
        # TextBuilder does not automatically truncate. We need to be mindful of the total length.
        # For simplicity, we are currently relying on the prompt to Gemini and content assembly
        # to keep it within limits. More robust truncation would be needed for longer content.
        final_text = text_builder.build_text()
        final_facets = text_builder.build_facets()

        if len(final_text) > 300:
            logging.warning(
                f"Bluesky post text exceeds 300 chars ({len(final_text)}). Truncating text and clearing facets."
            )
            # Truncate text to fit, leaving space for "..."
            max_len_for_text = 297
            final_text = final_text[:max_len_for_text] + "..."
            final_facets = []  # Clear facets as their byte offsets would be incorrect

        post_record_data = models.AppBskyFeedPost.Record(
            text=final_text,
            facets=final_facets,
            created_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        )

        if embed_payload:
            post_record_data.embed = embed_payload

        post_record = models.ComAtprotoRepoCreateRecord.Data(
            repo=profile.did, collection="app.bsky.feed.post", record=post_record_data
        )
        response = client.com.atproto.repo.create_record(data=post_record)

        logging.info(f"Successfully posted to Bluesky: {response.uri}")
        db = firestore.client()
        log_ref = db.collection("social_post_logs").document()
        log_ref.set(
            {
                "platform": "Bluesky",
                "quest_title": quest_title_for_embed,
                "post_text_preview": log_text_preview,  # Log the preview
                "post_uri": response.uri,
                "status": "success",
                "timestamp": firestore.SERVER_TIMESTAMP,
            }
        )

    except Exception as e:
        logging.error(f"Failed to post to Bluesky: {e}")
        db = firestore.client()
        log_ref = db.collection("social_post_logs").document()
        log_ref.set(
            {
                "platform": "Bluesky",
                "quest_title": quest_title_for_embed,
                "post_text_preview": log_text_preview,  # Log the preview
                "status": "error",
                "error_message": str(e),
                "timestamp": firestore.SERVER_TIMESTAMP,
            }
        )
        raise  # Re-raise the exception


def generate_ai_text(genre: str, summary: str, quest_title: str) -> str:
    """Generates a short, compelling AI snippet for a quest using Gemini."""
    try:
        api_key = get_gemini_api_key()
        if not api_key:
            logging.error("Gemini API key not available. Skipping AI text generation.")
            return ""

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.0-flash")

        prompt = f"""Generate a very short and exciting social media teaser (around 15-25 words, and strictly under 160 characters) for a tabletop roleplaying quest titled '{quest_title}'.
The quest is in the '{genre}' genre.
Summary: '{summary}'.
The teaser should be engaging and make people curious to check out the quest.
Do not use hashtags in your response. Do not include the quest title or genre in your response unless it flows very naturally as part of the teaser.
Focus on creating a hook or a sense of mystery/adventure.
Example tone for a fantasy quest: "Ancient secrets whisper from forgotten ruins. Dare you uncover them?"
Example tone for a sci-fi quest: "Cosmic anomalies detected. Your mission, should you choose to accept it..."
Example tone for a horror quest: "A chilling presence lurks in the old manor. What terrors await inside?"
"""

        logging.info(f"Generating AI text for quest: {quest_title} (Genre: {genre})")
        response = model.generate_content(prompt)

        if response.parts:
            ai_text = response.text.strip()
            # Additional check for safety, though the prompt requests short text
            if len(ai_text) > 160:
                logging.warning(
                    f"Generated AI text for '{quest_title}' is too long ({len(ai_text)} chars), truncating: {ai_text}"
                )
                ai_text = ai_text[:157] + "..."
            logging.info(f"Successfully generated AI text: {ai_text}")
            return ai_text
        else:
            logging.warning(
                f"Gemini response for '{quest_title}' contained no parts. Prompt: {prompt}"
            )
            if hasattr(response, "prompt_feedback") and response.prompt_feedback:
                logging.warning(f"Gemini prompt feedback: {response.prompt_feedback}")
            return ""

    except Exception as e:
        logging.error(f"Error generating AI text for '{quest_title}': {e}")
        return ""


def generate_post_content(quest_data: dict) -> dict:
    """
    Generates components for the social media post based on the quest data.
    """
    # Extract data from quest_data
    raw_quest_name = quest_data.get("title")
    quest_name = (
        raw_quest_name.title() if isinstance(raw_quest_name, str) else raw_quest_name
    )
    product_name = quest_data.get("productTitle")
    game_system = quest_data.get("standardizedGameSystem")
    genre = quest_data.get("genre")
    summary = quest_data.get("summary", "")  # Get summary for AI
    quest_id = quest_data.get("id")

    # Base hashtag terms (without '#')
    hashtag_terms = []
    if game_system:
        hashtag_terms.append(game_system.replace(" ", ""))
    if genre:
        hashtag_terms.append(genre.replace(" ", ""))
    hashtag_terms.extend(["Questable", "ttrpg"])
    # Ensure no empty strings if game_system or genre were empty
    hashtag_terms = [term for term in hashtag_terms if term]

    # Template-based post text components
    post_text_template = (
        f"New Quest: {quest_name}! From {product_name} ({game_system})."
    )

    deep_link = f"https://questable.app/#/quests/{quest_id}"

    call_to_actions = [
        "Explore this adventure!",
        "Discover your next quest!",
        "Embark on this journey!",
        "What choices will you make?",
        "Your story awaits!",
    ]
    call_to_action = random.choice(call_to_actions)

    # AI Text Generation
    ai_snippet = ""
    if genre and summary and quest_name:  # Only generate if key fields are present
        ai_snippet = generate_ai_text(genre, summary, quest_name)
    else:
        logging.warning(
            f"Skipping AI text generation for quest ID {quest_id} due to missing genre, summary, or title."
        )

    # Assemble text segments
    text_segments = [post_text_template]
    if ai_snippet:
        text_segments.append(ai_snippet)
    else:
        # Fallback if AI snippet is not generated, include genre explicitly if not in template already
        if genre and genre not in post_text_template:
            text_segments.append(f"Genre: {genre}.")

    text_segments.append(call_to_action)

    return {
        "text_segments": [
            segment for segment in text_segments if segment
        ],  # Filter out any None or empty segments
        "hashtag_terms": hashtag_terms,
        "quest_title": quest_name,  # Already capitalized
        "link": deep_link,
    }
