\
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

# Attempt to import the similarity calculation function
# This assumes similarity_calculator.py is in the same directory or Python path
try:
    from .similarity_calculator import calculate_similarity_for_quest
except ImportError:
    # Fallback for direct execution if similarity_calculator is in the same dir
    from similarity_calculator import calculate_similarity_for_quest

def initialize_firebase():
    """
    Initializes the Firebase Admin SDK.
    For local execution, ensure the GOOGLE_APPLICATION_CREDENTIALS environment
    variable is set to the path of your Firebase service account key JSON file.
    """
    try:
        if not firebase_admin._apps:
            # Attempt to initialize with application default credentials
            # This works if GOOGLE_APPLICATION_CREDENTIALS is set,
            # or in Google Cloud environments.
            firebase_admin.initialize_app()
        print("Firebase Admin SDK initialized successfully.")
        return True
    except Exception as e:
        print(f"Error initializing Firebase Admin SDK: {e}")
        print("Please ensure you have set the GOOGLE_APPLICATION_CREDENTIALS environment variable")
        print("to the path of your Firebase service account key JSON file for local execution.")
        #print("Example: export GOOGLE_APPLICATION_CREDENTIALS=\\"/path/to/your/serviceAccountKey.json\\" (Linux/macOS)")
        #print("Example: $env:GOOGLE_APPLICATION_CREDENTIALS=\\"C:\\\\path\\\\to\\\\your\\\\serviceAccountKey.json\\" (PowerShell)")
        return False

def update_all_quests_similarity():
    """
    Iterates through all quests in the 'questCards' collection and updates
    their similar quest lists by calling calculate_similarity_for_quest.
    """
    if not initialize_firebase():
        print("Exiting due to Firebase initialization failure.")
        return

    db = firestore.client()

    print("Fetching all quests from 'questCards' collection...")
    quests_ref = db.collection('questCards')
    
    try:
        all_quests_stream = quests_ref.stream()
    except Exception as e:
        print(f"Error fetching quests from Firestore: {e}")
        print("Please check Firestore permissions and connectivity.")
        return

    quest_count = 0
    updated_count = 0
    error_count = 0
    quests_to_process = []

    # First, collect all quest IDs to avoid issues with stream modification if not handled by client
    for quest_doc in all_quests_stream:
        quests_to_process.append(quest_doc.id)
    
    total_quests_to_process = len(quests_to_process)
    print(f"Found {total_quests_to_process} quests to process.")

    for i, quest_id in enumerate(quests_to_process):
        quest_count += 1
        print(f"Processing quest {quest_count}/{total_quests_to_process}: {quest_id}...")
        try:
            # calculate_similarity_for_quest is expected to handle:
            # 1. Fetching the specific quest's data using quest_id and db.
            # 2. Fetching all other quests for comparison.
            # 3. Calculating similarity scores.
            # 4. Storing the top N similar quests back to the quest's subcollection.
            calculate_similarity_for_quest(quest_id) # Function handles its own db client
            print(f"Successfully updated similar quests for {quest_id}.")
            updated_count += 1
        except Exception as e:
            print(f"Error updating similar quests for {quest_id}: {e}")
            error_count += 1

    print("\\n--- Summary ---")
    print(f"Total quests processed: {quest_count}")
    print(f"Successfully updated: {updated_count}")
    print(f"Failed to update: {error_count}")
    print("----------------")

if __name__ == '__main__':
    print("Starting admin tool to update similar quest lists for all existing quests...")
    update_all_quests_similarity()
    print("Admin tool finished.")
