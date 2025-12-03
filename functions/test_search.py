import pytest

from search import search_quests_core


def make_quest(id, title, summary, **fields):
    q = {"id": id, "title": title, "summary": summary}
    q.update(fields)
    return q


def test_search_basic_text():
    quests = [
        make_quest("1", "Dragon Hunt", "Hunt the red dragon in the mountains."),
        make_quest("2", "Goblin Clearing", "Clear the goblin camp in the woods."),
        make_quest("3", "Rescue", "Rescue the prince from a dragon lair."),
    ]

    out = search_quests_core("dragon", {}, 1, 10, quests)
    assert out["total"] == 3
    assert out["hits"]
    # Expect a dragon-related quest at top
    assert out["hits"][0]["id"] in ("1", "3")


def test_search_filters():
    quests = [
        make_quest("1", "Easy Hunt", "Hunt small beasts.", level=1),
        make_quest("2", "Hard Hunt", "Hunt a dragon.", level=5),
    ]

    out = search_quests_core("hunt", {"level": 5}, 1, 10, quests)
    assert out["total"] == 1
    assert out["hits"][0]["id"] == "2"
