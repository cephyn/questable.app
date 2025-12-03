from indexer import build_index_doc, _tokenize


def test_tokenize_basic():
    tokens = list(_tokenize("The dragon and the goblins in the cave."))
    # stopwords like 'the', 'and', 'in' should be removed
    assert "dragon" in tokens
    assert "goblins" in tokens
    assert "the" not in tokens


def test_build_index_doc():
    quest = {
        "title": "Lost Mines",
        "summary": "Explore the old mines for lost treasure and fight goblins.",
        "tags": ["dungeon", "goblins"],
        "environment": ["cave"],
        "level": 3,
    }
    idx = build_index_doc(quest)
    assert "search_text" in idx
    assert isinstance(idx["tokens"], list)
    assert "goblins" in idx["tokens"]
