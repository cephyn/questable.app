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
import requests # Added for the proxy function
# from markitdown import MarkItDown # Importing MarkItDown for PDF to Markdown conversion # MOVED TO pdf_to_md

# Import the similarity calculation function
# import similarity_calculator # Assuming similarity_calculator.py is in the same directory # MOVED
# from similarity_calculator import calculate_similarity_for_quest # Added for the new trigger # MOVED

# Import modularized functions
from utils import get_secret, log_social_post_attempt
from game_system_standardization import (
    standardize_new_quest_card,
    handle_quest_card_update,
    scheduled_game_system_cleanup,
    get_standardization_stats,
    report_incorrect_mapping,
    process_system_mapping_feedback
)
from user_management import on_user_delete
from social_media import select_quest_and_post_to_social_media

# Set root logger level to INFO for better visibility in Cloud Run if default is higher
logging.getLogger().setLevel(logging.INFO)

# Configure the root logger to handle INFO and higher severity messages
# logging.basicConfig(level=logging.INFO)
# If you also need DEBUG messages, use:
logging.basicConfig(level=logging.DEBUG)

initialize_app()

@firestore_fn.on_document_created(document="questCards/{questId}", memory=options.MemoryOption.MB_512)
def on_new_quest_card_created(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    """
    Triggered when a new quest card is created.
    Calculates and stores similarity scores for the new quest.
    """
    from similarity_calculator import calculate_similarity_for_quest # LAZY IMPORT
    quest_id = event.params["questId"]
    logging.info(f"New quest card created: {quest_id}. Calculating similarity scores.")
    try:
        calculate_similarity_for_quest(quest_id)
        logging.info(f"Successfully calculated and stored similarity for quest {quest_id}.")
    except Exception as e:
        logging.error(f"Error calculating similarity for quest {quest_id}: {e}")
        # Optionally, re-raise the exception if you want the function to be marked as failed
        # raise e

# @https_fn.on_call(
#     memory=options.MemoryOption.GB_2,
# )
# def pdf_to_md(req: https_fn.CallableRequest) -> any:
#     from markitdown import MarkItDown # LAZY IMPORT
#     url = req.data["url"]
#     md = MarkItDown(enable_plugins=False)  # Set to True to enable plugins
#     result = md.convert(url)

#     return result.text_content

@https_fn.on_call(memory=options.MemoryOption.MB_512)
def get_google_search_config(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """
    Fetches Google API Key and Search Engine ID from Google Cloud Secret Manager.
    """
    project_id = "766749273273"  # Your Google Cloud Project ID
    google_api_key_secret_id = "GOOGLE_API_KEY"
    google_search_engine_id_secret_id = "GOOGLE_SEARCH_ENGINE_ID"

    try:
        api_key = get_secret(google_api_key_secret_id, project_id)
        search_engine_id = get_secret(google_search_engine_id_secret_id, project_id
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


@https_fn.on_call(memory=options.MemoryOption.MB_512) # Added new proxy function
def proxy_fetch_url(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """
    Acts as a proxy to fetch content from a URL to bypass CORS issues.
    Expects 'targetUrl' in the request data.
    """
    target_url = req.data.get("targetUrl")

    if not target_url:
        logging.error("Proxy request missing 'targetUrl'")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="The function must be called with a 'targetUrl' argument."
        )

    logging.info(f"Proxying request to: {target_url}")

    try:
        # Using a session object can be beneficial for performance if multiple requests are made to the same host
        with requests.Session() as session:
            # It's good practice to set a User-Agent that's representative of your app/service
            headers = {
                "User-Agent": "QuestableAppProxy/1.0 (+https://questable.app)"
            }
            # Make a GET request. For HEAD requests, use session.head()
            # The original error was for a HEAD request, but for validation, GET might be more common.
            # If only headers are needed, change to session.head() and adjust response handling.
            response = session.get(target_url, headers=headers, timeout=20) # 20 seconds timeout

        # Raise an exception for bad status codes (4xx or 5xx)
        response.raise_for_status()

        # Return relevant parts of the response
        # Be mindful of not returning excessively large responses if only a status or specific headers are needed.
        return {
            "statusCode": response.status_code,
            "headers": dict(response.headers),
            # Omitting or truncating the content field to reduce payload size
            "content": response.text[:1000] if len(response.text) > 1000 else response.text
        }

    except requests.exceptions.Timeout as e:
        logging.error(f"Timeout error fetching {target_url}: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.DEADLINE_EXCEEDED,
            message=f"The request to {target_url} timed out.",
            details=str(e)
        )
    except requests.exceptions.RequestException as e:
        logging.error(f"Error fetching {target_url}: {e}")
        # Include status code in the error if available (e.g., for 403 Forbidden)
        status_code = e.response.status_code if e.response is not None else "N/A"
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAVAILABLE, # Or more specific based on e.response.status_code
            message=f"Failed to fetch content from {target_url}. Status: {status_code}",
            details=str(e)
        )
    except Exception as e:
        logging.error(f"Unexpected error in proxy_fetch_url for {target_url}: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An internal error occurred while proxying the request.",
            details=str(e)
        )

# Make sure to deploy this function after adding it.
# firebase deploy --only functions

