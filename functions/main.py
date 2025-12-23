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
import requests  # Added for the proxy function
import os
import tempfile
import json

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
    process_system_mapping_feedback,
)
from user_management import on_user_delete
from social_media import select_quest_and_post_to_social_media
from indexer import index_quest, delete_index, backfill_all
import time
from indexer import _tokenize

# Set root logger level to INFO for better visibility in Cloud Run if default is higher
logging.getLogger().setLevel(logging.INFO)

# Configure the root logger to handle INFO and higher severity messages
# logging.basicConfig(level=logging.INFO)
# If you also need DEBUG messages, use:
logging.basicConfig(level=logging.DEBUG)

initialize_app()


PDF_TO_MD_JOBS_COLLECTION = "pdfToMdJobs"
PDF_TO_MD_INPUT_FILENAME = "input.pdf"
PDF_TO_MD_OUTPUT_FILENAME = "output.md"


def _get_change_before_after(change) -> tuple[object | None, object | None]:
    """Return (before, after) snapshots from a Firestore Change.

    The firebase_functions Python SDK has used different attribute names across
    versions. This helper supports both the modern `before`/`after` and the
    older `old_value`/`value` naming.
    """
    if change is None:
        return (None, None)

    before = None
    after = None

    for attr in ("before", "old_value", "oldValue"):
        if hasattr(change, attr):
            before = getattr(change, attr)
            break

    for attr in ("after", "value", "new_value", "newValue"):
        if hasattr(change, attr):
            after = getattr(change, attr)
            break

    return (before, after)


def _get_default_storage_bucket_name() -> str | None:
    """Returns the Firebase Storage bucket name from FIREBASE_CONFIG if present."""
    try:
        # FIREBASE_CONFIG is a JSON string when present.
        import json

        cfg = os.environ.get("FIREBASE_CONFIG")
        if not cfg:
            return None
        parsed = json.loads(cfg)
        return parsed.get("storageBucket")
    except Exception:
        return None


def _job_paths(job_id: str) -> tuple[str, str]:
    """Returns (input_path, output_path) for a job inside the default bucket."""
    base = f"pdf_to_md_jobs/{job_id}"
    return (f"{base}/{PDF_TO_MD_INPUT_FILENAME}", f"{base}/{PDF_TO_MD_OUTPUT_FILENAME}")


@firestore_fn.on_document_created(
    document="questCards/{questId}", memory=options.MemoryOption.MB_512
)
def on_new_quest_card_created(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    """
    Triggered when a new quest card is created.
    Calculates and stores similarity scores for the new quest.
    """
    from similarity_calculator import calculate_similarity_for_quest  # LAZY IMPORT

    quest_id = event.params["questId"]
    logging.info(f"New quest card created: {quest_id}. Calculating similarity scores.")
    try:
        calculate_similarity_for_quest(quest_id)
        logging.info(
            f"Successfully calculated and stored similarity for quest {quest_id}."
        )
    except Exception as e:
        logging.error(f"Error calculating similarity for quest {quest_id}: {e}")
        # Optionally, re-raise the exception if you want the function to be marked as failed
        # raise e


@https_fn.on_call(memory=options.MemoryOption.MB_256)
def create_pdf_to_md_job(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """Creates a PDF→Markdown conversion job.

    Returns { jobId, uploadPath } where the client should upload a PDF to
    gs://<bucket>/<uploadPath> (via Firebase Storage SDK).
    """
    try:
        # Require auth so we can lock down Firestore reads to the job owner.
        if not hasattr(req, "auth") or req.auth is None:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Authentication required.",
            )

        bucket = _get_default_storage_bucket_name()
        if not bucket:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                message="Firebase Storage bucket is not configured.",
            )

        data = req.data or {}
        original_filename = str(data.get("originalFilename") or "").strip()
        run_id = str(data.get("runId") or "").strip()

        db = firestore.client()
        doc_ref = db.collection(PDF_TO_MD_JOBS_COLLECTION).document()
        job_id = doc_ref.id
        input_path, output_path = _job_paths(job_id)

        initiated_by = req.auth.uid

        doc_ref.set(
            {
                "status": "created",
                "bucket": bucket,
                "inputPath": input_path,
                "outputPath": output_path,
                "originalFilename": original_filename,
                "runId": run_id,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "createdBy": initiated_by,
            }
        )

        logging.info(
            "PDF_TO_MD job created jobId=%s runId=%s uid=%s inputPath=%s",
            job_id,
            run_id,
            initiated_by,
            input_path,
        )

        return {"jobId": job_id, "uploadPath": input_path, "bucket": bucket}
    except https_fn.HttpsError:
        raise
    except Exception as e:
        logging.error(f"create_pdf_to_md_job error: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Failed to create PDF to Markdown job.",
            details=str(e),
        )


