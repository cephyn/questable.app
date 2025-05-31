"""
Social Media functions for the quest cards Firebase Functions.
Handles content generation and posting to various social platforms.
"""

import logging
import datetime
import random
import re
from firebase_functions import scheduler_fn, options
from firebase_admin import firestore
from atproto import Client, models, client_utils
import tweepy
import google.generativeai as genai  # Added for Gemini

from utils import get_secret, log_social_post_attempt


def generate_ai_text(genre: str, summary: str, quest_title: str) -> str:
    """Generates a short, compelling AI snippet for a quest using Gemini."""
    try:
        api_key = get_secret("gemini_api_key")  # Fetch the Gemini API key from Secret Manager
        if not api_key:
            logging.error("Gemini API key not available. Skipping AI text generation.")
            return ""

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel("gemini-2.0-flash")

        prompt = f"""Generate a very short and exciting social media teaser (around 15-25 words, and strictly under 150 characters) for a tabletop roleplaying quest titled '{quest_title}'.
The quest is in the '{genre}' genre.
Summary: '{summary}'.
The teaser should be engaging and make people curious to check out the quest.
Do not use hashtags in your response. Do not include the quest title or genre in your response unless it flows very naturally as part of the teaser.
Focus on creating a hook or a sense of mystery/adventure.
Example tone for a fantasy quest: "Ancient secrets whisper from forgotten ruins. Dare you uncover them?"
Example tone for a sci-fi quest: "Cosmic anomalies detected. Your mission, should you choose to accept it..."
Example tone for a horror quest: "A chilling presence lurks in the old manor. What terrors await inside?"
"""

        logging.info(f"Generating AI text for quest: {quest_title} (Genre: {genre})")
        response = model.generate_content(prompt)

        if response.parts:
            ai_text = response.text.strip()
            # Additional check for safety, though the prompt requests short text
            if len(ai_text) > 160:
                logging.warning(
                    f"Generated AI text for '{quest_title}' is too long ({len(ai_text)} chars), truncating: {ai_text}"
                )
                ai_text = ai_text[:157] + "..."
            logging.info(f"Successfully generated AI text: {ai_text}")
            return ai_text
        else:
            logging.warning(
                f"Gemini response for '{quest_title}' contained no parts. Prompt: {prompt}"
            )
            if hasattr(response, "prompt_feedback") and response.prompt_feedback:
                logging.warning(f"Gemini prompt feedback: {response.prompt_feedback}")
            return ""

    except Exception as e:
        logging.error(f"Error generating AI text for '{quest_title}': {e}")
        return ""


def generate_post_content(quest_data):
    """Generates content for social media posts based on quest data."""
    logging.debug(f"Generating content for quest: {quest_data.get('title')}")
    
    title = quest_data.get("title", "Untitled Quest")
    product_name = quest_data.get("productTitle", "")
    game_system = quest_data.get("standardizedGameSystem", quest_data.get("gameSystem", "Unknown System"))
    genre = quest_data.get("genre", "Adventure")
    summary = quest_data.get("summary", "No summary available.")
    quest_id = quest_data.get("id")

    deep_link = f"https://questable.app/#/quest/{quest_id}" 

    hashtag_terms = []
    if game_system:
        hashtag_terms.append(game_system.replace(" ", ""))
    if genre:
        hashtag_terms.append(genre.replace(" ", ""))
    hashtag_terms.extend(["#Questable", "#ttrpg"])
    # Ensure no empty strings if game_system or genre were empty
    hashtag_terms = [term for term in hashtag_terms if term]

    # Template-based post text components
    if title.lower() == product_name.lower():
        post_text_template = f"New Quest: {title}! ({game_system})."
    else:
        post_text_template = f"New Quest: {title}! From {product_name} ({game_system})."

    ctas = [
        "Explore this adventure!",
        "Discover your next quest!",
        "Embark on this journey!",
        "What choices will you make?",
        "Your story awaits!",
        "Claim your destiny!",
        "The challenge begins now!",
        "Will you answer the call?",
        "Shape your own fate!",
        "Dive into the unknown!",
        "Start your legend!",
        "The next chapter unfolds!",
        "Where will your path lead?",
        "Make your move!",
    ]
    cta = random.choice(ctas)

    # Placeholder for Gemini integration logic
    # AI Text Generation
    ai_enhanced_text = ""
    if genre and summary and title:  # Only generate if key fields are present
        ai_enhanced_text = generate_ai_text(genre, summary, title)
    else:
        logging.warning(
            f"Skipping AI text generation for quest ID {quest_id} due to missing genre, summary, or title."
        )
    
    # Assemble text segments
    text_segments = [post_text_template]
    if ai_enhanced_text:
        text_segments.append(ai_enhanced_text)
    else:
        # Fallback if AI snippet is not generated, include genre explicitly if not in template already
        if genre and genre not in post_text_template:
            text_segments.append(f"Genre: {genre}.")

    text_segments.append(cta)

    return {
        "text_segments": [
            segment for segment in text_segments if segment
        ],  # Filter out any None or empty segments
        "hashtag_terms": hashtag_terms,
        "quest_title": title,  # Already capitalized
        "link": deep_link,
        "quest_id": quest_id,  # Add quest_id here
    }

