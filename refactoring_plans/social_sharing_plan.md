# Development Plan: Quest Card Social Sharing

**Goal:** Allow users to share a direct link to a specific `quest_card_details_view` on social media platforms (Twitter, Bluesky, Mastodon) and via a generic "Copy Link" option.

**Date:** May 4, 2025

---

## Phase 1: Routing Setup & Deep Linking (Completed)

1.  **Add Routing Package:** ✅
    *   Added the `go_router` package to `pubspec.yaml`.
    *   Ran `flutter pub get`.

2.  **Configure `go_router`:** ✅
    *   Modified `lib/main.dart` to initialize and use `GoRouter`.
    *   Defined application routes: `/` and `/quests/:questId`.
    *   Updated `MyApp` in `lib/src/app.dart` to use `MaterialApp.router`.

3.  **Update Navigation:** ✅
    *   Refactored navigation in `QuestCardListView` to use `context.go('/quests/$questId')`.
    *   `QuestCardDetailsView` now receives `questId` via `GoRouterState`.

4.  **Configure Firebase Hosting:** ✅
    *   Modified `firebase.json` to include rewrite rules for SPA behavior.
    *   *Note: Deployment (`firebase deploy --only hosting`) should be done manually after testing.*

5.  **Initial Testing:** ✅ (Manual testing completed)
    *   Verify direct URL navigation (`https://<your-app-url>/quests/<some-quest-id>`).
    *   Test in-app navigation.

---

## Phase 2: Share Button & Logic Implementation

1.  **Add Sharing Package:** ✅
    *   Added the `share_plus` package to `pubspec.yaml`.
    *   Ran `flutter pub get`.

2.  **Add Share UI Element:** ✅ (Initial implementation)
    *   In the `quest_card_details_view` widget, added an `IconButton` (using `Icons.share`) in the `AppBar`'s actions.

3.  **Implement Share Action:** ✅ (Basic implementation using `Share.share`)
    *   When the share button is tapped:
        *   Constructed the full, shareable URL using a constant from `app_constants.dart`. ✅
        *   Fetched the current quest's title. ✅
        *   Constructed the default share text: e.g., "Check out this quest: [Quest Title] - [Shareable URL]". ✅
        *   Called `Share.share()` to use the OS share sheet. ✅
        *   *Next steps: Implement specific platform options/modal if needed.*

4.  **Implement Sharing Options:** ✅ (Custom Modal Implemented)
    *   Created `share_options_modal.dart` widget. ✅
    *   Modified `_shareQuest` in `quest_card_details_view.dart` to call `showModalBottomSheet` with the custom widget. ✅
    *   **Twitter:** Implemented sharing via Twitter Web Intent URL (`https://twitter.com/intent/tweet?...`). ✅
    *   **Bluesky:** Implemented sharing via Bluesky Web Intent URL (`https://bsky.app/intent/compose?...`). ✅
    *   **Mastodon:** Deferred (Using "More Options..." fallback to system share sheet for now).
    *   **Copy Link:** Implemented using `Clipboard.setData` with `SnackBar` feedback. ✅
    *   Analytics logging for specific platform choices added within the modal. ✅

5.  **Refine UI/UX:** (Partially addressed)
    *   Implemented a modal bottom sheet for sharing options instead of relying solely on the OS default. ✅
    *   Used `simple_icons` for Twitter (X) and Bluesky icons. ✅
    *   Ensure the share button is easily accessible and understandable. (No change here)
    *   Extracted base URL to `app_constants.dart`. ✅

6.  **Add Analytics:** ✅ (Refined)
    *   Added the `firebase_analytics` package to `pubspec.yaml`. ✅
    *   Ran `flutter pub get`. ✅
    *   Ensured Firebase Analytics is initialized in `lib/main.dart`. ✅
    *   In the share button's action handler:
        *   Logged `share_quest_initiated` event before showing modal. ✅
        *   Moved `share_quest_platform` event logging into the modal for specific platform tracking (copy_link, twitter, bluesky, system_share_sheet). ✅
        *   Logged share initiation errors. ✅
        *   Modal handles logging for its specific actions. ✅

---

## Phase 3: Testing & Refinement

1.  **Comprehensive Testing:** (Next Step)
    *   Test sharing via the system share sheet on web builds.
    *   Verify the "Copy Link" functionality works correctly (if available in the system sheet).
    *   Test on different browsers (Chrome, Firefox, Safari).
    *   Ensure the shared links correctly open the specific quest details page.
    *   Check how links appear when pasted (link previews/unfurling).
    *   Verify analytics events are logged in Firebase console.

2.  **Code Review & Cleanup:** (Partially addressed)
    *   Review code for clarity, efficiency, and adherence to best practices.
    *   Add comments where necessary.
    *   Extracted base URL to configuration. ✅

---

## Future Considerations

*   **URL Shortening:** Investigate integrating a URL shortening service if links become too long or for analytics. Note that Firebase Dynamic Links is being deprecated, so alternatives like Bitly (free tier), TinyURL, or self-hosted solutions (like Shlink) would need evaluation.
*   **Platform-Specific Enhancements:** Explore more direct integrations if `share_plus` limitations are encountered or richer sharing previews are desired (might require platform-specific code or backend functions). Implement custom share modal/dialog with specific platform buttons (Twitter, Bluesky, Copy Link).
*   **Mastodon Instance Input:** If direct Mastodon sharing is highly desired, consider adding a feature where users can input their preferred instance URL.
*   **Analytics:** Refine platform-specific analytics tracking.

---
