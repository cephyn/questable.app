# Plan: User Profile & Quest Ownership Features

This document outlines the plan for adding user profile management and a quest ownership tracking feature to the Quest Cards application.

**Status:** Implementation In Progress

## 1. Goals

*   Implement a dedicated profile page for authenticated users.
*   Allow users to perform account management actions (password reset, account deletion).
*   Display quests submitted by the user on their profile.
*   Introduce an "I Own This" feature for individual quest cards.
*   Track quest ownership per user.
*   Display a user's owned quests (library) on their profile.
*   Add "Owned" and "Unowned" filtering options to the authenticated quest list view.

## 2. Data Model Changes (Firestore) - Partially Complete

*   **Users Collection (`users`):**
    *   ✅ Confirmed `users` collection exists with appropriate rules (`firestore.rules`).
    *   Store basic profile information if needed (e.g., `email`, `displayName`). (No changes needed yet)
*   **Quest Submissions:**
    *   ✅ Confirmed quest collection is `questCards` (based on `firestore.rules`).
    *   ✅ Confirmed field linking user is `uploadedBy` (based on `firestore.rules`).
*   **Quest Ownership Tracking:**
    *   ✅ Added rules for the new subcollection `users/{userId}/ownedQuests/{questId}` in `firestore.rules` to allow users to manage their own owned quests.
    *   The document `{questId}` within this subcollection will contain `{ ownedAt: FieldValue.serverTimestamp() }` upon creation.

## 3. Authentication Enhancements - Partially Complete

*   **Password Reset:**
    *   Leverage Firebase Authentication's built-in password reset email functionality (`FirebaseAuth.instance.sendPasswordResetEmail`).
    *   Implement UI elements on the profile page (or potentially the login screen) to trigger this. (UI - Step 4)
*   **Account Deletion:**
    *   Use `FirebaseAuth.instance.currentUser.delete()`. (UI - Step 4)
    *   ✅ Implemented Cloud Function (`onUserDelete` in `functions/main.py`) triggered on user deletion (`functions.auth.user().onDelete()`) for data cleanup.
    *   The Cloud Function deletes:
        *   ✅ The user's document in the `users` collection.
        *   ✅ The user's `ownedQuests` subcollection.
        *   ✅ Anonymizes quests submitted by the user by removing or nullifying the `uploadedBy` field.

## 4. UI Implementation - Partially Complete

*   **New Profile Screen (`lib/src/screens/profile_screen.dart`):**
    *   ✅ Created a new stateful widget (`lib/src/screens/profile_screen.dart`).
    *   ✅ Added routing to access this screen (route `/profile` in `main.dart`, button in `QuestCardListView` AppBar).
    *   ✅ Display user information (e.g., email from `FirebaseAuth.instance.currentUser`).
    *   ✅ Add buttons/links for:
        *   ✅ "Reset Password" (triggers `sendPasswordResetEmail`).
        *   ✅ "Delete Account" (shows a confirmation dialog before proceeding, triggers `currentUser.delete()`).
    *   ✅ Fetch and display "My Submissions": Query the `questCards` collection `where('uploadedBy', isEqualTo: currentUser.uid)`. (Implemented with StreamBuilder)
    *   ✅ Fetch and display "My Owned Library": (Implemented with FutureBuilder, includes basic batching)
        1.  Get all document IDs from `users/{userId}/ownedQuests`.
        2.  Query the `questCards` collection using `where(FieldPath.documentId, whereIn: ownedQuestIds)`. Handle potential `whereIn` limitations (currently 30 IDs per query) by batching if necessary.
*   **Quest Card Detail (`lib/src/quest_card/quest_card_details_view.dart`):**
    *   ✅ Conditionally display an "I Own This" `SwitchListTile` *only* if the user is authenticated.
    *   ✅ The initial state of the control reflects whether a document exists in `users/{userId}/ownedQuests/{questId}` (using `StreamBuilder`).
    *   ✅ On change:
        *   ✅ If checked: Add the document `users/{userId}/ownedQuests/{questId}` with `{ ownedAt: FieldValue.serverTimestamp() }`.
        *   ✅ If unchecked: Delete the document `users/{userId}/ownedQuests/{questId}`.
