# Mastodon Integration for Quest Cards Social Media

## Overview
Added Mastodon posting capability to the existing social media automation system. The system now posts to Bluesky, X (Twitter), and Mastodon simultaneously.

## Changes Made

### 1. Dependencies
- Added `Mastodon.py>=1.8.1` to `functions/requirements.txt`

### 2. Code Changes
- Added `from mastodon import Mastodon` import to `social_media.py`
- Implemented `post_to_mastodon(content)` function
- Added Mastodon posting call to the main scheduler function

### 3. Required Configuration
You need to add the following secrets to Google Cloud Secret Manager:

- `mastodon_instance_url`: The base URL of your Mastodon instance (e.g., "https://mastodon.social")
- `mastodon_access_token`: Your Mastodon application access token

### 4. How to Get Mastodon Credentials

1. **Choose a Mastodon instance** (e.g., mastodon.social, mas.to, etc.)
2. **Create an account** if you don't have one
3. **Navigate to application settings**:
   - Go to Preferences/Settings
   - Select "Development"
   - Click "New Application"
4. **Configure the application**:
   - Name: "Quest Cards Bot" (or similar)
   - Scopes: Make sure `write:statuses` is enabled
   - Redirect URI: Can be left as default for server apps
5. **Get credentials**:
   - Copy the "Your access token" value
   - Note the instance URL (e.g., "https://mastodon.social")

### 5. Features
- **Character limit**: 500 characters (more generous than Twitter's 280)
- **Link handling**: Full URLs are used (no link shortening like Twitter)
- **Error handling**: Comprehensive logging and error tracking
- **Content formatting**: Same content generation as other platforms
- **Hashtag support**: Full hashtag support

### 6. Deployment
After adding the secrets to Google Cloud Secret Manager, deploy the functions:

```bash
firebase deploy --only functions
```

### 7. Testing
The function runs on the same schedule as other social media posts:
- Daily at 2:00 PM and 11:00 PM UTC
- Posts are logged to the `social_post_logs` Firestore collection

## Mastodon-Specific Considerations

1. **Instance Selection**: Choose a reliable instance that aligns with your content policy
2. **Rate Limits**: Mastodon has generous rate limits compared to Twitter
3. **Character Limit**: 500 characters gives more room for detailed quest descriptions
4. **Community Guidelines**: Each instance may have different rules and moderation policies
5. **Hashtag Culture**: Mastodon users appreciate relevant hashtags for discoverability

## Error Handling
The system includes comprehensive error handling:
- Missing credentials are logged and tracked
- API failures don't affect other platform posts
- All attempts are logged to Firestore for monitoring
