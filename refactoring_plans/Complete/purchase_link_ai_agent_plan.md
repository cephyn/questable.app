# Purchase Link AI Agent Implementation Plan

This document outlines the phased approach for implementing a new feature in Questable that uses an AI agent to search the web for purchase links after scanning and extracting data from RPG adventures.

## Phase 1: Research & Requirements

**Objectives:**
- Define the exact scope of the feature
- Research Google Programmable Search Engine (PSE) configuration
- Determine search quality optimization strategies

**Tasks:**
1. **Requirement Analysis**:
   - Define what constitutes a "successful" web search result
   - Determine search priority order: direct publisher site first, then DriveThruRPG/itch.io, then other retailers
   - Create validation criteria for purchase links

2. **Google PSE Configuration Research**:
   - Research setting up a Google PSE with RPG publisher site focus
   - Determine optimal site restriction patterns for RPG retailers
   - Document API key and authentication requirements leveraging existing Google cloud account
   - Research quota limits and cost implications

3. **Legal & Policy Review**:
   - Review Google Custom Search API terms of service
   - Confirm compliance with affiliate program requirements
   - Verify privacy implications of data handling

**Dependencies:**
- Access to existing Google cloud account
- Documentation on currently extracted RPG adventure metadata
- List of priority RPG publisher and retail sites

**Expected Outcome:**
- Requirements document
- Google PSE configuration plan
- Budget estimation for API usage
- Prioritized list of publisher and retailer sites to include in search scope

## Phase 2: Design

**Objectives:**
- Create a technical design for the AI agent
- Design the integration with `quest_card_analyze.dart`
- Define the asynchronous processing approach

**Tasks:**
1. **AI Agent Design**:
   - Design query generation strategy using adventure metadata (title, publisher, author)
   - Define publisher website detection and validation logic
   - Create fallback search strategies when direct publisher links aren't found

2. **Integration Architecture**:
   - Design how the AI agent integrates within `autoAnalyzeFile` in `quest_card_analyze.dart`
   - Plan for asynchronous processing to run in parallel with existing file analysis
   - Leverage existing QuestCard's `link` field for storing purchase URLs

3. **Asynchronous Processing Design**:
   - Design thread/isolate management for search operations
   - Create mechanism to update QuestCard with link after both processes complete
   - Plan for handling search completion after metadata extraction finishes

**Dependencies:**
- Conclusions from Research phase
- Access to QuestCard class implementation
- Access to `quest_card_analyze.dart` implementation

**Expected Outcome:**
- Technical design document
- Thread management design for asynchronous processing
- Google PSE configuration specification

## Phase 3: Implementation

**Objectives:**
- Set up Google Programmable Search Engine
- Develop search query generation and result filtering
- Implement asynchronous integration with `quest_card_analyze.dart`
- Create admin functionality for backfilling existing QuestCards

**Tasks:**
1. **Google PSE Configuration**:
   - Create custom search engine in Google Cloud Console
   - Configure site restrictions for RPG publishers and retailers
   - Set up API key with appropriate permissions and restrictions
   - Create PSE with site prioritization for publisher sites

2. **Search Agent Implementation**:
   - Implement search query generation from QuestCard metadata
   - Develop result filtering with publisher site prioritization logic
   - Create validation for purchase links
   - Implement error handling and fallback searches

3. **Integration with `quest_card_analyze.dart`**:
   - Add asynchronous search capability to `autoAnalyzeFile` method
   - Implement Isolate or compute function for background processing
   - Create mechanism to update QuestCard's `link` field after search completes
   - Ensure proper exception handling for search failures

4. **Admin Backfill Functionality**:
   - Develop an admin page with batch processing capability
   - Implement filtering to select QuestCards without links
   - Create batch job system to process QuestCards in manageable chunks
   - Add progress tracking and reporting for backfill operations
   - Implement error handling and retry mechanisms for failed searches

5. **Search Result Optimization**:
   - Implement caching layer for search results
   - Create mechanism to detect and prioritize publisher domains
   - Add logging for search effectiveness

**Dependencies:**
- Google Cloud PSE account with API access
- Completed technical design
- Access to `quest_card_analyze.dart` implementation
- Database access to retrieve existing QuestCards

**Expected Outcome:**
- Functional Google PSE configuration
- Integration with existing analysis pipeline
- Asynchronous processing implementation
- Admin interface for backfilling existing QuestCards
- Comprehensive error handling

## Phase 4: Testing

**Objectives:**
- Validate accuracy of search results
- Test publisher prioritization logic
- Ensure asynchronous processing reliability

**Tasks:**
1. **Unit Testing**:
   - Test search query generation
   - Verify publisher detection and prioritization
   - Validate asynchronous processing mechanisms

2. **Integration Testing**:
   - Test complete flow from file scan through link discovery
   - Verify proper updating of QuestCard's `link` field
   - Test error handling and fallback mechanisms
   - Ensure proper handling of Google API quota limits