def get_bluesky_credentials() -> dict:
    """Fetches Bluesky credentials using the utility function."""
    project_id = "766749273273"  # Your Google Cloud Project ID
    bluesky_handle_secret_id = "bluesky_handle"
    bluesky_password_secret_id = "bluesky_password"

    bluesky_handle = get_secret("bluesky_handle")
    bluesky_password = get_secret("bluesky_password")

    if not bluesky_handle or not bluesky_password:
        logging.error("Bluesky handle or password not found in Secret Manager.")
        raise ValueError(
            "Bluesky credentials not configured correctly in Google Cloud Secret Manager."
        )

    return {"handle": bluesky_handle, "password": bluesky_password}


def post_to_bluesky(content: dict):
    """Posts the given content to Bluesky using TextBuilder for rich text."""
    credentials = get_bluesky_credentials()
    client = Client()

    # Extract components from the content dictionary
    text_segments = content.get("text_segments", [])
    hashtag_terms = content.get("hashtag_terms", [])
    link_url = content.get("link")
    quest_title_for_embed = content.get("quest_title", "View Quest")
    # For logging purposes, join text segments for a readable version of the post text
    # This won't be the exact text sent, as TextBuilder handles spacing and facets.
    log_text_preview = " ".join(text_segments)

    try:
        profile = client.login(credentials["handle"], credentials["password"])
        logging.info(f"Successfully logged in to Bluesky as {profile.handle}")

        text_builder = client_utils.TextBuilder()
        first_segment = True
        for segment in text_segments:
            if not first_segment:
                text_builder.text(" ")  # Add space between segments
            text_builder.text(segment)
            first_segment = False

        # Add hashtags
        for term in hashtag_terms:
            if term:  # Ensure term is not empty
                text_builder.text(" ").tag(
                    term, term
                )  # Adds a space before the hashtag text and then the tag itself

        # Add the link at the end of the text part if it exists
        # The visual card embed is separate
        if link_url:
            text_builder.text(" ").link(link_url, link_url)

        # Prepare the embed card for the link
        embed_payload = None
        if link_url:
            embed_external = models.AppBskyEmbedExternal.Main(
                external=models.AppBskyEmbedExternal.External(
                    uri=link_url,
                    title=quest_title_for_embed,
                    description="Check out this quest on Questable!",  # Generic description for the card
                )
            )
            embed_payload = embed_external

        # Build post record
        # Note: Bluesky has a 300 grapheme limit for the post text.
        # TextBuilder does not automatically truncate. We need to be mindful of the total length.
        # For simplicity, we are currently relying on the prompt to Gemini and content assembly
        # to keep it within limits. More robust truncation would be needed for longer content.
        final_text = text_builder.build_text()
        final_facets = text_builder.build_facets()

        if len(final_text) > 300:
            logging.warning(
                f"Bluesky post text exceeds 300 chars ({len(final_text)}). Truncating text and clearing facets."
            )
            # Truncate text to fit, leaving space for "..."
            max_len_for_text = 297
            final_text = final_text[:max_len_for_text] + "..."
            final_facets = []  # Clear facets as their byte offsets would be incorrect

        post_record_data = models.AppBskyFeedPost.Record(
            text=final_text,
            facets=final_facets,
            created_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        )

        if embed_payload:
            post_record_data.embed = embed_payload

        post_record = models.ComAtprotoRepoCreateRecord.Data(
            repo=profile.did, collection="app.bsky.feed.post", record=post_record_data
        )
        response = client.com.atproto.repo.create_record(data=post_record)

        logging.info(f"Successfully posted to Bluesky: {response.uri}")
        db = firestore.client()
        log_ref = db.collection("social_post_logs").document()
        log_ref.set(
            {
                "platform": "Bluesky",
                "quest_title": quest_title_for_embed,
                "post_text_preview": log_text_preview,  # Log the preview
                "post_uri": response.uri,
                "status": "success",
                "timestamp": firestore.SERVER_TIMESTAMP,
            }
        )

    except Exception as e:
        logging.error(f"Failed to post to Bluesky: {e}")
        db = firestore.client()
        log_ref = db.collection("social_post_logs").document()
        log_ref.set(
            {
                "platform": "Bluesky",
                "quest_title": quest_title_for_embed,
                "post_text_preview": log_text_preview,  # Log the preview
                "status": "error",
                "error_message": str(e),
                "timestamp": firestore.SERVER_TIMESTAMP,
            }
        )
        raise  # Re-raise the exception


