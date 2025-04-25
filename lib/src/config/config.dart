// Configuration values for the application
// This file stores constants and configuration settings used across the app

import 'package:firebase_remote_config/firebase_remote_config.dart';

class Config {
  // Algolia search credentials
  static const String algoliaAppId = 'XDZDKQL54G';
  static const String algoliaApiKey = 'd2137698a7e4631b3e06c2e839a72bac';
  static const String algoliaQuestCardsIndex = 'questCards';

  // Google PSE Configuration
  // Remote config keys
  static const String _googleApiKeyRemoteConfigKey = 'GOOGLE_API_KEY';
  static const String _googleSearchEngineIdRemoteConfigKey =
      'GOOGLE_SEARCH_ENGINE_ID';

  // Getters for Google PSE credentials using Firebase Remote Config
  static String get googleApiKey {
    return FirebaseRemoteConfig.instance
        .getString(_googleApiKeyRemoteConfigKey);
  }

  static String get googleSearchEngineId {
    return FirebaseRemoteConfig.instance
        .getString(_googleSearchEngineIdRemoteConfigKey);
  }

  // RPG Publisher domains (priority 1)
  static const List<String> publisherDomains = [
    'wizardsofthecoast.com',
    'paizo.com',
    'koboldpress.com',
    'chaosium.com',
    'goodman-games.com',
    'montecookgames.com',
    'pelgranepress.com',
    'atlas-games.com',
    'modiphius.com',
    'cubicle7games.com',
    'ospreypublishing.com',
    'osrgaming.org',
    'freeleaguepublishing.com',
    'drivethrurpg.com', // Publisher storefront
  ];

  // RPG Marketplace domains (priority 2)
  static const List<String> marketplaceDomains = [
    'dmsguild.com',
    'itch.io',
    'rpgnow.com',
    'dtrpg.com',
    'drivethrucomics.com',
    'drivethrumodules.com',
    'drivethurfiction.com',
    'rpgdrivethru.com',
    'rulebookgames.com',
    'noblegames.com',
  ];

  // General Retailer domains (priority 3)
  static const List<String> retailerDomains = [
    'amazon.com',
    'barnesandnoble.com',
    'bookshop.org',
    'ebay.com',
    'walmart.com',
    'target.com',
    'powells.com',
  ];

  // Initialize Firebase Remote Config with default values
  static Future<void> initializeRemoteConfig() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    // Set default values for remote config parameters
    await remoteConfig.setDefaults({
      _googleApiKeyRemoteConfigKey: '',
      _googleSearchEngineIdRemoteConfigKey: '',
    });

    // Fetch remote config values
    try {
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      // Handle fetch error, but continue with defaults or cached values
      print('Error fetching remote config: $e');
    }
  }

  // Private constructor to prevent instantiation
  Config._();
}
