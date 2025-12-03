import logging
import os
from typing import List, Dict, Any

# Lightweight server-side search that reuses similarity helpers.
# Designed to be callable from functions/main.py via https_fn.on_call.


def _snippet_for_query(text: str, query: str, radius: int = 80) -> str:
    if not text or not query:
        return ""
    q = query.lower()
    t = text.lower()
    idx = t.find(q)
    if idx == -1:
        # fallback to start
        return text[:radius].strip()
    start = max(0, idx - radius // 4)
    end = min(len(text), idx + len(q) + radius // 2)
    return (
        ("..." if start > 0 else "")
        + text[start:end].strip()
        + ("..." if end < len(text) else "")
    )


def search_quests_core(
    query: str,
    filters: Dict[str, Any],
    page: int,
    page_size: int,
    quests: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """Pure function for searching over an in-memory list of quest dicts.

    Each quest dict should at minimum contain: id, title, summary and various
    fields (level, players, duration, tags, environment, common_monsters).
    Returns a paginated dict with hits sorted by score.
    """
    # Lazy imports that can be expensive in cloud functions.
    try:
        from similarity_calculator import (
            _calculate_text_similarity,
            _calculate_field_match_score,
            HYBRID_APPROACH_WEIGHTING,
        )
    except Exception as e:
        logging.error("Failed to import similarity helpers: %s", e)
        raise

    query = (query or "").strip()
    page = max(1, int(page or 1))
    page_size = max(1, int(page_size or 10))

    # Suggestions only: return short title suggestions matching the query
    if not query:
        # No query; return empty results or all depending on client.
        return {"total": 0, "page": page, "pageSize": page_size, "hits": []}

    # Basic filtering: apply equality filters for level/players/duration if provided
    def passes_filters(quest: Dict[str, Any]) -> bool:
        if not filters:
            return True
        for k, v in (filters or {}).items():
            if v is None:
                continue
            # If filter value is a list, check any match
            if isinstance(v, list):
                if quest.get(k) not in v:
                    return False
            else:
                if quest.get(k) != v:
                    return False
        return True

    candidates = [q for q in quests if passes_filters(q)]

    results = []

    for q in candidates:
        title = q.get("title", "")
        summary = q.get("summary", "")

        title_sim = _calculate_text_similarity(query, title)
        summary_sim = _calculate_text_similarity(query, summary)
        combined_text_score = (title_sim + summary_sim) / 2

        # For field match we supply the query as an empty target object and use
        # the quest fields directly — field score will be low for free text queries
        # but this keeps hybrid approach consistent.
        field_score = 0.0
        try:
            # We construct a dummy target that may include filters to boost matches
            target = {}
            for f in [
                "level",
                "players",
                "duration",
                "common_monsters",
                "environment",
                "tags",
            ]:
                if filters and f in filters:
                    target[f] = filters[f]
            field_score = _calculate_field_match_score(
                target,
                q,
                {
                    "level": 0.3,
                    "players": 0.2,
                    "duration": 0.1,
                    "common_monsters": 0.2,
                    "environment": 0.1,
                    "tags": 0.1,
                },
            )
        except Exception:
            field_score = 0.0

        hybrid_score = (
            field_score * HYBRID_APPROACH_WEIGHTING["field_matching_score"]
            + combined_text_score * HYBRID_APPROACH_WEIGHTING["text_similarity_score"]
        )

        results.append(
            {
                "id": q.get("id"),
                "title": title,
                "snippet": _snippet_for_query(summary or title, query),
                "score": float(hybrid_score),
            }
        )

    # Sort by score descending
    results.sort(key=lambda x: x["score"], reverse=True)

    total = len(results)
    start = (page - 1) * page_size
    end = start + page_size
    page_hits = results[start:end]

    return {
        "total": total,
        "page": page,
        "pageSize": page_size,
        "hits": page_hits,
    }


if __name__ == "__main__":
    # Simple smoke test when run locally
    sample = [
        {"id": "1", "title": "Dragon Hunt", "summary": "Hunt the red dragon"},
        {"id": "2", "title": "Goblin Cave", "summary": "Clear goblins"},
    ]
    print(search_quests_core("dragon", {}, 1, 10, sample))
