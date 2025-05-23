# Google Programmable Search Engine (PSE) Research

## Overview
This document contains research findings for implementing Google PSE to find purchase links for RPG adventures in the Questable application.

## Google PSE Basics
- **Service Description**: Google Programmable Search Engine allows creating custom search engines that search specific websites or the entire web with customized ranking and prioritization
- **API Name**: Google Custom Search JSON API
- **Documentation**: https://developers.google.com/custom-search/v1/overview

## Setup Requirements
1. **Google Cloud Account**: Required for API access and quota management
2. **Programmable Search Engine Creation**: 
   - Create at https://programmablesearchengine.google.com/
   - Can specify sites to include in search results
   - Can prioritize certain domains

3. **API Key**: 
   - Required for accessing the Custom Search JSON API
   - Create in Google Cloud Console under "APIs & Services > Credentials"

## API Usage Details
- **Endpoint**: `https://www.googleapis.com/customsearch/v1`
- **Required Parameters**:
  - `key`: API key
  - `cx`: Custom Search Engine ID
  - `q`: Search query

- **Example Request**:
```
GET https://www.googleapis.com/customsearch/v1?key=YOUR-API-KEY&cx=YOUR-CSE-ID&q=Tomb+of+Annihilation+Wizards+of+the+Coast
```

## Quota and Pricing
- **Free Tier**: 100 search queries per day
- **Paid Tier**: $5 per 1000 queries, up to 10,000 queries per day
- **Billing**: Must enable billing in Google Cloud Console

## Optimization for RPG Purchase Links
### Site Restriction Strategy
1. **Priority Publisher Sites**:
   - Wizards of the Coast (dnd.wizards.com)
   - Paizo (paizo.com)
   - Kobold Press (koboldpress.com)
   - Chaosium (chaosium.com)
   - Free League Publishing (freeleaguepublishing.com)
   - Goodman Games (goodman-games.com)

2. **RPG Marketplaces**:
   - DriveThruRPG (drivethrurpg.com)
   - itch.io (itch.io)
   - RPGNow (rpgnow.com)
   - DMs Guild (dmsguild.com)

### Query Formation Strategy
For optimal results, construct queries using:
1. Product title (exact match in quotes)
2. Publisher name
3. Game system
4. "buy" or "purchase" keywords

Example: `"Tomb of Annihilation" "Wizards of the Coast" D&D buy`

### Result Validation
Validate returned URLs by checking:
1. Domain matches known publisher/marketplace
2. URL contains product name or keywords
3. URL path suggests a product page (/product/, /item/, /store/)

## Implementation Considerations
1. **Rate Limiting**: Implement retry with exponential backoff
2. **Caching**: Cache results to minimize API calls
3. **Error Handling**: Plan for API downtime or quota exhaustion
4. **Asynchronous Processing**: Run searches in background to avoid UI blocking

## Legal and Policy Considerations

### Google Custom Search API Terms
- **Attribution**: Must attribute search results to Google when displaying them
- **Rate Limits**: Must adhere to quota limitations based on subscription tier
- **Caching**: May cache results for up to 24 hours to reduce API calls
- **Usage Restrictions**: 
  - Cannot use to create a similar search service to Google
  - Cannot scrape or extract data from search result pages
  - Must use API results as presented

### Affiliate Program Considerations
- **Disclosure**: Must disclose affiliate relationships to users
- **DriveThruRPG Affiliate Program**:
  - Offers 5% commission on sales through affiliate links
  - Requires approval process before generating links
  - Provides structured affiliate link format
- **Amazon Associates Program**:
  - Offers 1-10% commission depending on product category
  - Has specific disclosure requirements
  - Links expire after 24 hours

### Privacy Implications
- **User Consent**: Consider informing users that their uploaded content metadata may be used for web searches
- **Data Storage**: Store only the minimum necessary data from search results (product URL)
- **API Keys**: Secure API keys with appropriate restrictions (HTTP referrers, IP limitations)
- **Search Logging**: Consider whether to store search history for improving results

## Considerations for Implementation
- Implement both the Google terms of service requirements and relevant affiliate program requirements
- Include appropriate attribution when displaying search results
- Consider creating a privacy policy addition explaining the feature
- Use secure storage for API keys with appropriate access restrictions

## Next Steps
1. Create Google Cloud project and enable Custom Search API
2. Set up Programmable Search Engine with RPG publisher and marketplace sites
3. Test API with sample RPG adventure data
4. Implement query construction and result validation strategies

## References
- [Google Custom Search JSON API Documentation](https://developers.google.com/custom-search/v1/overview)
- [Programmable Search Engine Setup](https://programmablesearchengine.google.com/about/)
- [Google Cloud Console](https://console.cloud.google.com/)