@https_fn.on_call(memory=options.MemoryOption.MB_256)
def start_pdf_to_md_job(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """Marks a previously created job as queued, triggering processing."""
    try:
        if not hasattr(req, "auth") or req.auth is None:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                message="Authentication required.",
            )

        data = req.data or {}
        job_id = str(data.get("jobId") or "").strip()
        if not job_id:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message="Missing required field: jobId",
            )

        db = firestore.client()
        doc_ref = db.collection(PDF_TO_MD_JOBS_COLLECTION).document(job_id)
        snap = doc_ref.get()
        if not snap.exists:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.NOT_FOUND,
                message="Job not found.",
            )

        # Only the creator may start their job.
        job_data = snap.to_dict() or {}
        created_by = str(job_data.get("createdBy") or "")
        run_id = str(job_data.get("runId") or "")
        if not created_by or created_by != req.auth.uid:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                message="Not allowed to start this job.",
            )

        doc_ref.update(
            {
                "status": "queued",
                "queuedAt": firestore.SERVER_TIMESTAMP,
            }
        )

        logging.info(
            "PDF_TO_MD job queued jobId=%s runId=%s uid=%s",
            job_id,
            run_id,
            req.auth.uid,
        )

        return {"jobId": job_id, "status": "queued"}
    except https_fn.HttpsError:
        raise
    except Exception as e:
        logging.error(f"start_pdf_to_md_job error: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Failed to start PDF to Markdown job.",
            details=str(e),
        )


