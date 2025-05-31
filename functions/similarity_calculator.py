# functions/similarity_calculator.py
# Likely imports:
import nltk # Keep for nltk.data.path
# All other NLTK/sklearn imports moved to be lazy loaded
import os
import firebase_admin
from firebase_admin import credentials, firestore
import glob  # For debugging deployed nltk_data contents

# Global variable to hold the Firestore client
fb_db = None


def _initialize_firebase():
    global fb_db
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
        # print("Firebase Admin SDK initialized.") # Commented out for production
    # else:
        # print("Firebase Admin SDK already initialized.") # Commented out for production
    fb_db = firestore.client()


# --- NLTK Data Setup ---
NLTK_DATA_DIR_NAME = "nltk_data"
# In Cloud Functions, __file__ should point to the deployed script\'s location, e.g., /workspace/similarity_calculator.py
# So, NLTK_DATA_PATH should become /workspace/nltk_data
NLTK_DATA_PATH = os.path.join(os.path.dirname(__file__), NLTK_DATA_DIR_NAME)

if NLTK_DATA_PATH not in nltk.data.path:
    nltk.data.path.insert(0, NLTK_DATA_PATH)

_stopwords_cache = None
_punkt_initialized = False

# Removed NLTK pre-loading from global scope to prevent deployment timeouts.
# These will be loaded on-demand by _ensure_nltk_resources().
# print("--- Attempting NLTK Punkt Pre-load ---")
# try:
#     print(f"Attempting word_tokenize with a test sentence to pre-load Punkt...")
#     test_tokens = nltk.word_tokenize("This is a test sentence for Punkt pre-loading.")
#     print(f"Punkt pre-load successful. Test tokens: {test_tokens[:5]}...")
#
#     print(f"Attempting to load stopwords...")
#     sw = nltk.corpus.stopwords.words('english')
#     print(f"Stopwords loaded successfully. Count: {len(sw)}.")
#
# except Exception as e:
#     print(f"ERROR during NLTK pre-load: {e}")
# print("--- End NLTK Punkt Pre-load ---")

# You can also add more detailed logging about what\'s actually in NLTK_DATA_PATH in the cloud:
# if os.path.exists(NLTK_DATA_PATH):
#     print(f"Contents of {NLTK_DATA_PATH} in cloud: {os.listdir(NLTK_DATA_PATH)}")
#     tokenizers_path = os.path.join(NLTK_DATA_PATH, 'tokenizers')
#     if os.path.exists(tokenizers_path):
#         print(f"Contents of {tokenizers_path} in cloud: {os.listdir(tokenizers_path)}")
#         punkt_path = os.path.join(tokenizers_path, 'punkt')
#         if os.path.exists(punkt_path):
#             print(f"Contents of {punkt_path} in cloud: {os.listdir(punkt_path)}")
# else:
#     print(f"{NLTK_DATA_PATH} does not exist in the cloud environment.")


