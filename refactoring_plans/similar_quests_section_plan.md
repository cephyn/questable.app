# Plan for Adding "Similar Quests" Section to Quest Card Detail View

## 1. Overview

This document outlines the plan for implementing a "Similar Quests" section on the quest card detail view. The feature will display preview cards for similar adventures in the database, along with a similarity score for each quest. The goal is to enhance user engagement by encouraging exploration of related quests.

## 2. Goals

* Provide users with recommendations for similar quests.
* Increase user engagement and time spent on the platform.
* Showcase the variety of quests available in the database.

## 3. Scope

### In Scope:

* **Similarity Score Calculation**:
    * Propose multiple methods for deriving similarity scores.
    * Display similarity scores alongside each recommended quest.
* **UI/UX Design**:
    * Add a "Similar Quests" section to the quest card detail view.
    * Display preview cards for similar quests, including quest name, genre, and similarity score.
* **Backend Integration**:
    * Query the database for similar quests based on the selected similarity calculation method.
    * Ensure efficient querying and data retrieval.

### Out of Scope (Initially):

* Advanced machine learning models for similarity calculation.
* User-configurable similarity criteria.
* A/B testing of recommendation algorithms.
* Analytics for tracking user interaction with the "Similar Quests" section.

## 4. Similarity Score Calculation Methods

### Option 1: Field Matching

* Compare key fields such as genre, game system, and tags.
* Assign weights to each field based on importance (e.g., genre: 50%, game system: 30%, tags: 20%).
* Calculate a weighted similarity score.

### Option 2: Text Similarity

* Use natural language processing (NLP) techniques to compare quest summaries and titles.
* Calculate similarity using algorithms like cosine similarity or Jaccard index.
* Requires preprocessing of text data (e.g., tokenization, stopword removal).

### Option 3: Collaborative Filtering (Future Enhancement)

* Analyze user interactions (e.g., views, likes) to recommend quests that similar users have engaged with.
* Requires sufficient user interaction data.

### Option 4: Hybrid Approach

* Combine field matching and text similarity for a more comprehensive score.
* Normalize scores from each method and calculate a weighted average.
* Use key fields such as game system, genre, common monsters, environment, and summary for field matching.
* Apply natural language processing (NLP) techniques to compare quest summaries and titles for text similarity.
* Collaborative filtering is not necessary for this implementation.

## 5. UI/UX Design

* Add a "Similar Quests" section below the main quest details.
* Display up to 5 preview cards for similar quests.
* Each preview card should include:
    * Quest name
    * Genre
    * Similarity score (e.g., "87% similar")
* Include a "View More" button to navigate to a full list of similar quests.

## 6. Backend Integration

* **Database Query**:
    * Implement a query to retrieve similar quests based on the selected similarity calculation method.
    * Ensure the query is optimized for performance.
* **API Endpoint**:
    * Create a new API endpoint to fetch similar quests for a given quest ID.
    * Include similarity scores in the API response.

## 7. Technical Considerations

* **Data Storage**:
    * Ensure all necessary fields (e.g., genre, tags, summary) are indexed in the database for efficient querying.
* **Scalability**:
    * Design the system to handle a growing database of quests.
* **Error Handling**:
    * Handle cases where no similar quests are found.
    * Provide fallback recommendations (e.g., popular quests).

## 8. Open Questions for Clarification

1. **Resolved**: Similarity scores should be pre-computed at the time the quest is first uploaded and created in the system. These results should be cached with a timestamp. In the future, a re-compute backend function can be implemented to recompute quests with "stale" similar quest data. The definition of "stale" will be determined in a future development iteration.
2. **Resolved**: The most important fields for similarity calculation are game system, genre, common monsters, environment, and summary.
3. **Resolved**: The "Similar Quests" section should be included in all iterations of the system (web and mobile).
4. **Resolved**: The similarity score display format should be a percentage initially.
5. **Resolved**: A "View More" button is not necessary. The similar quests list should display no more than 10 quests.

## 9. Success Criteria

* The "Similar Quests" section is displayed on the quest card detail view.
* Similar quests are accurately recommended based on the selected calculation method.
* The system performs efficiently, even with a large database of quests.
* Users interact with the "Similar Quests" section, as measured by click-through rates.
* Similarity scores are pre-computed and cached with a timestamp, ensuring efficient retrieval.
* The list of similar quests is limited to 10 entries, displayed with percentage-based similarity scores.

## 10. Implementation Phases

### Phase 1: Backend Development - Similarity Calculation and API Endpoint