@firestore_fn.on_document_written(
    document=f"{PDF_TO_MD_JOBS_COLLECTION}/{{jobId}}",
    memory=options.MemoryOption.GB_4,
)
def process_pdf_to_md_job(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    """Processes queued PDF→Markdown jobs.

    Triggered by updates to pdfToMdJobs/{jobId}. When status transitions to
    'queued', downloads the uploaded PDF from Cloud Storage, converts to Markdown,
    uploads output markdown, and updates job doc.
    """
    job_id = event.params["jobId"]

    try:
        # Extract before/after snapshots (SDK version compatible)
        old_value, new_value = _get_change_before_after(event.data)

        if new_value is None:
            return

        def _to_dict(v):
            try:
                return v.to_dict() if hasattr(v, "to_dict") else dict(v)
            except Exception:
                try:
                    return dict(v)
                except Exception:
                    return {}

        old_data = _to_dict(old_value) if old_value is not None else {}
        new_data = _to_dict(new_value)

        old_status = str(old_data.get("status") or "")
        new_status = str(new_data.get("status") or "")

        run_id = str(new_data.get("runId") or "")

        # Only run on transition to queued
        if new_status != "queued" or old_status == "queued":
            return

        bucket_name = str(new_data.get("bucket") or "")
        input_path = str(new_data.get("inputPath") or "")
        output_path = str(new_data.get("outputPath") or "")

        if not bucket_name or not input_path or not output_path:
            logging.error(
                "process_pdf_to_md_job missing bucket/path fields jobId=%s runId=%s",
                job_id,
                run_id,
            )
            return

        db = firestore.client()
        doc_ref = db.collection(PDF_TO_MD_JOBS_COLLECTION).document(job_id)
        doc_ref.update(
            {
                "status": "processing",
                "startedAt": firestore.SERVER_TIMESTAMP,
            }
        )

        logging.info(
            "PDF_TO_MD processing started jobId=%s runId=%s inputPath=%s outputPath=%s",
            job_id,
            run_id,
            input_path,
            output_path,
        )

        # Lazy imports to keep cold starts smaller
        from google.cloud import storage  # type: ignore
        from markitdown import MarkItDown  # type: ignore

        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(input_path)

        with tempfile.TemporaryDirectory() as tmpdir:
            local_pdf = os.path.join(tmpdir, "input.pdf")
            local_md = os.path.join(tmpdir, "output.md")

            blob.download_to_filename(local_pdf)

            doc_ref.update({"downloadedAt": firestore.SERVER_TIMESTAMP})

            # Delete the uploaded PDF as soon as we've successfully pulled it into
            # local temp storage to minimize retention of user uploads.
            try:
                blob.delete()
                doc_ref.update({"inputDeletedAt": firestore.SERVER_TIMESTAMP})
            except Exception as e:
                logging.warning(f"Could not delete input PDF for job {job_id}: {e}")

            md = MarkItDown(enable_plugins=False)
            result = md.convert(local_pdf)
            text = getattr(result, "text_content", None)
            if text is None:
                text = str(result)

            doc_ref.update(
                {
                    "convertedAt": firestore.SERVER_TIMESTAMP,
                    "markdownCharCount": len(text),
                }
            )

            # Write output locally then upload
            with open(local_md, "w", encoding="utf-8") as f:
                f.write(text)

            out_blob = bucket.blob(output_path)
            out_blob.content_type = "text/markdown"
            out_blob.upload_from_filename(local_md)

            doc_ref.update({"outputUploadedAt": firestore.SERVER_TIMESTAMP})

        doc_ref.update(
            {
                "status": "done",
                "completedAt": firestore.SERVER_TIMESTAMP,
            }
        )

        logging.info(
            "PDF_TO_MD processing done jobId=%s runId=%s markdownChars=%s",
            job_id,
            run_id,
            len(text),
        )

    except Exception as e:
        logging.exception("process_pdf_to_md_job failed jobId=%s", job_id)
        try:
            firestore.client().collection(PDF_TO_MD_JOBS_COLLECTION).document(job_id).update(
                {
                    "status": "failed",
                    "failedAt": firestore.SERVER_TIMESTAMP,
                    "error": str(e),
                    "errorType": type(e).__name__,
                }
            )
        except Exception:
            logging.warning(f"Could not update failed status for job {job_id}")


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
        search_engine_id = get_secret(google_search_engine_id_secret_id, project_id)

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


@https_fn.on_call(memory=options.MemoryOption.MB_512)  # Added new proxy function
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
            message="The function must be called with a 'targetUrl' argument.",
        )

    logging.info(f"Proxying request to: {target_url}")

    try:
        # Using a session object can be beneficial for performance if multiple requests are made to the same host
        with requests.Session() as session:
            # It's good practice to set a User-Agent that's representative of your app/service
            headers = {"User-Agent": "QuestableAppProxy/1.0 (+https://questable.app)"}
            # Make a GET request. For HEAD requests, use session.head().
            response = session.get(target_url, headers=headers, timeout=20)

        # IMPORTANT: Do NOT raise for non-2xx status codes.
        # Many sites block automated requests (403) and we want the caller to
        # treat that as "not accessible" rather than an internal function error.
        return {
            "statusCode": response.status_code,
            "headers": dict(response.headers),
            # Omitting or truncating the content field to reduce payload size
            "content": (
                response.text[:1000] if len(response.text) > 1000 else response.text
            ),
        }

    except requests.exceptions.Timeout as e:
        logging.error(f"Timeout error fetching {target_url}: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.DEADLINE_EXCEEDED,
            message=f"The request to {target_url} timed out.",
            details=str(e),
        )
    except requests.exceptions.RequestException as e:
        logging.error(f"Error fetching {target_url}: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.UNAVAILABLE,
            message=f"Failed to fetch content from {target_url}.",
            details=str(e),
        )
    except Exception as e:
        logging.error(f"Unexpected error in proxy_fetch_url for {target_url}: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An internal error occurred while proxying the request.",
            details=str(e),
        )


