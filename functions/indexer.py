"""Simple search indexer for questCards.

Creates/updates documents in collection `questSearchIndex` where each doc id
matches the questCard id. The index document contains a concatenated `search_text`
and a small list of `tokens` useful for suggestion/autocomplete.

This uses a lightweight tokenization (regex) to avoid heavy NLP packages during
indexing. The search core can still use NLTK/scikit for matching when executing
queries.
"""

from __future__ import annotations

import datetime
import re
from typing import Dict, Any, Iterable

STOPWORDS = {
    # Small stopword list to avoid packaging heavy NLTK for basic indexing
    "the",
    "and",
    "a",
    "an",
    "of",
    "in",
    "on",
    "for",
    "to",
    "with",
    "is",
    "are",
    "from",
}

TOKEN_RE = re.compile(r"\b[a-z0-9]{2,}\b", re.IGNORECASE)


def _tokenize(text: str) -> Iterable[str]:
    if not text:
        return []
    tokens = TOKEN_RE.findall(text.lower())
    return [t for t in tokens if t not in STOPWORDS]


def build_index_doc(quest: Dict[str, Any]) -> Dict[str, Any]:
    """Create an index document payload from a quest document dict.

    The quest dict is expected to contain keys like `title`, `summary`, `tags`,
    `environment`, `common_monsters`, etc.
    """
    title = str(quest.get("title", "")).strip()
    summary = str(quest.get("summary", "")).strip()

    fields_join = []
    for e in (quest.get("tags") or []) + (quest.get("environment") or []):
        fields_join.append(str(e))

    # Add some structured fields as text so they influence tokenization
    level = quest.get("level")
    if level is not None:
        fields_join.append(str(level))

    players = quest.get("players")
    if players is not None:
        fields_join.append(str(players))

    combined = " ".join([title, summary] + fields_join)

    tokens = list(dict.fromkeys(_tokenize(combined)))  # preserve order, unique

    return {
        "title": title,
        "summary": summary,
        "search_text": combined,
        "tokens": tokens[:50],
        "indexedAt": datetime.datetime.utcnow(),
    }


def index_quest(db, quest_id: str, quest_data: Dict[str, Any]) -> None:
    """Write the index document for a single quest into `questSearchIndex`.

    Args:
        db: Firestore client
        quest_id: id of quest document
        quest_data: dictionary of quest fields
    """
    idx_doc = build_index_doc(quest_data)
    db.collection("questSearchIndex").document(quest_id).set(idx_doc)


def delete_index(db, quest_id: str) -> None:
    db.collection("questSearchIndex").document(quest_id).delete()


def backfill_all(db, batch_size: int = 500) -> int:
    """Backfill all quests into questSearchIndex. Returns number processed.

    Uses streaming and batch writes for efficiency.
    """
    quests_ref = db.collection("questCards")
    processed = 0
    batch = db.batch()
    count_in_batch = 0

    for doc in quests_ref.stream():
        q = doc.to_dict() or {}
        idx_doc = build_index_doc(q)
        dest = db.collection("questSearchIndex").document(doc.id)
        batch.set(dest, idx_doc)
        count_in_batch += 1

        if count_in_batch >= batch_size:
            batch.commit()
            processed += count_in_batch
            batch = db.batch()
            count_in_batch = 0

    if count_in_batch > 0:
        batch.commit()
        processed += count_in_batch

    return processed