def _setup_nltk_data_for_packaging():
    """
    Ensures NLTK data (stopwords, punkt) is downloaded and UNZIPPED to the local 
    nltk_data directory. This directory MUST then be packaged and deployed.
    This function is intended to be run locally BEFORE deployment.
    """
    from nltk.tokenize import word_tokenize # LAZY IMPORT for this function
    from nltk.corpus import stopwords # LAZY IMPORT for this function
    print(f"--- Running NLTK Data Setup for Local Packaging ---")
    # NLTK_DATA_PATH is defined at the module level, e.g., os.path.join(os.path.dirname(__file__), "nltk_data")
    print(f"Target local NLTK data directory: {NLTK_DATA_PATH}")

    # Ensure base nltk_data directory and subdirectories for tokenizers and corpora exist
    tokenizers_dir = os.path.join(NLTK_DATA_PATH, "tokenizers")
    corpora_dir = os.path.join(NLTK_DATA_PATH, "corpora")
    os.makedirs(tokenizers_dir, exist_ok=True)
    os.makedirs(corpora_dir, exist_ok=True)

    resources_to_download = ["punkt", "stopwords", "punkt_tab"]

    # Download resources. NLTK places them in subdirectories like \'tokenizers\' or \'corpora\' within download_dir.
    for resource_name in resources_to_download:
        print(f"Downloading NLTK resource: \'{resource_name}\' to {NLTK_DATA_PATH} (NLTK will use subdirs)...")
        try:
            nltk.download(resource_name, download_dir=NLTK_DATA_PATH)
            print(f"Successfully downloaded \'{resource_name}\'.")
        except Exception as e:
            print(f"ERROR downloading NLTK resource \'{resource_name}\': {e}")
            print("Please ensure network connectivity and that NLTK can write to the target.")
            return # Stop if a download fails

    # Temporarily modify nltk.data.path to include our target NLTK_DATA_PATH
    # This ensures that when we call NLTK functions, they use and unpack from our specific directory.
    original_nltk_data_path_list = list(nltk.data.path)
    if NLTK_DATA_PATH not in nltk.data.path:
        nltk.data.path.insert(0, NLTK_DATA_PATH)
    
    try:
        # Trigger NLTK to unpack \'punkt\' if it hasn\'t already from the .zip
        print("Verifying/Unpacking \'punkt\' tokenizer locally...")
        word_tokenize("test sentence for punkt unpacking")
        print("\'punkt\' tokenizer ready locally.")

        # Trigger NLTK to unpack \'stopwords\' if it hasn\'t already
        print("Verifying/Unpacking \'stopwords\' locally...")
        stopwords.words("english")
        print("\'stopwords\' ready locally.")
    except Exception as e:
        print(f"ERROR during local NLTK resource test (unpacking): {e}")
        # Restore nltk.data.path before returning on error
        nltk.data.path = original_nltk_data_path_list
        return
    finally:
        # Restore original nltk.data.path
        nltk.data.path = original_nltk_data_path_list

    # Remove the .zip files after NLTK has had a chance to unpack them
    # This ensures only the unzipped directories are deployed.
    punkt_zip_path = os.path.join(tokenizers_dir, "punkt.zip")
    stopwords_zip_path = os.path.join(corpora_dir, "stopwords.zip")

    for zip_file_path in [punkt_zip_path, stopwords_zip_path]:
        if os.path.exists(zip_file_path):
            try:
                os.remove(zip_file_path)
                print(f"Removed local .zip file: {zip_file_path}")
            except Exception as e:
                print(f"Warning: Could not remove .zip file {zip_file_path}: {e}")
        else:
            print(f".zip file not found (already removed or never existed): {zip_file_path}")
            
    # Clean up .DS_Store files (common on macOS)
    for root, dirs, files in os.walk(NLTK_DATA_PATH):
        if ".DS_Store" in files:
            ds_store_file = os.path.join(root, ".DS_Store")
            try:
                os.remove(ds_store_file)
                print(f"Removed .DS_Store file: {ds_store_file}")
            except Exception as e:
                print(f"Warning: Could not remove .DS_Store file {ds_store_file}: {e}")

    print(f"--- NLTK Data Setup for Local Packaging Complete ---")
    print(f"Ensure the directory \'{NLTK_DATA_PATH}\' (now with unzipped contents and no zips) is deployed.")

# --- Configuration for Similarity Algorithm (from Task 1.1) ---
FIELD_MATCH_WEIGHTS = {
    "level": 0.3,
    "players": 0.2,
    "duration": 0.1,
    "common_monsters": 0.2,
    "environment": 0.1,
    "tags": 0.1,
}

HYBRID_APPROACH_WEIGHTING = {
    "field_matching_score": 0.60,
    "text_similarity_score": 0.40,
}