3. **Performance Testing**:
   - Measure search latency
   - Verify proper asynchronous operation
   - Test under different load conditions
   - Ensure minimal impact on UI responsiveness

4. **Validation Testing**:
   - Create benchmark dataset of RPG adventures with known purchase links
   - Measure accuracy of publisher detection
   - Track success rate of finding the correct purchase URLs
   - Compare direct publisher vs. retailer detection rates

**Dependencies:**
- Completed implementation
- Test environment with Google API access
- Benchmark dataset of RPG adventures

**Expected Outcome:**
- Test coverage report
- Search accuracy metrics
- Performance benchmarks
- List of prioritized improvements

## Phase 5: Deployment & Monitoring

**Objectives:**
- Release the feature to production
- Monitor search performance and accuracy
- Optimize based on real-world usage

**Tasks:**
1. **Deployment Preparation**:
   - Update documentation
   - Set up monitoring for Google API usage
   - Create fallback mechanisms for API outages or quota exhaustion

2. **Phased Rollout**:
   - Deploy to limited user group
   - Monitor for issues
   - Gradually expand availability

3. **Analytics Setup**:
   - Track search success rates
   - Measure publisher vs. retailer link ratio
   - Monitor performance impact on file analysis
   - Track API usage and costs

4. **Continuous Improvement**:
   - Tune search queries based on success metrics
   - Update publisher site priority list
   - Optimize asynchronous processing timing
   - Expand supported RPG publishers and retailers

**Dependencies:**
- Successful testing phase
- Production environment readiness
- Analytics infrastructure

**Expected Outcome:**
- Fully deployed feature
- Baseline search accuracy metrics
- API usage monitoring dashboard
- Improvement roadmap

## Progress Tracking

| Phase | Status | Start Date | End Date | Notes |
|-------|--------|------------|----------|-------|
| Research & Requirements | Completed | April 25, 2025 | April 25, 2025 | Completed Google PSE research document, purchase link requirements, and legal considerations |
| Design | Completed | April 25, 2025 | April 25, 2025 | Created technical design document and integration plan for quest_card_analyze.dart |
| Implementation | In Progress | April 25, 2025 | | Implemented service classes, integration with quest_card_analyze.dart, and admin backfill functionality. Added admin UI access through navigation. |
| Testing | Not Started | | | |
| Deployment & Monitoring | Not Started | | | |

## Implementation Status

### Completed:
- Created BackfillStats model for tracking progress
- Implemented PurchaseLinkService for search operations
- Created PurchaseLinkBackfillController for managing backfill process
- Added PurchaseLinkBackfillScreen for the admin UI
- Integrated with main app navigation for admin users
- Added access control to restrict functionality to admin users

### In Progress:
- Testing the backfill functionality with real data
- Optimizing search queries for better results
- Implementing caching for repeated searches

### Pending:
- Complete integration testing
- User acceptance testing
- Performance optimization
- Deployment to production

## Risks & Mitigation

1. **Google Search API Limitations**:
   - Risk: Rate limits, cost scaling, quota exhaustion
   - Mitigation: Implement caching, asynchronous processing, quota monitoring

2. **Search Result Quality**:
   - Risk: Incorrect or irrelevant purchase links, especially for niche publishers
   - Mitigation: Publisher site prioritization, multiple query strategies

3. **Publisher Website Changes**:
   - Risk: Publisher websites changing structure affecting search results
   - Mitigation: Regular monitoring, search parameter optimization

4. **Performance Impact**:
   - Risk: Search operations slowing down overall file processing
   - Mitigation: Proper asynchronous implementation, caching, and optimized search queries

## Implementation Notes

1. **Integration Point**:
   - Integration to occur within the `autoAnalyzeFile` method in `quest_card_analyze.dart`
   - URL search will run in parallel with the existing AI metadata extraction

2. **Data Storage**:
   - Purchase URLs will be stored in the existing `link` field of the QuestCard class
   - No database schema changes required

3. **Asynchronous Processing**:
   - Web search will run on a separate thread/isolate
   - Result will be applied to QuestCard after both metadata extraction and URL search complete

4. **Search Priority**:
   - Direct publisher website URLs will be prioritized
   - Fallback to established RPG marketplaces (DriveThruRPG, itch.io)
   - Generic retailers as last resort

5. **Legacy Data Handling**:
   - Admin interface will provide batch processing for existing QuestCards
   - Backfill process will run with lower priority to avoid API quota issues
   - Progress tracking will allow for pausing and resuming backfill operations

## Future Enhancements

- Price comparison across multiple stores
- Historical price tracking
- Bundle detection (when multiple quests are available in a collection)
- User reviews integration from purchase sites
- Affiliate program revenue sharing with content creators
- Enhanced search optimization using Google Search Console data
