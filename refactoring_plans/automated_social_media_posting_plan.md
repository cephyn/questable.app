# Automated Social Media Posting for Quest Cards Feature Plan

## 1. Overview

This document outlines the plan for implementing an automated feature that selects quest cards from the application and posts them to various social media platforms. The goal is to increase engagement, drive traffic to the application, and showcase the variety of quests available. The system will initially support Bluesky, with future phases incorporating X (formerly Twitter), Instagram, and Threads.net.

## 2. Goals

*   Automate the process of sharing quest cards on social media.
*   Increase visibility and discovery of quest cards.
*   Drive user engagement and traffic to the application.
*   Provide a consistent social media presence.
*   Start with Bluesky integration and expand to other platforms (X, Instagram, Threads.net) in subsequent phases.

## 3. Scope

### In Scope (Phased Approach):

*   **Quest Selection**:
    *   Randomly selecting a public quest card twice a day.
    *   Eligibility: Must be public and have key fields populated (system, standardized game system, title, product title, summary, genre).
    *   Can be re-featured, no cooldown period necessary for now.
    *   Pure random selection initially; algorithmic selection is a future goal.
*   **Content Generation**:
    *   Extracting quest name, product name (from quest card field), and standardized game system.
    *   Generating related hashtags for the game system and genre.
    *   Creating a dynamic, compelling text snippet for the post:
        *   Randomly chosen tone appropriate to the quest's genre and summary.
        *   Combination of a predefined template and AI/LLM (Gemini) generated text.
    *   Generating a direct link to the quest card within the application (existing web feature, future mobile).
    *   Randomly selecting a Call to Action from a predefined list.
*   **Image Handling**:
    *   Attempting to find/use an existing image (future goal for quest cards).
    *   Sourcing images from royalty-free stock photo sites, game system logos, or product cover images. No "R" or "Adult" rated images.
    *   Fallback: Game system logo or Questable logo if no suitable image is found.
*   **Social Media Posting**:
    *   Phase 1: Posting to Bluesky.
    *   Phase 2: Adding posting capabilities for X.
    *   Phase 3: Adding posting capabilities for Instagram.
    *   Phase 4: Adding posting capabilities for Threads.net.
*   **Scheduling**: Implementing a twice-daily automated posting schedule using Firebase Scheduled Functions.
*   **Configuration**: API keys managed via Firebase Remote Config.
*   **Logging & Error Handling**:
    *   Tracking successful posts, failures, and API responses (especially errors).
    *   Email notifications to an admin for failures or errors.
    *   Log errors if a post fails on one platform but succeeds on others.
*   **Admin Review**:
    *   (Potential Future Feature) Admin tool within the application for manual review/approval of posts, with an option to toggle to full automation.

### Out of Scope (Initially, but potential future enhancements):

*   Advanced AI-driven image generation if no suitable image is found (beyond specified sourcing).
*   Complex sentiment analysis for tailoring post text.
*   User interaction management (responding to comments, DMs) via this automated system.
*   A/B testing of post formats through this system.
*   Detailed analytics dashboard for post performance (beyond specified logging).
*   ~~Manual approval workflow for every post (though this might be a question for clarification).~~ (Addressed by admin tool)

## 4. Phased Implementation Plan

### Phase 1: MVP - Core Logic & Bluesky Integration

*   **Quest Selection**:
    *   `[X]` Develop a Firebase Function to randomly select a public quest card from Firestore.
    *   `[X]` Eligibility criteria: Must be public, and have key fields populated (system, standardized game system, title, product title, summary, genre).
*   **Content Generation (MVP)**:
    *   `[X]` Extract quest name, product name, standardized game system, and genre from the quest card.
    *   `[X]` Generate game system and genre-specific hashtags.
    *   `[X]` Implement a template-based system for the structured portion of the post text.
    *   `[X]` Construct a direct deep link to the quest card.
    *   `[X]` Randomly select a Call to Action from a predefined list.
*   **Bluesky Integration**:
    *   `[X]` Implement API client for Bluesky within a Firebase Function.
    *   `[X]` Handle authentication (API keys from Google Cloud Secret Manager) and posting.
*   **Scheduling**:
    *   `[X]` Set up a Firebase Scheduled Function to trigger the posting process twice a day (10 AM & 7 PM).
