import unittest
from unittest.mock import MagicMock, patch

import main

class TestSyncUploaderEmail(unittest.TestCase):

    @patch('main.firestore')
    def test_sync_updates_when_missing(self, mock_firestore):
        # Setup event with 'after' snapshot
        quest_id = 'quest1'
        after_snapshot = MagicMock()
        after_snapshot.to_dict.return_value = {'uploadedBy': 'user123'}

        change = MagicMock()
        change.after = after_snapshot

        event = MagicMock()
        event.params = {'questId': quest_id}
        event.data = change

        # Mock user doc with email
        mock_user_doc = MagicMock()
        mock_user_doc.exists = True
        mock_user_doc.to_dict.return_value = {'email': 'u@example.com'}

        # Mock Firestore client behavior
        mock_client = MagicMock()
        mock_firestore.client.return_value = mock_client
        mock_client.collection.return_value.document.return_value.get.return_value = mock_user_doc

        # Call the trigger (call original function to avoid CloudEvent wrapper)
        main.sync_uploader_email.__wrapped__(event)

        # Expect update called on quest document
        mock_client.collection.assert_any_call('questCards')
        mock_client.collection('questCards').document.assert_called_with(quest_id)
        mock_client.collection('questCards').document(quest_id).update.assert_called_with({'uploaderEmail': 'u@example.com'})

    @patch('main.firestore')
    def test_no_update_when_email_present_or_no_uploadedBy(self, mock_firestore):
        quest_id = 'quest2'
        # Case 1: uploaderEmail present
        after_snapshot = MagicMock()
        after_snapshot.to_dict.return_value = {'uploadedBy': 'user123', 'uploaderEmail': 'already@example.com'}
        change = MagicMock()
        change.after = after_snapshot
        event = MagicMock()
        event.params = {'questId': quest_id}
        event.data = change

        mock_client = MagicMock()
        mock_firestore.client.return_value = mock_client

        main.sync_uploader_email.__wrapped__(event)
        # update should not be called
        mock_client.collection('questCards').document.assert_not_called()

        # Case 2: no uploadedBy
        after_snapshot2 = MagicMock()
        after_snapshot2.to_dict.return_value = {}
        change2 = MagicMock()
        change2.after = after_snapshot2
        event2 = MagicMock()
        event2.params = {'questId': quest_id}
        event2.data = change2

        main.sync_uploader_email.__wrapped__(event2)
        mock_client.collection('questCards').document.assert_not_called()

if __name__ == '__main__':
    unittest.main()
