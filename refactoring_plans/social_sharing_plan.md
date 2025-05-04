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

## Phase 3: Server-Side Rendering for Link Previews (New)

**Goal:** Improve link unfurling/previews on social media by dynamically injecting meta tags.

1.  **Update Cloud Function (`functions/main.py`):**
    *   Add necessary imports (e.g., `firebase_admin`, `google.cloud.firestore`, `flask`).
    *   Ensure Firebase Admin SDK is initialized.
    *   Create or modify an HTTP function to handle requests.
    *   Intercept requests for paths matching `/quests/<questId>`.
    *   Extract the `questId` from the request path.
    *   Connect to Firestore and fetch the quest document using the `questId`.
    *   If the quest exists:
        *   Read the base `index.html` file content (from `../build/web/index.html` relative to the function).
        *   Extract relevant data (title, summary) from the quest document.
        *   Construct meta tags (Open Graph: `og:title`, `og:description`, `og:url`, `og:type`, `og:image` [optional]; Twitter Card: `twitter:card`, `twitter:title`, `twitter:description`, `twitter:image` [optional]).
        *   Inject these meta tags into the `<head>` section of the `index.html` content.
        *   Return the modified HTML content with a `Content-Type: text/html` header.
    *   If the quest doesn't exist or an error occurs, fall back to serving the original `index.html` or an appropriate error response.

2.  **Update Firebase Hosting (`firebase.json`):**
    *   Modify the `hosting.rewrites` section.
    *   Add a rewrite rule to direct requests matching the pattern `/quests/**` to the Cloud Function created/updated in step 1.
    *   Ensure the existing rewrite `{"source": "**", "destination": "/index.html"}` remains but is ordered *after* the function rewrite, acting as a fallback for non-quest URLs.

3.  **Deploy Function & Hosting:**
    *   Run `firebase deploy --only functions,hosting` to deploy the updated Cloud Function and hosting configuration.

4.  **Test Link Unfurling:**
    *   Use social media debuggers (e.g., Twitter Card Validator, Facebook Sharing Debugger) with a quest URL (`https://questable.app/quests/<questId>`).
    *   Verify that the preview shows the correct title, description, and image (if configured).
    *   Paste a quest link into a test post on relevant platforms to see the live preview.

---

## Phase 4: Testing & Refinement (Previously Phase 3)

1.  **Comprehensive Testing:** (Partially done, continue after SSR)
    *   Test sharing via the custom modal and system share sheet fallback on web builds.
    *   Verify the "Copy Link" functionality works correctly.
    *   Test on different browsers (Chrome, Firefox, Safari).
    *   Ensure the shared links correctly open the specific quest details page.
    *   Re-verify link previews after SSR implementation. ✅
    *   Verify analytics events (initiation, platform choice, errors) are logged correctly in the Firebase console.

2.  **Code Review & Cleanup:** (Ongoing)
    *   Review code (Flutter, Python function) for clarity, efficiency, and adherence to best practices.
    *   Add comments where necessary.
    *   Ensure error handling is robust (Firestore fetch, HTML injection, URL launching).
    *   Consider edge cases (missing quest data, invalid URLs).

---

## Future Considerations

*   **URL Shortening:** Investigate integrating a URL shortening service if links become too long or for analytics. Note that Firebase Dynamic Links is being deprecated, so alternatives like Bitly (free tier), TinyURL, or self-hosted solutions (like Shlink) would need evaluation.
*   **Platform-Specific Enhancements:** Explore more direct integrations if `share_plus` limitations are encountered or richer sharing previews are desired (might require platform-specific code or backend functions). Implement custom share modal/dialog with specific platform buttons (Twitter, Bluesky, Copy Link).
*   **Mastodon Instance Input:** If direct Mastodon sharing is highly desired, consider adding a feature where users can input their preferred instance URL.
*   **Analytics:** Refine platform-specific analytics tracking.

---