*   **Configuration**:
    *   `[X]` Store Bluesky API credentials in Google Cloud Secret Manager (retrieval implemented).
*   **Logging**:
    *   `[X]` Basic logging for successful posts and errors to Firebase Logging. (Selection, posting success/errors to Firestore `social_post_logs`)
*   **AI Text Generation (Stretch Goal for MVP, otherwise Phase 1.5)**:
    *   `[X]` Integrate Gemini to generate a dynamic, compelling text snippet based on quest genre and summary, to be appended to the template-based text.
*   **Image Handling (Post-MVP / Phase 2)**:
    *   `[X]` Initially, post to Bluesky without an image. (Explicitly no image handling in this phase, text-only posts with link embeds).

### Phase 2: Platform Expansion (X), AI Text & Basic Image Handling

*   **AI Text Generation (If not in MVP)**:
    *   Fully implement and test Gemini integration for dynamic text generation.
*   **Image Handling (Basic)**:
    *   Implement logic to search for an existing image URL in quest card data (once field is available).
    *   If no image, attempt to find a game system logo or Questable logo as a fallback.
    *   Integrate image uploading with Bluesky posts.
*   **X Integration**:
    *   `[/]` Implement API client for X within a Firebase Function.
    *   `[/]` Adapt post content (text length, image handling) for X's requirements.
    *   `[X]` Store X API credentials in Google Cloud Secret Manager.
*   **Content Generation Enhancements**:
    *   Refine text generation templates and AI prompts.
*   **Error Handling**:
    *   Improve error handling and retry logic for posting across platforms. Log errors per platform.

### Phase 3: Advanced Image Sourcing, Instagram Integration & Admin Tools

*   **Advanced Image Sourcing**:
    *   Implement sourcing of appropriate images from royalty-free stock photo sites (e.g., via API) or product cover images, adhering to content restrictions.
    *   Refine fallback logic (game system logo, Questable logo).
*   **Instagram Integration**:
    *   Implement API client for Instagram within a Firebase Function.
    *   Focus on image-centric posts, potentially requiring specific image aspect ratios or types.
    *   Store Instagram API credentials in Google Cloud Secret Manager.
*   **Admin Review Tool (Potential Feature)**:
    *   Develop a simple admin interface in the application to review scheduled/generated posts.
    *   Allow manual approval or edits before posting.
    *   Implement a toggle for full automation vs. manual review mode.
*   **Monitoring & Analytics**:
    *   Implement more detailed monitoring and alerts.
