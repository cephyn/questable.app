# Purchase Link AI Agent Requirements

## Overview
This document defines the requirements for the AI agent that will search for purchase links for RPG adventures after file scanning and data extraction in the Questable application.

## Success Criteria
A "successful" web search result for an RPG adventure purchase link must meet the following criteria:

1. **Link Validity**
   - URL must be properly formed and accessible (returns HTTP 200 status)
   - URL must lead to a page where the product can be purchased or downloaded
   - URL must not redirect to a generic catalog or search page

2. **Source Prioritization**
   - **Priority 1**: Direct publisher website (e.g., wizardsofthecoast.com for D&D adventures)
   - **Priority 2**: Official RPG marketplaces (DriveThruRPG, itch.io, DMs Guild)
   - **Priority 3**: Other legitimate retailers (Amazon, Barnes & Noble)

3. **Match Confidence**
   - High confidence: URL or page title contains exact product name 
   - Medium confidence: URL contains partial product name or publisher name plus product keywords
   - Low confidence: Generic product page with matching game system and similar keywords

4. **Minimum Requirements for Storage**
   - Only store URLs with medium or high confidence matches
   - In case of multiple matches, store the highest priority source
   - If no medium/high confidence match is found, do not populate the link field

## Search Query Formation
The AI agent should form search queries using the following product metadata in order of importance:

1. Product title (exact phrase)
2. Publisher name
3. Game system and edition
4. "buy", "purchase", or "official" keywords

Example query formations:
- `"Curse of Strahd" "Wizards of the Coast" buy`
- `"The Slumbering Tsar Saga" "Frog God Games" Pathfinder purchase`

## Validation Criteria
Before storing a discovered purchase link, the system must validate:

1. **Domain Validation**
   - Check against whitelist of known RPG publishers and marketplaces
   - Verify domain has secure HTTPS
   - Ensure domain is not a known piracy site

2. **Content Validation**
   - Verify page title or metadata contains product name
   - Check for price information or "add to cart" functionality
   - Verify page is not a review site, forum, or blog

3. **Link Structure Validation**
   - Prefer links with "/product/", "/store/", "/item/" in the path
   - Avoid links with "/search?", "/category/", or similar in the path
   - Remove unnecessary query parameters that don't identify the product

## Performance Requirements
- Search and validation should complete within 5 seconds for new file analysis
- Batch processing for existing records should process at least 20 records per minute
- System should cache results to prevent duplicate API calls for the same product

## Error Handling Requirements
1. **Search Failures**:
   - Retry failed searches up to 3 times with exponential backoff
   - Log detailed error information for failed searches
   - Allow manual triggering of search for previously failed items

2. **API Quota Management**:
   - Monitor daily API usage against quota limits
   - Implement graceful degradation when approaching quota limits
   - Prioritize new file analysis over backfill operations

## Analytics Requirements
The system should capture the following metrics:
- Search success rate
- Distribution of link sources (publisher vs marketplace vs other)
- Average search latency
- API quota usage patterns