# NLP Libraries to be used: nltk for preprocessing, scikit-learn for TF-IDF and cosine similarity.
SIMILAR_QUESTS_SUBCOLLECTION = "similarQuests"  # Define subcollection name


def calculate_similarity_for_quest(quest_id: str) -> list:
    """
    Calculates similarity scores for a given quest against all other quests.
    Retrieves quest data from Firestore, computes field matching and text similarity,
    combines them using a hybrid approach, and returns a sorted list of top N similar quests.

    Args:
        quest_id: The ID of the target quest.

    Returns:
        A list of tuples, where each tuple contains (similar_quest_id, hybrid_score),
        sorted by hybrid_score in descending order. Limited to top N results.
    """
    global fb_db
    _initialize_firebase()  # Ensure Firebase is initialized

    print(f"Calculating similarity for quest: {quest_id}")

    # 1. Retrieve target quest details from Firestore
    target_quest_ref = fb_db.collection("questCards").document(quest_id)
    target_quest_doc = target_quest_ref.get()
    if not target_quest_doc.exists:
        print(f"Error: Target quest {quest_id} not found.")
        return []
    target_quest_data = target_quest_doc.to_dict()
    target_quest_data["id"] = quest_id  # Ensure id is part of the dict

    # 2. Retrieve all other quests from Firestore
    all_quests_ref = fb_db.collection("questCards")
    all_quest_docs = all_quests_ref.stream()
    other_quests_data = []
    for doc in all_quest_docs:
        if doc.id != quest_id:
            quest_data = doc.to_dict()
            quest_data["id"] = doc.id  # Ensure id is part of the dict
            other_quests_data.append(quest_data)

    if not other_quests_data:
        print("No other quests found to compare against.")
        return []

    similarities = []

    for other_quest in other_quests_data:
        # 3.1. Calculate field matching score
        field_score = _calculate_field_match_score(
            target_quest_data, other_quest, FIELD_MATCH_WEIGHTS
        )

        # 3.2. Calculate text similarity score (titles & summaries)
        # For simplicity, let\'s assume titles and summaries are weighted equally for the text score.
        # A more sophisticated approach might weight them differently or combine them before TF-IDF.
        title_similarity = _calculate_text_similarity(
            target_quest_data.get("title", ""), other_quest.get("title", "")
        )
        summary_similarity = _calculate_text_similarity(
            target_quest_data.get("summary", ""), other_quest.get("summary", "")
        )

        # Average similarity for title and summary
        combined_text_score = (title_similarity + summary_similarity) / 2

        # 3.3. Calculate overall hybrid score
        hybrid_score = (
            field_score * HYBRID_APPROACH_WEIGHTING["field_matching_score"]
        ) + (combined_text_score * HYBRID_APPROACH_WEIGHTING["text_similarity_score"])

        similarities.append({"id": other_quest["id"], "score": hybrid_score})

    # 4. Sort results by hybrid_score (descending)
    similarities.sort(key=lambda x: x["score"], reverse=True)

    # 5. Get top N (e.g., 10) similar quests
    top_n_similarities = similarities[:10]

    # 6. Store these top N similarities in Firestore
    if top_n_similarities:
        print(
            f"Storing top {len(top_n_similarities)} similar quests for {quest_id} in subcollection \'{SIMILAR_QUESTS_SUBCOLLECTION}\'..."
        )
        target_quest_ref = fb_db.collection("questCards").document(quest_id)
        subcollection_ref = target_quest_ref.collection(SIMILAR_QUESTS_SUBCOLLECTION)

        # Atomically delete all existing documents in the subcollection and add new ones
        batch = fb_db.batch()

        # Delete existing documents
        # Note: Listing and deleting in a loop can be less efficient for very large subcollections,
        # but for a small number (e.g., <100) of similar quests, it\'s generally acceptable.
        # For Cloud Functions, consider time limits.
        # A more robust way for larger subcollections might involve a recursive delete helper if needed.
        existing_similar_docs = subcollection_ref.stream()
        for doc in existing_similar_docs:
            batch.delete(doc.reference)

        # Add new similar quest documents
        for similar_quest_info in top_n_similarities:
            similar_quest_id = similar_quest_info["id"]
            score = similar_quest_info["score"]
            similar_quest_doc_ref = subcollection_ref.document(similar_quest_id)
            batch.set(
                similar_quest_doc_ref,
                {"score": score, "calculatedAt": firestore.SERVER_TIMESTAMP},
            )

        try:
            batch.commit()
            print(f"Successfully stored/updated similar quests for {quest_id}.")
        except Exception as e:
            print(f"Error storing similar quests for {quest_id}: {e}")
    else:
        print(f"No similar quests to store for {quest_id}.")
        # Optionally, clear the subcollection if no similarities are found
        target_quest_ref = fb_db.collection("questCards").document(quest_id)
        subcollection_ref = target_quest_ref.collection(SIMILAR_QUESTS_SUBCOLLECTION)
        existing_similar_docs = subcollection_ref.stream()
        # Check if subcollection is not empty before starting a batch
        docs_to_delete = [doc.reference for doc in existing_similar_docs]
        if docs_to_delete:
            batch = fb_db.batch()
            for doc_ref in docs_to_delete:
                batch.delete(doc_ref)
            try:
                batch.commit()
                print(
                    f"Cleared existing similar quests for {quest_id} as no new similarities were found."
                )
            except Exception as e:
                print(f"Error clearing similar quests for {quest_id}: {e}")

    print(f"Calculated similarities: {top_n_similarities}")
    return top_n_similarities


