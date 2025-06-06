"""
Game System Standardization functions for the quest cards Firebase Functions.
Handles standardization, mapping, and cleanup of game system names.
"""

import logging
import datetime
import re
from firebase_functions import firestore_fn, https_fn, scheduler_fn, options
from firebase_admin import firestore


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


def calculate_standardization_stats():
    """Calculates and returns current statistics for game system standardization."""
    try:
        db = firestore.client()
        # Get counts for different statuses
        standardized_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "completed")
            .count()
            .get()[0][0]
            .value
        )

        pending_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "pending")
            .count()
            .get()[0][0]
            .value
        )

        failed_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "failed")
            .count()
            .get()[0][0]
            .value
        )

        needs_review_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "needs_review")
            .count()
            .get()[0][0]
            .value
        )

        no_match_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "no_match")
            .count()
            .get()[0][0]
            .value
        )

        # Add count for 'flagged' status if it exists
        flagged_count = (
            db.collection("questCards")
            .where("systemMigrationStatus", "==", "flagged")
            .count()
            .get()[0][0]
            .value
        )

        total_count = (
            db.collection("questCards").count().get()[0][0].value
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
            "flagged": flagged_count,
            "unprocessed": unprocessed_count,
            "total": total_count,
            "coverage": (standardized_count / total_count) if total_count > 0 else 0,
        }

    except Exception as e:
        logging.error(f"Error calculating standardization stats: {e}")
        # Return error within the dictionary for consistency
        return {"error": str(e)}


# Firebase Function Triggers and Handlers

@firestore_fn.on_document_created(
    document="questCards/{questId}",
    memory=options.MemoryOption.GB_1,
)
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


@firestore_fn.on_document_updated(
    document="questCards/{questId}",
    memory=options.MemoryOption.MB_512,
)
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


@scheduler_fn.on_schedule(
    schedule="0 0 * * *",
    memory=options.MemoryOption.MB_512,
)
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
        stats = calculate_standardization_stats()

        # Check if stats calculation resulted in an error before proceeding
        if "error" in stats:
            # Log the error from stats calculation but don't necessarily stop the whole process
            # The main error handling block below will catch larger issues
            logging.error(f"Error generating stats for report: {stats['error']}")

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


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
)
def get_standardization_stats(req: https_fn.CallableRequest = None) -> dict:
    """Get current statistics for game system standardization (calls helper)."""
    # Simply call the internal helper function
    return calculate_standardization_stats()


@https_fn.on_call(
    memory=options.MemoryOption.MB_512,
)
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


@firestore_fn.on_document_created(
    document="system_mapping_feedback/{feedbackId}",
    memory=options.MemoryOption.MB_512,
)
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
            # Batch update logic placeholder
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