def post_to_x(content):
    """Post content to X (formerly Twitter) platform."""
    logging.info("Attempting to post to X...")
    try:
        consumer_key = get_secret("twitter_api_key")
        consumer_secret = get_secret("twitter_api_key_secret")
        access_token = get_secret("twitter_access_token")
        access_token_secret = get_secret("twitter_access_token_secret")

        client = tweepy.Client(
            consumer_key=consumer_key,
            consumer_secret=consumer_secret,
            access_token=access_token,
            access_token_secret=access_token_secret
        )

        text_segments = content.get("text_segments", [])
        hashtag_terms = content.get("hashtag_terms", [])
        embed_link = content.get("link")

        # Construct the main text part from segments and hashtags
        main_text_parts = [segment for segment in text_segments if segment]
        constructed_body = " ".join(main_text_parts)

        hashtags_string = ""
        if hashtag_terms:
            valid_hashtags = [f"#{term.replace(' ', '')}" for term in hashtag_terms if term]
            if valid_hashtags:
                hashtags_string = " ".join(valid_hashtags)

        post_text_to_truncate = ""
        if constructed_body and hashtags_string:
            post_text_to_truncate = f"{constructed_body} {hashtags_string}"
        elif constructed_body:
            post_text_to_truncate = constructed_body
        elif hashtags_string:
            post_text_to_truncate = hashtags_string
        
        limit = 280
        link_placeholder_len = 23 # t.co link length
        final_tweet_text: str

        if embed_link:
            available_char_for_text = limit - link_placeholder_len - 1 # 1 for space before link
            if len(post_text_to_truncate) > available_char_for_text:
                text_part = post_text_to_truncate[:available_char_for_text - 3] + "..."
            else:
                text_part = post_text_to_truncate
            final_tweet_text = f"{text_part} {embed_link}"
        else:
            if len(post_text_to_truncate) > limit:
                text_part = post_text_to_truncate[:limit - 3] + "..."
            else:
                text_part = post_text_to_truncate
            final_tweet_text = text_part

        response = client.create_tweet(text=final_tweet_text)

        logging.info(f"Successfully posted to X. Tweet ID: {response.data['id']}")
        log_social_post_attempt(content["quest_id"], "X", "success", final_tweet_text, link=embed_link, post_id=response.data['id'])

    except Exception as e:
        logging.error(f"Error posting to X: {e}. Check if 'x_consumer_key', 'x_consumer_secret', 'x_access_token', 'x_access_token_secret' are correctly set in Secret Manager.")
        log_social_post_attempt(content["quest_id"], "X", "error", str(e), link=content.get("link"))


@scheduler_fn.on_schedule(
    schedule="0 14,23 * * *", 
    memory=options.MemoryOption.GB_1,
)
def select_quest_and_post_to_social_media(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Selects a random public quest card from Firestore and posts to social media.
    """
    db = firestore.client()
    quests_ref = db.collection("questCards") 
    query = quests_ref.where("isPublic", "==", True)
    logging.info("Querying for public quest cards...")

    eligible_quests = []
    processed_count = 0
    for doc in query.stream():
        processed_count += 1
        quest_data = doc.to_dict()
        quest_data["id"] = doc.id 
        logging.debug(f"Processing quest document ID: {doc.id}")

        if (
            quest_data.get("gameSystem")
            and quest_data.get("standardizedGameSystem")
            and quest_data.get("title")
            and quest_data.get("productTitle")
            and quest_data.get("summary")
            and quest_data.get("genre")
        ):
            logging.debug(f"Quest ID: {doc.id} is eligible.")
            eligible_quests.append(quest_data)
        else:
            logging.debug(
                f"Quest ID: {doc.id} is NOT eligible due to missing fields."
            )

    logging.info(f"Total public quests processed: {processed_count}")
    if not eligible_quests:
        logging.error("No eligible quests found for posting.")
        return

    selected_quest = random.choice(eligible_quests)
    logging.info(
        f"Selected quest for posting: {selected_quest.get('title')} (ID: {selected_quest.get('id')})"
    )
    
    generated_content = generate_post_content(selected_quest) 

    if not generated_content or not generated_content.get("quest_id"):
        logging.error(f"Failed to generate content or quest_id missing for selected_quest: {selected_quest.get('id')}")
        return

    logging.info(f"Generated content for quest ID {generated_content.get('quest_id')}: {generated_content.get('text')}")

    try:
        post_to_bluesky(generated_content)
    except Exception as e:
        logging.error(f"Bluesky posting failed in main scheduler for quest {generated_content.get('quest_id')}: {e}")

    try:
        post_to_x(generated_content)
    except Exception as e:
        logging.error(f"X posting failed in main scheduler for quest {generated_content.get('quest_id')}: {e}")

    logging.info(f"select_quest_and_post_to_social_media function completed for quest {generated_content.get('quest_id')}.")