*   **Task 1.1: Finalize Similarity Algorithm.**
    *   **Status: Completed**
    *   Based on "Option 4: Hybrid Approach", defined initial specific weights for field matching (game system, genre, common monsters, environment) and text similarity (summaries and titles) in `functions/similarity_calculator.py`.
    *   Implemented NLP for text similarity (tokenization, stopword removal, TF-IDF, cosine similarity) using `nltk` and `scikit-learn` in `_calculate_text_similarity` function within `functions/similarity_calculator.py`.
    *   Added `nltk` and `scikit-learn` to `functions/requirements.txt`.
*   **Task 1.2: Implement Similarity Score Calculation Logic.**
    *   **Status: In Progress**
    *   Developed a script (`functions/similarity_calculator.py`) that takes a quest ID as input.
    *   Implemented logic for calculating field matching and text similarity scores (using the now enhanced `_calculate_text_similarity`), and combining them using the hybrid approach.
    *   Currently integrating Firebase Firestore for actual data retrieval in `calculate_similarity_for_quest` (replacing placeholder data).
    *   TODO: Finalize Firebase integration and test data retrieval.
    *   TODO: Determine and implement storage for pre-computed similarity scores (e.g., a separate collection or adding to existing quest documents).
*   **Task 1.3: Develop Pre-computation Mechanism.**
    *   **Status: Not Started**
    *   Create a mechanism to run the similarity score calculation for all new quests upon creation/upload.
    *   Store the results along with a timestamp.
*   **Task 1.4: Backend Unit & Integration Testing.**
    *   **Status: Not Started**
    *   Write unit tests for the similarity calculation logic.
    *   Write integration tests for the API endpoint (if developed in the future).

### Phase 2: Frontend Development - UI/UX Implementation

*   **Task 2.1: Design Quest Preview Card Component.**
    *   If not already existing, create a reusable UI component for a quest preview card that displays:
        *   Quest name
        *   Genre
        *   Similarity score (e.g., "87% similar")
*   **Task 2.2: Implement "Similar Quests" Section in Detail View.**
    *   Add a new section titled "Similar Quests" below the main quest details in the quest card detail view.
    *   On loading the quest detail view, call the new API endpoint to fetch similar quests.
    *   Display up to 10 similar quest preview cards in this section.
    *   Handle loading states (e.g., shimmer/skeleton loaders while fetching data).
    *   Handle the case where no similar quests are found (e.g., display a message like "No similar quests found yet!").
*   **Task 2.3: Styling and Responsiveness.**
    *   Ensure the "Similar Quests" section and preview cards are styled according to the application's design guidelines.
    *   Ensure the layout is responsive across different screen sizes (web and mobile).
*   **Task 2.4: Frontend Unit & Component Testing.**
    *   Write unit tests for any new frontend logic.
    *   Write component tests for the quest preview card and the "Similar Quests" section.

### Phase 3: Integration and End-to-End Testing

*   **Task 3.1: Integrate Frontend with Backend API.**
    *   Connect the frontend UI to the live backend API endpoint.
    *   Verify data flow and error handling between frontend and backend.
*   **Task 3.2: Perform End-to-End Testing.**
    *   Test the entire user flow:
        *   Navigate to a quest detail view.
        *   Verify the "Similar Quests" section loads correctly.
        *   Verify the displayed quests and similarity scores are accurate (based on manual checks or a small test dataset).
        *   Verify behavior when no similar quests are found.
    *   Test on different devices/browsers as per project standards.
*   **Task 3.3: Address Bugs and Refine.**
    *   Fix any bugs identified during testing.
    *   Make any necessary refinements to UI/UX or performance.

### Phase 4: Deployment & Monitoring

*   **Task 4.1: Deploy Backend Changes.**
    *   Deploy the updated backend (similarity calculation logic, pre-computation mechanism, new API endpoint) to the production environment.
    *   Ensure the pre-computation script runs for all existing quests if not already handled.
*   **Task 4.2: Deploy Frontend Changes.**
    *   Deploy the updated frontend (quest detail view with "Similar Quests" section) to the production environment.
*   **Task 4.3: Initial Monitoring.**
    *   Monitor system performance (API response times, database load) after deployment.
    *   Monitor for any errors or unexpected behavior.
    *   (Optional, if analytics are added later) Monitor user interaction with the new section.

## 12. Future Considerations

* Implement advanced machine learning models for similarity calculation.
* Allow users to customize similarity criteria (e.g., prioritize genre over game system).
* Track user interactions to refine recommendation algorithms.
* Expand the feature to include user-generated tags and reviews in similarity calculations.