def _calculate_field_match_score(
    quest1_data: dict, quest2_data: dict, field_weights: dict
) -> float:
    """
    Calculates a weighted score based on matching predefined fields.
    Normalizes the score to be between 0 and 1.
    """
    score = 0.0
    max_possible_score = sum(field_weights.values())  # Sum of all weights

    # Level
    if "level" in quest1_data and "level" in quest2_data:
        if quest1_data["level"] == quest2_data["level"]:
            score += field_weights["level"]

    # Players
    if "players" in quest1_data and "players" in quest2_data:
        if quest1_data["players"] == quest2_data["players"]:
            score += field_weights["players"]

    # Duration
    if "duration" in quest1_data and "duration" in quest2_data:
        if quest1_data["duration"] == quest2_data["duration"]:
            score += field_weights["duration"]

    # Common Monsters, Environment, Tags (List-based fields)
    for field in ["common_monsters", "environment", "tags"]:
        items1 = quest1_data.get(field, [])
        items2 = quest2_data.get(field, [])

        if not isinstance(items1, (list, set)):
            items1 = []
        if not isinstance(items2, (list, set)):
            items2 = []

        if not items1 and not items2:
            common_elements = 0
        elif not items1 or not items2:
            common_elements = 0
        else:
            common_elements = len(set(items1).intersection(set(items2)))

        if common_elements > 0:
            score += field_weights[field]

    return score