@https_fn.on_call(memory=options.MemoryOption.MB_256)
def report_client_error(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """Callable used by the client to report failures into Cloud Logs.

    This is especially helpful when browser extensions block Firestore/AI
    requests (net::ERR_BLOCKED_BY_CLIENT), which prevents useful server-side
    logs from being generated.
    """
    try:
        data = req.data or {}
        uid = None
        try:
            uid = req.auth.uid if hasattr(req, "auth") and req.auth is not None else None
        except Exception:
            uid = None

        logging.error(
            "CLIENT_ERROR uid=%s runId=%s stage=%s message=%s details=%s",
            uid,
            data.get("runId"),
            data.get("stage"),
            data.get("message"),
            {
                "error": data.get("error"),
                "stack": data.get("stack"),
                "context": data.get("context"),
            },
        )
        return {"ok": True}
    except Exception as e:
        logging.error(f"report_client_error failed: {e}")
        return {"ok": False}


@https_fn.on_call(memory=options.MemoryOption.MB_256)
def report_client_event(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """Callable used by the client to report stage/progress events into Cloud Logs.

    This is intentionally lightweight and best-effort; it should never break
    user flows. Use `report_client_error` for exceptions.
    """
    try:
        data = req.data or {}
        uid = None
        try:
            uid = req.auth.uid if hasattr(req, "auth") and req.auth is not None else None
        except Exception:
            uid = None

        logging.info(
            "CLIENT_EVENT uid=%s runId=%s stage=%s message=%s context=%s",
            uid,
            data.get("runId"),
            data.get("stage"),
            data.get("message"),
            data.get("context"),
        )
        return {"ok": True}
    except Exception as e:
        logging.error(f"report_client_event failed: {e}")
        return {"ok": False}


@https_fn.on_request(memory=options.MemoryOption.MB_256)
def report_client_error_http(req: https_fn.Request) -> https_fn.Response:
    """HTTP endpoint to report client errors when callable Functions aren't available.

    This is primarily used for very-early web startup crashes where Firebase may
    not be initialized yet, so `httpsCallable('report_client_error')` cannot run.

    CORS is enabled for browser requests.
    """
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Max-Age": "3600",
    }

    if req.method == "OPTIONS":
        return https_fn.Response("", status=204, headers=cors_headers)

    if req.method != "POST":
        return https_fn.Response(
            json.dumps({"ok": False, "error": "Method not allowed"}),
            status=405,
            headers={**cors_headers, "Content-Type": "application/json"},
        )

    try:
        # `req` is a Flask request under the hood.
        data = None
        try:
            data = req.get_json(silent=True)
        except Exception:
            data = None
        if not isinstance(data, dict):
            data = {}

        logging.error(
            "CLIENT_ERROR_HTTP runId=%s stage=%s message=%s details=%s",
            data.get("runId"),
            data.get("stage"),
            data.get("message"),
            {
                "error": data.get("error"),
                "stack": data.get("stack"),
                "context": data.get("context"),
            },
        )

        return https_fn.Response(
            json.dumps({"ok": True}),
            status=200,
            headers={**cors_headers, "Content-Type": "application/json"},
        )
    except Exception as e:
        logging.error(f"report_client_error_http failed: {e}")
        return https_fn.Response(
            json.dumps({"ok": False}),
            status=200,
            headers={**cors_headers, "Content-Type": "application/json"},
        )


# Make sure to deploy this function after adding it.
# firebase deploy --only functions


@https_fn.on_call(memory=options.MemoryOption.MB_512)
def search_quests(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """Callable function that performs text+field search across questCards.

    Accepts data: { query: str, filters: dict (optional), page: int, pageSize: int }
    Returns: { total, page, pageSize, hits: [ {id,title,snippet,score} ] }
    """
    try:
        data = req.data or {}
        query_text = data.get("query", "")
        filters = data.get("filters", {})
        page = int(data.get("page", 1))
        page_size = int(data.get("pageSize", 10))

        # Lazy import of the core search logic
        from search import search_quests_core

        # Initialize Firestore client (app already initialized at module level)
        db = firestore.client()

        # Use a candidate-based approach via questSearchIndex to avoid streaming
        # every quest on each search. Also use a small in-memory TTL cache to
        # reduce repeated work when the same query is being executed quickly.

        # Simple in-function cache (helps warm instances keep recent results)
        # key -> {expires_at: float, hits: [..], total: int}
        global _search_cache
        try:
            _search_cache
        except NameError:
            _search_cache = {}

        # Canonicalize filters into a stable string for cache key
        def _filters_key(flt):
            if not flt:
                return ""
            parts = []
            for k in sorted(flt.keys()):
                v = flt[k]
                if isinstance(v, (list, tuple)):
                    parts.append(f"{k}:{','.join(map(str, v))}")
                else:
                    parts.append(f"{k}:{v}")
            return "|".join(parts)

        cache_key = (query_text or "").strip().lower() + "|" + _filters_key(filters)
        CACHE_TTL = 30
        candidate_limit = 200

        now = time.time()
        cached = _search_cache.get(cache_key)
        if cached and cached.get("expires_at", 0) > now:
            # We have full cached hits; slice for pagination and return
            all_hits = cached["hits"]
            total = cached.get("total", len(all_hits))
            start = (page - 1) * page_size
            end = start + page_size
            return {
                "total": total,
                "page": page,
                "pageSize": page_size,
                "hits": all_hits[start:end],
            }

        # Tokenize the query for candidate selection using indexer._tokenize
        tokens = list(_tokenize(query_text or ""))

        candidate_ids = []
        if tokens:
            # Firestore supports up to 10 elements for array-contains-any
            tokens_for_query = tokens[:10]
            try:
                idx_coll = db.collection("questSearchIndex")
                q = idx_coll.where(
                    "tokens", "array_contains_any", tokens_for_query
                ).limit(candidate_limit)
                for doc in q.stream():
                    candidate_ids.append(doc.id)
            except Exception:
                # In case index queries fail, fall back to scanning the full quests set
                candidate_ids = []

        quests = []

        # Fetch full quest documents for found candidate IDs (preserves fields used in scoring)
        if candidate_ids:
            for cid in candidate_ids:
                try:
                    d = db.collection("questCards").document(cid).get()
                    if d.exists:
                        qd = d.to_dict() or {}
                        qd["id"] = d.id
                        quests.append(qd)
                except Exception:
                    continue

        # If we didn't find any candidates (or tokenization produced nothing),
        # fall back to scanning quests (safe but slower for small datasets)
        if not quests:
            docs = db.collection("questCards").stream()
            for d in docs:
                q = d.to_dict() or {}
                q["id"] = d.id
                quests.append(q)

        # Run the existing core search over this smaller candidate set.
        # Request a large page size to compute full sorted results, then cache
        # the hits so pagination can be served from cache.
        unpaginated = search_quests_core(
            query_text, filters, 1, max(len(quests), 1000), quests
        )
        all_hits = unpaginated.get("hits", [])

        # Cache the full result for short TTL
        _search_cache[cache_key] = {
            "expires_at": now + CACHE_TTL,
            "hits": all_hits,
            "total": unpaginated.get("total", len(all_hits)),
        }

        # Slice for the requested page
        start = (page - 1) * page_size
        end = start + page_size
        page_hits = all_hits[start:end]

        result = {
            "total": len(all_hits),
            "page": page,
            "pageSize": page_size,
            "hits": page_hits,
        }
        return result

    except https_fn.HttpsError as e:
        raise e
    except Exception as e:
        logging.error(f"search_quests error: {e}")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="An error occurred while performing search.",
            details=str(e),
        )


# Firestore trigger to maintain the questSearchIndex entry when a quest is written (create/update/delete)
@firestore_fn.on_document_written(
    document="questCards/{questId}", memory=options.MemoryOption.MB_512
)
def maintain_search_index(event: firestore_fn.Event[firestore_fn.Change]) -> None:
    quest_id = event.params["questId"]
    try:
        before, after = _get_change_before_after(event.data)

        # If document deleted
        if before is not None and after is None:
            # deleted
            delete_index(firestore.client(), quest_id)
            logging.info(f"Deleted search index for {quest_id}")
            return

        # For create or update, build index
        if after is not None:
            # `after` is a firestore.DocumentSnapshot-like object
            new_data = after
            # Convert to dict safely
            try:
                # If the event object exposes to_dict(), use it
                qdata = (
                    new_data.to_dict()
                    if hasattr(new_data, "to_dict")
                    else dict(new_data)
                )
            except Exception:
                # Fallback: use raw map
                qdata = dict(new_data)

            index_quest(firestore.client(), quest_id, qdata)
            logging.info(f"Indexed search for {quest_id}")

    except Exception as e:
        logging.error(f"Error maintaining search index for {quest_id}: {e}")


@https_fn.on_call(memory=options.MemoryOption.MB_512)
def backfill_search_index(req: https_fn.CallableRequest) -> https_fn.Response | dict:
    """Callable to backfill search index for all questCards. Returns count processed."""
    try:
        db = firestore.client()

        # Create a backfill_run log entry
        try:
            run_doc = db.collection("backfill_runs").document()
            run_id = run_doc.id
            initiated_by = None
            try:
                initiated_by = (
                    req.auth.uid
                    if hasattr(req, "auth") and req.auth is not None
                    else None
                )
            except Exception:
                initiated_by = None

            run_doc.set(
                {
                    "type": "search_index",
                    "status": "running",
                    "initiatedBy": initiated_by,
                    "startTime": firestore.SERVER_TIMESTAMP,
                }
            )
        except Exception as e:
            logging.warning(f"Could not write backfill run start log: {e}")

        processed = backfill_all(db)

        # Update log entry with results
        try:
            if "run_id" in locals():
                db.collection("backfill_runs").document(run_id).update(
                    {
                        "status": "success",
                        "processed": processed,
                        "endTime": firestore.SERVER_TIMESTAMP,
                    }
                )
        except Exception as e:
            logging.warning(f"Could not update backfill run log: {e}")

        return {"processed": processed}
    except Exception as e:
        logging.error(f"backfill_search_index error: {e}")
        # Update run doc with failure status if it exists
        try:
            if "run_id" in locals():
                db.collection("backfill_runs").document(run_id).update(
                    {
                        "status": "failed",
                        "error": str(e),
                        "endTime": firestore.SERVER_TIMESTAMP,
                    }
                )
        except Exception as _:
            logging.warning("Could not update backfill run failure status")
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message="Failed to backfill search index.",
            details=str(e),
        )
