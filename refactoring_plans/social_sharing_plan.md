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

5.  **Initial Testing:** (Requires manual testing after deployment)
    *   Verify direct URL navigation (`https://<your-app-url>/quests/<some-quest-id>`).
    *   Test in-app navigation.

---

## Phase 2: Share Button & Logic Implementation

1.  **Add Sharing Package:**
    *   Add the `share_plus` package to `pubspec.yaml`.
    *   Run `flutter pub get`.

2.  **Add Share UI Element:**
    *   In the `quest_card_details_view` widget, add an `IconButton` (e.g., using `Icons.share`) in a suitable location (like the `AppBar`'s actions).

3.  **Implement Share Action:**
    *   When the share button is tapped:
        *   Construct the full, shareable URL: `https://<your-app-url>/quests/<current-quest-id>`.
        *   Fetch the current quest's title.
        *   Construct the default share text: e.g., "Check out this quest: [Quest Title] - [Shareable URL]".
        *   Present sharing options (potentially using a modal bottom sheet or dialog for better UX).

4.  **Implement Sharing Options:**
    *   **Twitter:** Use `share_plus` or construct a Twitter Web Intent URL (`https://twitter.com/intent/tweet?text=[Encoded Text]&url=[Encoded URL]`).
    *   **Bluesky:** Construct a Bluesky Web Intent URL (`https://bsky.app/intent/compose?text=[Encoded Text and URL]`).
    *   **Mastodon:** Use `share_plus`'s generic share functionality. *Note: Direct instance sharing is complex; a generic share intent is more feasible initially.*
    *   **Copy Link:** Use `Clipboard.setData(ClipboardData(text: shareableUrl))` (available via `flutter/services.dart`) possibly wrapped by `share_plus`. Provide user feedback (e.g., a Snackbar) confirming the link was copied.

5.  **Refine UI/UX:**
    *   Ensure the share button is easily accessible and understandable.
    *   Make the sharing option presentation (dialog/sheet) clean and platform-consistent.

6.  **Add Analytics:**
    *   Add the `firebase_analytics` package to `pubspec.yaml`.
    *   Run `flutter pub get`.
    *   Ensure Firebase Analytics is initialized in `lib/main.dart`.
    *   In the share button's action handler:
        *   Log a general share event: `FirebaseAnalytics.instance.logEvent(name: 'share_quest_initiated', parameters: {'quest_id': currentQuestId});`
        *   When a specific platform is chosen (e.g., Twitter, Copy Link), log a more specific event: `FirebaseAnalytics.instance.logEvent(name: 'share_quest_platform', parameters: {'quest_id': currentQuestId, 'platform': 'twitter'});` (Replace 'twitter' with the actual platform chosen).

---

## Phase 3: Testing & Refinement

1.  **Comprehensive Testing:**
    *   Test sharing to each platform (Twitter, Bluesky, generic share for Mastodon) on web builds.
    *   Verify the "Copy Link" functionality works correctly.
    *   Test on different browsers (Chrome, Firefox, Safari).
    *   Ensure the shared links correctly open the specific quest details page.
    *   Check how links appear when pasted (link previews/unfurling).

2.  **Code Review & Cleanup:**
    *   Review code for clarity, efficiency, and adherence to best practices.
    *   Add comments where necessary.

---

## Future Considerations

*   **URL Shortening:** Investigate integrating a URL shortening service if links become too long or for analytics. Note that Firebase Dynamic Links is being deprecated, so alternatives like Bitly (free tier), TinyURL, or self-hosted solutions (like Shlink) would need evaluation.
*   **Platform-Specific Enhancements:** Explore more direct integrations if `share_plus` limitations are encountered or richer sharing previews are desired (might require platform-specific code or backend functions).
*   **Mastodon Instance Input:** If direct Mastodon sharing is highly desired, consider adding a feature where users can input their preferred instance URL.
*   **Analytics:** Track share button usage.

---