*   **Quest List View Filtering (`lib/src/quest_card/quest_card_list_view.dart` or similar):** ✅ (Complete)
    *   ✅ Added "Owned" and "Unowned" options to the filter UI (`filter_drawer.dart`).
    *   ✅ Modified the data fetching logic (`firestore_service.dart`):
        *   ✅ If "Owned" or "Unowned" filter is active:
            1.  ✅ Fetch the list of `ownedQuestIds` for the current user from `users/{userId}/ownedQuests`.
            2.  ✅ Modify the main `questCards` query:
                *   ✅ For "Owned": Add `where(FieldPath.documentId, whereIn: ownedQuestIds)`. Handle batching if needed.
                *   ✅ For "Unowned": Add `where(FieldPath.documentId, whereNotIn: ownedQuestIds)`. Handle batching if needed.
        *   ✅ If neither filter is active, fetch quests as normal.
        *   ✅ Considered performance implications and potential need for client-side filtering if `whereIn`/`whereNotIn` becomes too complex or slow, especially in combination with other filters.

## 5. Backend Implementation (Cloud Functions) - Partially Complete

*   **`onUserDelete` Function (`functions/main.py` or similar):**
    *   ✅ Trigger: `functions.auth.user().onDelete()`
    *   ✅ Purpose: Clean up associated Firestore data (user profile, owned quests) and anonymize submitted quests by removing/nullifying `uploadedBy`.

## 6. State Management - Complete

*   ✅ Created `AuthProvider` (`lib/src/providers/auth_provider.dart`) to listen to `FirebaseAuth.instance.authStateChanges()` and provide `currentUser`, `isAuthenticated`, and `isLoading` status.
*   ✅ Integrated `AuthProvider` into `main.dart` using `MultiProvider`.
*   ✅ Used `AuthProvider` in `QuestCardListView` to conditionally show profile button, edit, and delete buttons.
*   ✅ Used `AuthProvider` in `QuestCardDetailsView` to conditionally show the edit button and the "I Own This" switch.
*   ✅ Implemented route guard for `/profile` in `main.dart` using `GoRouter`'s redirect functionality and `AuthProvider.isAuthenticated`.
*   ✅ Created `UserService` (`lib/src/services/user_service.dart`) to handle Firestore operations related to user profile data (submitted and owned quests).
*   ✅ Refactored `ProfileScreen` to use `AuthProvider` for user state and `UserService` for data fetching.
*   ✅ Refactored `QuestCardDetailsView` to use `UserService` for ownership state and actions.
*   **To Do (Profile Data Management):**
    *   Consider more advanced state management for profile data (submitted/owned quests) if needed, e.g., caching fetched data in a `ProfileProvider` or within `AuthProvider` to reduce Firestore reads if `ProfileScreen` is visited frequently. For now, `ProfileScreen` fetches directly using `UserService`.

## 7. File Structure Suggestions

*   `lib/src/screens/profile_screen.dart` (✅ Created)
*   `lib/src/providers/auth_provider.dart` (✅ Created)
*   `lib/src/services/user_service.dart` (✅ Created - New service for profile, ownership, submissions)
*   `lib/src/providers/` or `lib/src/blocs/` (Consider for future: `ProfileProvider` for caching profile data - see "To Do" in State Management)
*   `lib/src/widgets/quest_card_detail.dart` (✅ Modified)
*   `lib/src/widgets/quest_list_view.dart` (✅ Modified)
*   `lib/src/widgets/filter_controls.dart` (✅ Modified)
*   `functions/main.py` (✅ Modified)

## 8. Open Questions & Considerations

*   **Filtering Performance:** The `whereIn`/`whereNotIn` approach for ownership filtering might hit limits or be slow with many owned items or combined with other complex filters. Monitor performance and consider client-side filtering as a fallback if needed.
*   **UI/UX:** Ensure clear feedback during operations (saving ownership, deleting account, sending reset email). Use loading indicators appropriately.
*   **Error Handling:** Implement robust error handling for all Firestore and Auth operations.
*   **Backfilling:** If `uploadedBy` is not currently tracked on all relevant `questCards` documents, decide if backfilling historical data is necessary/feasible.
