# filepath: c:\Users\cephy\Documents\App Development\quest_cards\populate_emulator.py
import os
import firebase_admin
from firebase_admin import credentials, firestore

# --- Configuration ---
# Point the SDK to the Firestore emulator
os.environ["FIRESTORE_EMULATOR_HOST"] = "localhost:8282"

# --- Initialization ---
try:
    # Use application default credentials (useful for emulators)
    # No specific service account key needed when running against emulator
    firebase_admin.initialize_app()
    print("Firebase Admin SDK initialized successfully.")
except ValueError as e:
    # Handle cases where it might already be initialized (e.g., running script multiple times)
    if "The default Firebase app already exists" in str(e):
        print("Firebase Admin SDK already initialized.")
    else:
        raise e

db = firestore.client()
print("Firestore client obtained.")

# --- Data Definitions ---

# Game Systems Data
game_systems_data = [
    {
        "id": "dnd5e",
        "data": {
            "standardName": "Dungeons & Dragons 5th Edition",
            "aliases": ["D&D 5e", "5e"],
        },
    },
    {
        "id": "pf2e",
        "data": {
            "standardName": "Pathfinder 2nd Edition",
            "aliases": ["PF2e", "Pathfinder 2"],
        },
    },
    {
        "id": "coc7e",
        "data": {"standardName": "Call of Cthulhu 7th Edition", "aliases": ["CoC 7e"]},
    },
    {
        "id": "swade",
        "data": {
            "standardName": "Savage Worlds Adventure Edition",
            "aliases": ["SWADE"],
        },
    },
]

# Quest Cards Data
quest_cards_data = [
    # --- Cards that SHOULD be processed by the cleanup function ---
    {
        "id": "card_pending_exact",
        "data": {
            "title": "Exact Match Test",
            "gameSystem": "Dungeons & Dragons 5th Edition",
            "systemMigrationStatus": "pending",
        },
    },
    {
        "id": "card_pending_case",
        "data": {
            "title": "Case-Insensitive Test",
            "gameSystem": "dungeons & dragons 5th edition",
            "systemMigrationStatus": "pending",
        },
    },
    {
        "id": "card_pending_alias",
        "data": {
            "title": "Alias Test",
            "gameSystem": "PF2e",
            "systemMigrationStatus": "pending",
        },
    },
    {
        "id": "card_pending_substring",
        "data": {
            "title": "Substring Test",
            "gameSystem": "Call of Cthulhu",
            "systemMigrationStatus": "pending",
        },
    },
    {
        "id": "card_pending_acronym",
        "data": {
            "title": "Acronym Test",
            "gameSystem": "CoC 7e",
            "systemMigrationStatus": "pending",
        },
    },
    {
        "id": "card_pending_nomatch",
        "data": {
            "title": "No Match Test",
            "gameSystem": "Totally Obscure Game",
            "systemMigrationStatus": "pending",
        },
    },
    {
        "id": "card_failed_retry",
        "data": {
            "title": "Failed Retry Test",
            "gameSystem": "Pathfinder 2",
            "systemMigrationStatus": "failed",
        },
    },
    {
        "id": "card_null_status",
        "data": {
            "title": "Null Status Test",
            "gameSystem": "Savage Worlds Adventure Edition",
            "systemMigrationStatus": None,
        },
    },  # Test None status
    {
        "id": "card_missing_status",
        "data": {"title": "Missing Status Test", "gameSystem": "SWADE"},
    },  # Test missing status field
    {
        "id": "card_pending_missing_gs",
        "data": {
            "title": "Missing GameSystem Test",
            "systemMigrationStatus": "pending",
        },
    },  # Test missing gameSystem
    {
        "id": "card_pending_empty_gs",
        "data": {
            "title": "Empty GameSystem Test",
            "gameSystem": "",
            "systemMigrationStatus": "pending",
        },
    },  # Test empty gameSystem
    # --- Cards that should generally be IGNORED by the cleanup function's main query ---
    {
        "id": "card_completed_ignore",
        "data": {
            "title": "Completed Ignore Test",
            "gameSystem": "D&D 5e",
            "standardizedGameSystem": "Dungeons & Dragons 5th Edition",
            "systemMigrationStatus": "completed",
        },
    },
    {
        "id": "card_needsreview_ignore",
        "data": {
            "title": "Needs Review Ignore Test",
            "gameSystem": "Some Vague System",
            "systemMigrationStatus": "needs_review",
        },
    },
    {
        "id": "card_nomatch_ignore",
        "data": {
            "title": "No Match Ignore Test",
            "gameSystem": "Another Unknown Game",
            "systemMigrationStatus": "no_match",
        },
    },
]

# --- Population Logic ---

print("\nPopulating 'game_systems' collection...")
game_systems_ref = db.collection("game_systems")
for system in game_systems_data:
    try:
        game_systems_ref.document(system["id"]).set(system["data"])
        print(f"  Added/Updated game system: {system['id']}")
    except Exception as e:
        print(f"  Error adding game system {system['id']}: {e}")

print("\nPopulating 'questCards' collection...")
quest_cards_ref = db.collection("questCards")
for card in quest_cards_data:
    try:
        quest_cards_ref.document(card["id"]).set(card["data"])
        print(f"  Added/Updated quest card: {card['id']}")
    except Exception as e:
        print(f"  Error adding quest card {card['id']}: {e}")

print("\nEmulator population script finished.")
