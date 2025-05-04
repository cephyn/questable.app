import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:simple_icons/simple_icons.dart'; // For X and Bluesky icons

class ShareOptionsModal extends StatelessWidget {
  final String shareText;
  final String shareUrl;
  final String questId;
  final String questTitle;
  final FirebaseAnalytics analytics;

  const ShareOptionsModal({
    super.key,
    required this.shareText,
    required this.shareUrl,
    required this.questId,
    required this.questTitle,
    required this.analytics,
  });

  // Helper to log analytics event for platform choice
  Future<void> _logSharePlatform(String platform) async {
    await analytics.logEvent(
      name: 'share_quest_platform',
      parameters: {'quest_id': questId, 'platform': platform},
    );
  }

  // Helper to launch URL safely
  Future<void> _launchSocialUrl(Uri uri, BuildContext context, String platform) async {
    try {
      // Remove canLaunchUrl check, directly attempt to launch
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await _logSharePlatform(platform);
      if (context.mounted) Navigator.pop(context); // Close modal on success
    } catch (e) { // Catch potential exceptions during launch
      debugPrint('Could not launch $uri: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link for $platform.')),
        );
      }
      // Optionally log the launch error to analytics
      await analytics.logEvent(
        name: 'share_launch_error',
        parameters: {'quest_id': questId, 'platform': platform, 'error': e.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap( // Use Wrap for content within the modal sheet
      children: <Widget>[
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('Copy Link'),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: shareUrl));
            await _logSharePlatform('copy_link');
            if (context.mounted) {
              Navigator.pop(context); // Close the modal
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard!')),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(SimpleIcons.x, size: 24.0), // Twitter/X icon
          title: const Text('Share on X (Twitter)'),
          onTap: () async {
            // Construct Twitter Web Intent URL
            final Uri twitterUri = Uri.https('twitter.com', '/intent/tweet', {
              'text': 'Check out this quest on Questable: "$questTitle"',
              'url': shareUrl,
              // 'hashtags': 'QuestableApp,TTRPG', // Optional hashtags
            });
            await _launchSocialUrl(twitterUri, context, 'twitter');
          },
        ),
        ListTile(
          leading: const Icon(SimpleIcons.bluesky, size: 24.0), // Bluesky icon
          title: const Text('Share on Bluesky'),
          onTap: () async {
            // Construct Bluesky Web Intent URL (text includes the URL)
            final String blueskyText = 'Check out this quest on Questable: "$questTitle"\n$shareUrl';
            final Uri blueskyUri = Uri.https('bsky.app', '/intent/compose', {
              'text': blueskyText,
            });
             await _launchSocialUrl(blueskyUri, context, 'bluesky');
          },
        ),
         ListTile(
          leading: const Icon(Icons.share), // Generic share icon
          title: const Text('More Options...'),
          onTap: () async {
             if (context.mounted) Navigator.pop(context); // Close the modal first
             // Fallback to the system share sheet
             // Note: share_plus might handle this better in future versions
             // For now, we re-call the basic share logic if needed,
            // but ideally the modal covers the primary cases.
            // This re-introduces the system share sheet if clicked.
             // Consider if this is the desired UX or if the modal should be exhaustive.
             try {
                // Re-use the text constructed earlier
                // Use Share from the share_plus package
                await SharePlus.instance.share(ShareParams(text: shareText, title: shareText, subject: 'Questable: $questTitle'));
                await _logSharePlatform('system_share_sheet'); // Log if system sheet is used via modal
             } catch (e) {
                 debugPrint('Error using system share: $e');
                 if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not open sharing options.')),
                    );
                 }
             }
          },
        ),
      ],
    );
  }
}

// Helper function to show the modal (can be called from the view)
void showShareOptionsModal(BuildContext context, {
  required String shareText,
  required String shareUrl,
  required String questId,
  required String questTitle,
  required FirebaseAnalytics analytics,
}) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return ShareOptionsModal(
        shareText: shareText,
        shareUrl: shareUrl,
        questId: questId,
        questTitle: questTitle,
        analytics: analytics,
      );
    },
  );
}

