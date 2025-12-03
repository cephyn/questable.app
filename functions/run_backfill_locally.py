"""Utility to run indexer.backfill_all locally against configured Firestore.

This is useful when you want to run the backfill from a developer machine
instead of invoking the deployed callable. It uses Application Default
Credentials, so ensure you've run `gcloud auth application-default login`
or have a service account configured.
"""

import logging
from firebase_admin import initialize_app, firestore

from indexer import backfill_all


def main():
    logging.basicConfig(level=logging.INFO)
    initialize_app()
    db = firestore.client()

    # Create a log entry similar to deployed function behavior
    run_doc = None
    try:
        run_doc = db.collection("backfill_runs").document()
        run_id = run_doc.id
        run_doc.set(
            {
                "type": "search_index",
                "status": "running",
                "initiatedBy": None,
                "startTime": firestore.SERVER_TIMESTAMP,
            }
        )
    except Exception as e:
        logging.warning(f"Could not create run log: {e}")

    logging.info("Starting backfill of questSearchIndex...")
    processed = backfill_all(db)

    try:
        if run_doc is not None:
            db.collection("backfill_runs").document(run_id).update(
                {
                    "status": "success",
                    "processed": processed,
                    "endTime": firestore.SERVER_TIMESTAMP,
                }
            )
    except Exception as e:
        logging.warning(f"Could not update run log: {e}")

    logging.info(f"Backfill processed {processed} quest(s)")
    print(f"Backfill processed {processed} quest(s)")


if __name__ == "__main__":
    main()
