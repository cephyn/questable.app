"""
User Management functions for the quest cards Firebase Functions.
Handles user deletion and cleanup operations.
"""

import logging
from firebase_functions import firestore_fn, options
from firebase_admin import firestore


def delete_collection(coll_ref, batch_size):
    """Helper function to delete subcollections recursively (adjust batch size as needed)"""
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


@firestore_fn.on_document_deleted(
    document="users/{userId}",
    memory=options.MemoryOption.MB_512,
)
def on_user_delete(event: firestore_fn.Event) -> None:
    """Cleans up user data from Firestore when a user document is deleted."""
    userId = event.params["userId"]
    logging.info(
        f"Starting cleanup for deleted user document: users/{userId}"
    )

    try:
        db = firestore.client()

        # The user document users/{userId} is already deleted by the trigger.
        # We need its reference to access subcollections.
        user_doc_ref = db.collection("users").document(userId)

        # 1. Delete the 'ownedQuests' subcollection
        owned_quests_ref = user_doc_ref.collection("ownedQuests")
        deleted_owned_count = delete_collection(owned_quests_ref, 50)  # Batch size 50
        logging.info(
            f"Deleted {deleted_owned_count} documents from ownedQuests subcollection for user {userId}"
        )

        # 2. Anonymize submitted quest cards
        quests_query = db.collection("questCards").where(
            "uploadedBy", "==", userId
        )
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
                    f"Committed batch of {batch_count} quest anonymizations for user {userId}"
                )
                batch = db.batch()  # Start a new batch
                batch_count = 0

        # Commit any remaining updates in the last batch
        if batch_count > 0:
            batch.commit()
            logging.info(
                f"Committed final batch of {batch_count} quest anonymizations for user {userId}"
            )

        logging.info(
            f"Anonymized {anonymized_count} quest cards submitted by user {userId}"
        )
        logging.info(
            f"Successfully completed cleanup for deleted user document: users/{userId}"
        )

    except Exception as e:
        logging.error(
            f"Error during cleanup for user document users/{userId}: {e}"
        )
        # Depending on the error, you might want to add retry logic or specific handling
        # For now, just log the error.