def _calculate_text_similarity(text1: str, text2: str) -> float:
    """
    Calculates cosine similarity between two texts using TF-IDF.
    Uses nltk for tokenization/stopwords and scikit-learn for TF-IDF.
    """
    from nltk.tokenize import word_tokenize # LAZY IMPORT
    from sklearn.feature_extraction.text import TfidfVectorizer # LAZY IMPORT
    from sklearn.metrics.pairwise import cosine_similarity # LAZY IMPORT
    
    _ensure_nltk_resources() # Ensure NLTK resources are loaded

    # Explicitly check for two empty strings at the beginning
    if not text1 and not text2:
        return 1.0

    stop_words_set = _stopwords_cache if _stopwords_cache is not None else set()

    def preprocess(text_content):
        tokens = word_tokenize(text_content.lower())
        # Keep only alphanumeric words and remove stopwords
        return " ".join(
            [word for word in tokens if word.isalnum() and word not in stop_words_set]
        )

    processed_text1 = preprocess(text1)
    processed_text2 = preprocess(text2)

    # If after preprocessing, both texts are empty (e.g., only stopwords or special chars),
    # they can be considered identical in terms of meaningful content.
    # If one is empty after processing, it means it had only stopwords or special chars, affecting similarity.
    if not processed_text1 and not processed_text2:
        return 1.0  # Both are empty after processing, so they are identical in terms of content
    elif not processed_text1 or not processed_text2:
        return 0.0  # One is empty, the other is not, so no similarity

    try:
        # Create TF-IDF vectors for both processed texts
        tfidf_matrix = TfidfVectorizer().fit_transform([processed_text1, processed_text2])
    except ValueError:
        # This can happen if vocabulary is empty (e.g., texts contained only characters not part of TF-IDF's default token pattern)
        return 0.0

    # Calculate cosine similarity between the two vectors
    # tfidf_matrix[0:1] is the vector for processed_text1
    # tfidf_matrix[1:2] is the vector for processed_text2
    similarity_matrix = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:2])

    # similarity_matrix is a 2D array, e.g., [[value]], so extract the value
    return float(similarity_matrix[0][0])


def _ensure_nltk_resources():
    """
    Ensures NLTK\'s Punkt tokenizer and stopwords are loaded.
    This function is called before NLTK operations that depend on these resources.
    """
    global _stopwords_cache, _punkt_initialized

    if not _punkt_initialized:
        from nltk.tokenize import word_tokenize # LAZY IMPORT
        try:
            # print("Ensuring NLTK Punkt tokenizer is ready (first-time use)...")
            # A light operation to trigger NLTK\'s internal loading of Punkt if needed.
            # NLTK\'s word_tokenize handles its own lazy loading of \'punkt\'.
            # This call ensures it happens before we rely on it in loops.
            word_tokenize("test") 
            # print("NLTK Punkt tokenizer should be ready.")
            _punkt_initialized = True
        except Exception as e:
            print(f"ERROR initializing NLTK Punkt tokenizer: {e}")
            # Depending on severity, you might re-raise or handle (e.g., proceed without tokenization)

    if _stopwords_cache is None:
        from nltk.corpus import stopwords # LAZY IMPORT
        try:
            # print("Loading NLTK stopwords (first-time use)...")
            _stopwords_cache = set(stopwords.words("english"))
            # print(f"NLTK stopwords loaded. Count: {len(_stopwords_cache)}")
        except Exception as e:
            print(f"ERROR loading NLTK stopwords: {e}")
            _stopwords_cache = set() # Fallback to empty set if loading fails


# Example usage (for testing locally)
if __name__ == "__main__":
    # This part would require Firebase setup if using actual Firestore calls
    # For now, it will run with placeholder data
    print("Running similarity calculation example...")
    # !!! IMPORTANT: Replace "YOUR_ACTUAL_QUEST_ID_FROM_FIRESTORE" with a real ID from your Firestore 'questCards' collection for testing.
    test_quest_id = "e9fM0VdDXz0QyrveF5ly"

    if test_quest_id == "YOUR_ACTUAL_QUEST_ID_FROM_FIRESTORE":
        print(
            "ERROR: Please update 'test_quest_id' in similarity_calculator.py with an actual ID from your Firestore 'questCards' collection."
        )
    else:
        similar_quests_result = calculate_similarity_for_quest(test_quest_id)
        if similar_quests_result:
            print(f"Top similar quests for {test_quest_id}:")
            for quest in similar_quests_result:
                print(
                    f"  Quest ID: {quest['id']}, Similarity Score: {quest['score']:.4f}"
                )
        else:
            print(
                f"No similar quests found or error during calculation for {test_quest_id}."
            )

    # Local setup for NLTK data (uncomment to run)
    _setup_nltk_data_for_packaging()
