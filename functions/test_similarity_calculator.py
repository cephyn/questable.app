\
# filepath: c:\\AppDev\\questable.app\\functions\\test_similarity_calculator.py
import unittest
from unittest.mock import patch, MagicMock
import nltk
import similarity_calculator as sc # Corrected import statement

# Ensure NLTK data is available
try:
    nltk.data.find('corpora/stopwords')
except LookupError:
    nltk.download('stopwords', quiet=True)
try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    nltk.download('punkt', quiet=True)
try:
    nltk.data.find('tokenizers/punkt_tab') # Added for punkt_tab
except LookupError:
    nltk.download('punkt_tab', quiet=True) # Added for punkt_tab

from similarity_calculator import (
    _calculate_field_match_score,
    _calculate_text_similarity,
    calculate_similarity_for_quest,
    FIELD_MATCH_WEIGHTS, # Keep this if it's used directly in tests for setup
    HYBRID_APPROACH_WEIGHTING,
    SIMILAR_QUESTS_SUBCOLLECTION,
)

class TestSimilarityCalculator(unittest.TestCase):

    def test_calculate_field_match_score_exact_match(self):
        quest1 = {"level": 1, "players": 4, "duration": "2 hours", "common_monsters": ["Goblin", "Orc"], "environment": ["Forest", "Cave"], "tags": ["combat", "exploration"]}
        quest2 = {"level": 1, "players": 4, "duration": "2 hours", "common_monsters": ["Goblin", "Orc"], "environment": ["Forest", "Cave"], "tags": ["combat", "exploration"]}
        score = sc._calculate_field_match_score(quest1, quest2, sc.FIELD_MATCH_WEIGHTS) # Pass weights
        self.assertAlmostEqual(score, 1.0) # Sum of all weights if all match

    def test_calculate_field_match_score_partial_match(self):
        quest1 = {"level": 1, "players": 4, "duration": "2 hours", "common_monsters": ["Goblin"], "environment": ["Forest"], "tags": ["combat"]}
        quest2 = {"level": 2, "players": 4, "duration": "3 hours", "common_monsters": ["Orc"], "environment": ["Cave"], "tags": ["puzzle"]}
        # Expected: only players match
        expected_score = sc.FIELD_MATCH_WEIGHTS["players"] 
        score = sc._calculate_field_match_score(quest1, quest2, sc.FIELD_MATCH_WEIGHTS) # Pass weights
        self.assertAlmostEqual(score, expected_score)

    def test_calculate_field_match_score_no_match(self):
        quest1 = {"level": 1, "players": 3, "duration": "1 hour"}
        quest2 = {"level": 5, "players": 5, "duration": "5 hours"}
        score = sc._calculate_field_match_score(quest1, quest2, sc.FIELD_MATCH_WEIGHTS) # Pass weights
        self.assertEqual(score, 0.0)

    def test_calculate_field_match_score_empty_fields(self):
        quest1 = {}
        quest2 = {}
        score = sc._calculate_field_match_score(quest1, quest2, sc.FIELD_MATCH_WEIGHTS) # Pass weights
        self.assertEqual(score, 0.0)

    def test_calculate_field_match_score_list_fields_empty(self):
        quest1 = {"common_monsters": [], "environment": [], "tags": []}
        quest2 = {"common_monsters": [], "environment": [], "tags": []}
        score = sc._calculate_field_match_score(quest1, quest2, sc.FIELD_MATCH_WEIGHTS) # Pass weights
        self.assertEqual(score, 0.0)

    def test_calculate_text_similarity_identical_texts(self):
        text1 = "The quick brown fox jumps over the lazy dog."
        text2 = "The quick brown fox jumps over the lazy dog."
        score = sc._calculate_text_similarity(text1, text2)
        self.assertAlmostEqual(score, 1.0, places=7) # Use assertAlmostEqual for float comparisons

    def test_calculate_text_similarity_different_texts(self):
        text1 = "This is a sample sentence for testing."
        text2 = "Another example sentence for the test."
        score = sc._calculate_text_similarity(text1, text2)
        self.assertTrue(0.0 <= score < 1.0)

    def test_calculate_text_similarity_one_empty_text(self):
        text1 = "Some text."
        text2 = ""
        score = sc._calculate_text_similarity(text1, text2)
        self.assertEqual(score, 0.0)

    def test_calculate_text_similarity_both_empty_texts(self):
        text1 = ""
        text2 = ""
        score = sc._calculate_text_similarity(text1, text2)
        self.assertEqual(score, 1.0) # Expect 1.0 if both truly empty and processed are empty

    @patch('similarity_calculator.nltk.download')
    @patch('similarity_calculator.word_tokenize')
    @patch('similarity_calculator.stopwords.words')
    def test_calculate_text_similarity_empty_strings(self, mock_stopwords, mock_word_tokenize, mock_nltk_download):
        mock_stopwords.return_value = []
        mock_word_tokenize.side_effect = lambda x: x.split() # simple split for testing
        # Test with two empty strings
        score = sc._calculate_text_similarity("", "")
        self.assertEqual(score, 1.0) # Should be 1.0 if both are empty

    @patch('similarity_calculator.nltk.download')
    @patch('similarity_calculator.word_tokenize')
    @patch('similarity_calculator.stopwords.words')
    def test_calculate_text_similarity_one_empty_string(self, mock_stopwords, mock_word_tokenize, mock_nltk_download):
        mock_stopwords.return_value = ['is', 'the', 'a', 'of', 'and', 'to']
        mock_word_tokenize.side_effect = lambda x: nltk.word_tokenize(x) # Use actual NLTK tokenizer for this
        # Test with one empty string and one non-empty
        score1 = sc._calculate_text_similarity("hello world", "")
        self.assertEqual(score1, 0.0)
        score2 = sc._calculate_text_similarity("", "hello world")
        self.assertEqual(score2, 0.0)

    @patch('similarity_calculator.nltk.download')
    @patch('similarity_calculator.word_tokenize')
    @patch('similarity_calculator.stopwords.words')
    def test_calculate_text_similarity_stopwords_only(self, mock_stopwords, mock_word_tokenize, mock_nltk_download):
        # Using a more complete list of stopwords for the mock, including 'an'
        mock_stopwords.return_value = ['is', 'the', 'a', 'of', 'and', 'to', 'an'] 
        mock_word_tokenize.side_effect = lambda x: nltk.word_tokenize(x) if x else []

        text1 = "is the an a"
        text2 = "of and to"
        # After preprocessing, both texts should become empty.
        score = sc._calculate_text_similarity(text1, text2)
        self.assertEqual(score, 1.0)

    @patch('similarity_calculator.nltk.download')
    @patch('similarity_calculator.word_tokenize')
    @patch('similarity_calculator.stopwords.words')
    def test_calculate_text_similarity_mixed_content(self, mock_stopwords, mock_word_tokenize, mock_nltk_download):
        # This test might need adjustment if it's conflicting with non-mocked tests
        # For now, let's assume it uses the mocked versions correctly
        mock_stopwords.return_value = ['the', 'is', 'a']
        mock_word_tokenize.side_effect = lambda x: nltk.word_tokenize(x) if x else []

        text1 = "The quick brown fox"
        text2 = "The quick brown dog"
        score = sc._calculate_text_similarity(text1, text2)
        self.assertTrue(0.0 <= score < 1.0)

    @patch('similarity_calculator.nltk.download')
    @patch('similarity_calculator.word_tokenize')
    @patch('similarity_calculator.stopwords.words')
    def test_calculate_text_similarity_case_insensitivity(self, mock_stopwords, mock_word_tokenize, mock_nltk_download):
        mock_stopwords.return_value = []
        mock_word_tokenize.side_effect = lambda x: nltk.word_tokenize(x.lower()) if x else []

        text1 = "Hello World"
        text2 = "hello world"
        score = sc._calculate_text_similarity(text1, text2)
        self.assertAlmostEqual(score, 1.0, places=5)

    @patch('similarity_calculator.firestore.client')
    @patch('similarity_calculator._initialize_firebase')
    def test_calculate_similarity_for_quest_no_other_quests(self, mock_init_firebase, mock_firestore_client):
        # Setup mock Firestore
        mock_db = MagicMock()
        mock_firestore_client.return_value = mock_db
        # Ensure fb_db in similarity_calculator is set to the mock_db
        similarity_calculator_module = __import__('similarity_calculator')
        similarity_calculator_module.fb_db = mock_db


        mock_target_quest_doc = MagicMock()
        mock_target_quest_doc.exists = True
        mock_target_quest_doc.to_dict.return_value = {"id": "quest1", "title": "Target Quest", "summary": "Summary of target"}
        
        mock_db.collection.return_value.document.return_value.get.return_value = mock_target_quest_doc
        mock_db.collection.return_value.stream.return_value = [] # No other quests

        result = calculate_similarity_for_quest("quest1")
        self.assertEqual(result, [])
        mock_init_firebase.assert_called_once()


    @patch('similarity_calculator.firestore.client')
    @patch('similarity_calculator._initialize_firebase')
    @patch('similarity_calculator._calculate_field_match_score')
    @patch('similarity_calculator._calculate_text_similarity')
    def test_calculate_similarity_for_quest_full_logic(
        self, mock_text_similarity, mock_field_match_score, mock_init_firebase, mock_firestore_client
    ):
        # Setup mock Firestore
        mock_db = MagicMock()
        mock_firestore_client.return_value = mock_db
        # Ensure fb_db in similarity_calculator is set to the mock_db
        similarity_calculator_module = __import__('similarity_calculator')
        similarity_calculator_module.fb_db = mock_db

        # Target Quest
        mock_target_quest_doc = MagicMock(id="quest1")
        mock_target_quest_doc.exists = True
        target_data = {"id": "quest1", "title": "Target", "summary": "Target Summary", "genre": "Fantasy", "game_system": "SystemA"}
        mock_target_quest_doc.to_dict.return_value = target_data

        # Other Quests
        mock_other_quest1_doc = MagicMock(id="quest2")
        other_data1 = {"id": "quest2", "title": "Other1", "summary": "Other1 Summary", "genre": "Fantasy", "game_system": "SystemB"}
        mock_other_quest1_doc.to_dict.return_value = other_data1
        
        mock_other_quest2_doc = MagicMock(id="quest3")
        other_data2 = {"id": "quest3", "title": "Other2", "summary": "Other2 Summary", "genre": "SciFi", "game_system": "SystemA"}
        mock_other_quest2_doc.to_dict.return_value = other_data2

        # Firestore call setup
        def collection_side_effect(collection_name):
            if collection_name == "questCards":
                mock_collection_ref = MagicMock()
                
                def document_side_effect(doc_id):
                    if doc_id == "quest1":
                        return mock_target_quest_doc_ref # Defined below
                    elif doc_id == "quest2":
                         return mock_other_quest1_doc_ref
                    elif doc_id == "quest3":
                         return mock_other_quest2_doc_ref
                    return MagicMock() # Default mock for other document calls

                mock_doc_ref = MagicMock()
                mock_doc_ref.get.return_value = mock_target_quest_doc # For target quest retrieval
                mock_doc_ref.collection.return_value.document = MagicMock(side_effect=document_side_effect) # For subcollection writes
                mock_doc_ref.collection.return_value.stream.return_value = [] # For clearing subcollection

                mock_target_quest_doc_ref = MagicMock()
                mock_target_quest_doc_ref.get.return_value = mock_target_quest_doc
                mock_target_quest_doc_ref.collection.return_value.document = MagicMock(side_effect=document_side_effect)
                mock_target_quest_doc_ref.collection.return_value.stream.return_value = []


                mock_other_quest1_doc_ref = MagicMock()
                # ... setup for other quest doc refs if needed for subcollection writes ...

                mock_other_quest2_doc_ref = MagicMock()
                # ... setup for other quest doc refs if needed for subcollection writes ...


                mock_collection_ref.document = MagicMock(side_effect=document_side_effect)
                mock_collection_ref.stream.return_value = [mock_other_quest1_doc, mock_other_quest2_doc] # For listing all quests
                return mock_collection_ref
            return MagicMock()

        mock_db.collection.side_effect = collection_side_effect
        mock_db.batch.return_value = MagicMock() # Mock batch operations

        # Mock scores
        mock_field_match_score.side_effect = [0.5, 0.8] # For quest2, quest3 respectively
        mock_text_similarity.side_effect = [0.6, 0.7, 0.4, 0.9] # title1-2, summary1-2, title1-3, summary1-3

        results = calculate_similarity_for_quest("quest1")

        mock_init_firebase.assert_called_once()
        self.assertEqual(mock_field_match_score.call_count, 2)
        self.assertEqual(mock_text_similarity.call_count, 4)
        
        # Expected calculations:
        # Quest2:
        #   field_score = 0.5
        #   text_score_title = 0.6, text_score_summary = 0.7 => combined_text = (0.6+0.7)/2 = 0.65
        #   hybrid_score2 = 0.5 * 0.6 + 0.65 * 0.4 = 0.3 + 0.26 = 0.56
        # Quest3:
        #   field_score = 0.8
        #   text_score_title = 0.4, text_score_summary = 0.9 => combined_text = (0.4+0.9)/2 = 0.65
        #   hybrid_score3 = 0.8 * 0.6 + 0.65 * 0.4 = 0.48 + 0.26 = 0.74

        self.assertEqual(len(results), 2)
        self.assertEqual(results[0]["id"], "quest3") # Higher score
        self.assertAlmostEqual(results[0]["score"], 0.74)
        self.assertEqual(results[1]["id"], "quest2")
        self.assertAlmostEqual(results[1]["score"], 0.56)

        # Verify Firestore writes (batch commit)
        mock_db.batch.return_value.commit.assert_called_once()
        # Check that set was called for each similar quest
        self.assertEqual(mock_db.batch.return_value.set.call_count, 2)


if __name__ == '__main__':
    unittest.main()
