# functions/similarity_calculator.py
# Likely imports:
import nltk
from nltk.tokenize import word_tokenize
from nltk.corpus import stopwords
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

import firebase_admin
from firebase_admin import credentials, firestore

# Global variable to hold the Firestore client
fb_db = None


def _initialize_firebase():
    global fb_db
    if not firebase_admin._apps:
        # Initialize the Firebase Admin SDK. This is typically done once.
        # In a Cloud Function environment, this might be handled differently
        # or you might rely on the default app initialization if run in that context.
        # For local testing or scripts, explicit initialization is often needed.
        # cred = credentials.ApplicationDefault() # Or use a service account key
        # firebase_admin.initialize_app(cred)
        firebase_admin.initialize_app()  # Initialize with default credentials
        print("Firebase Admin SDK initialized.")
    else:
        print("Firebase Admin SDK already initialized.")
    fb_db = firestore.client()


# Download nltk resources if not already present
# It's good practice to ensure these are available.
# In a deployed environment (like a cloud function), these might need to be packaged or pre-downloaded.
try:
    stopwords.words("english")
except LookupError:
    nltk.download("stopwords", quiet=True)
try:
    word_tokenize("test")  # A simple way to check if 'punkt' is available
except LookupError:
    nltk.download("punkt", quiet=True)

# --- Configuration for Similarity Algorithm (from Task 1.1) ---
FIELD_MATCH_WEIGHTS = {
    "game_system": 0.30,
    "genre": 0.30,
    "common_monsters": 0.20,  # Assuming list/set comparison
    "environment": 0.20,  # Assuming list/set comparison
}
# Note: 'summary' field matching is not included here, assuming its similarity is covered by text similarity.

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
        # For simplicity, let's assume titles and summaries are weighted equally for the text score.
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
            f"Storing top {len(top_n_similarities)} similar quests for {quest_id} in subcollection '{SIMILAR_QUESTS_SUBCOLLECTION}'..."
        )
        target_quest_ref = fb_db.collection("questCards").document(quest_id)
        subcollection_ref = target_quest_ref.collection(SIMILAR_QUESTS_SUBCOLLECTION)

        # Atomically delete all existing documents in the subcollection and add new ones
        batch = fb_db.batch()

        # Delete existing documents
        # Note: Listing and deleting in a loop can be less efficient for very large subcollections,
        # but for a small number (e.g., <100) of similar quests, it's generally acceptable.
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

    if quest1_data.get("game_system") == quest2_data.get("game_system"):
        score += field_weights["game_system"]
    if quest1_data.get("genre") == quest2_data.get("genre"):
        score += field_weights["genre"]

    # For fields like 'common_monsters' and 'environment' (assumed to be lists/sets of strings)
    # Use Jaccard similarity or simple overlap percentage
    for field_key in ["common_monsters", "environment"]:
        set1 = set(quest1_data.get(field_key, []))
        set2 = set(quest2_data.get(field_key, []))
        if (
            not set1 and not set2
        ):  # Both empty, consider perfect match for this field or skip
            # score += field_weights[field_key] # Option: count as match
            pass
        elif set1 and set2:
            intersection = len(set1.intersection(set2))
            union = len(set1.union(set2))
            if union > 0:
                jaccard_sim = intersection / union
                score += field_weights[field_key] * jaccard_sim

    if max_possible_score == 0:
        return 0.0
    return score / max_possible_score if max_possible_score > 0 else 0.0


def _calculate_text_similarity(text1: str, text2: str) -> float:
    """
    Calculates cosine similarity between two texts using TF-IDF.
    Uses nltk for tokenization/stopwords and scikit-learn for TF-IDF.
    """
    if not text1 or not text2:
        return 0.0
    # If texts are identical, similarity is 1.0
    if text1 == text2:
        return 1.0

    stop_words_set = set(stopwords.words("english"))

    def preprocess(text_content):
        tokens = word_tokenize(text_content.lower())
        # Keep only alphanumeric words and remove stopwords
        return " ".join(
            [word for word in tokens if word.isalnum() and word not in stop_words_set]
        )

    processed_text1 = preprocess(text1)
    processed_text2 = preprocess(text2)

    # If after preprocessing, one or both texts are empty (e.g., only stopwords or special chars),
    # they can't be vectorized, so similarity is 0.
    if not processed_text1 or not processed_text2:
        return 0.0

    vectorizer = TfidfVectorizer()
    try:
        # Create TF-IDF vectors for both processed texts
        tfidf_matrix = vectorizer.fit_transform([processed_text1, processed_text2])
    except ValueError:
        # This can happen if vocabulary is empty (e.g., texts contained only characters not part of TF-IDF's default token pattern)
        return 0.0

    # Calculate cosine similarity between the two vectors
    # tfidf_matrix[0:1] is the vector for processed_text1
    # tfidf_matrix[1:2] is the vector for processed_text2
    similarity_matrix = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:2])

    # similarity_matrix is a 2D array, e.g., [[value]], so extract the value
    return float(similarity_matrix[0][0])


# Example usage (for testing locally)
if __name__ == "__main__":
    # This part would require Firebase setup if using actual Firestore calls
    # For now, it will run with placeholder data
    print("Running similarity calculation example...")
    # !!! IMPORTANT: Replace "YOUR_ACTUAL_QUEST_ID_FROM_FIRESTORE" with a real ID from your Firestore 'questCards' collection for testing.
    test_quest_id = "YOUR_ACTUAL_QUEST_ID_FROM_FIRESTORE"

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
