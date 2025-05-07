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

## 10. Future Considerations

* Implement advanced machine learning models for similarity calculation.
* Allow users to customize similarity criteria (e.g., prioritize genre over game system).
* Track user interactions to refine recommendation algorithms.
* Expand the feature to include user-generated tags and reviews in similarity calculations.