*   **Refinement**:
    *   Based on performance and feedback, refine quest selection logic (e.g., consider weighted randomness if pure random isn't ideal).

### Phase 4: Threads.net Integration

*   **Objective**: Extend social media integration to include posting to Threads.net.
*   **Research & API Setup**:
    *   Investigate the Threads.net API for automated posting capabilities. Refer to official documentation: https://developers.facebook.com/docs/threads/posts
    *   Set up any necessary developer accounts and obtain API keys/tokens.
    *   Securely store API credentials in Google Cloud Secret Manager.
*   **Implementation**:
    *   Develop a new Firebase Function or extend existing ones to handle posting to Threads.net.
    *   Adapt content generation (text length, image/video requirements, link handling) for Threads.net specific formats and best practices.
    *   Implement authentication and posting logic using the Threads.net API.
*   **Image/Video Handling**:
    *   Determine image and video requirements for Threads.net posts.
    *   Integrate image/video uploading capabilities, leveraging existing image sourcing logic from Phase 2 & 3 where applicable.
*   **Logging & Error Handling**:
    *   Extend logging to include posts made to Threads.net (success, failures, API responses).
    *   Update error handling and notification mechanisms to cover Threads.net integration.
*   **Testing**:
    *   Thoroughly test posting to Threads.net, including various content types (text, image, video if supported/planned).
    *   Verify link functionality and overall post appearance.

## 5. Key Feature Components & Technical Considerations

*   **Quest Card Selection Module (Firebase Function)**:
    *   Needs secure access to Firestore.
    *   Logic for random selection and eligibility (public, required fields: system, standardized game system, title, product title, summary, genre).
*   **Content Generation Engine (Firebase Function)**:
    *   **Text**: Combination of predefined templates and AI/LLM (Gemini, existing integration) for dynamic text. Needs access to quest details (genre, summary for tone).
    *   **Image**: Logic to retrieve existing image URLs (future). Image sourcing from royalty-free sites, game system logos, product covers. Fallback to game system or Questable logo. No "R" or "Adult" images.
    *   **Hashtags**: Mapping game systems to hashtags (to be developed), include genre hashtags.
    *   **Links**: Deep link generation (existing web, future mobile).
    *   **Call to Action**: Random selection from a predefined list.
*   **Social Media Posting Module (Firebase Functions)**:
    *   Separate clients/SDKs for Bluesky, X, Instagram, Threads.net, managed within Firebase Functions.
    *   Handling of authentication (API keys from Google Cloud Secret Manager), rate limits, error responses for each platform.
    *   Formatting content according to each platform's best practices.
*   **Scheduling & Execution Environment**:
    *   Firebase Scheduled Functions for twice-daily execution.
    *   Firebase Functions for the core logic (selection, generation, posting).
*   **Direct Linking Mechanism**:
    *   Utilize existing deep linking for web; plan for mobile deep linking.
*   **Configuration Management**:
    *   Secure storage for API keys (Bluesky, X, Instagram, Threads.net) and other settings using Google Cloud Secret Manager.
*   **Logging, Monitoring, and Error Handling**:
    *   Structured logging to Firebase Logging (success/failure, API responses, errors).
    *   Email alerts to admin for critical failures or errors.
    *   Graceful handling of API errors, network issues. Log errors per platform if multi-platform posting fails partially.

## 6. Open Questions for Clarification

**Answers based on user feedback incorporated above. This section can be streamlined or removed if all points are now considered resolved within the plan.**

1.  **Quest Selection Criteria**:
    *   **Resolved**: Must be public; key fields (system, standardized game system, title, product title, summary, genre) populated. Can be re-featured, no cooldown. Pure random for now.

2.  **Content Generation - Text**:
    *   **Resolved**: Tone randomly chosen based on genre/summary. Predefined template + Gemini AI for dynamic text.

3.  **Content Generation - Image**:
    *   **Resolved**: No current images on quest cards. Future sources: royalty-free stock, game system logos, product covers. No "R"/"Adult". Fallback: game system/Questable logo.

4.  **Social Media Post Details**:
    *   **Resolved**: Product name is a field in quest card. No master hashtag list yet; include game system & genre. Direct link exists. Create list of CTAs and pick randomly.

5.  **Technical Implementation**:
    *   **Resolved**: Firebase Scheduled Functions and Firebase Functions. API keys via Google Cloud Secret Manager. Rate limits TBD.

6.  **Operational Considerations**:
    *   **Resolved**: Admin tool for review/approval (with full auto toggle) is a good idea. Log success/failure, API responses. Email admin on errors. Log partial failures. Ineligible if missing data.

7.  **Prioritization for Initial Phase (Bluesky) MVP**:
    *   **Resolved**:
        *   **Core MVP**: Scheduled posting, quest data for structured post (template), direct link, Call to Action.
        *   **Next Priority**: AI-generated text (Gemini).
        *   **Last Priority for MVP/Early Phase 2**: Image inclusion.

## 7. Success Criteria

*   The system reliably posts to Bluesky (and later X, Instagram, Threads.net) twice a day.
*   Posts contain accurate quest information (name, system, link).
*   Posts include compelling text (template + AI) and, where possible/implemented, an appropriate image.
*   The system operates autonomously (or via admin approval) with minimal manual intervention.
*   Direct links in posts correctly navigate to the specific quest card in the application.
*   Basic logging confirms system operation and captures critical errors.

## 8. Future Considerations

*   User-configurable posting frequency or specific times.
*   Ability to manually trigger a post for a specific quest.
*   Tracking click-through rates or engagement metrics from posts.
*   Allowing users to opt-in their quests for featuring.
*   Theming posts based on special events or holidays.
*   Support for other social media platforms.
*   Admin interface for managing featured quests, reviewing posts, and configuring settings.
*   Development of a master list for game system hashtags.
*   Algorithm for weighted random quest selection.
