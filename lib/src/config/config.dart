// Configuration values for the application
// This file stores constants and configuration settings used across the app

import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart'; // Added for calling Firebase Functions

class Config {
  // Algolia search credentials
  static const String algoliaAppId = 'XDZDKQL54G';
  static const String algoliaApiKey = 'd2137698a7e4631b3e06c2e839a72bac';
  static const String algoliaQuestCardsIndex = 'questCards';

  // Google PSE Configuration
  // Static variables to hold the fetched secrets
  static String? _googleApiKey;
  static String? _googleSearchEngineId;

  // Getters for Google PSE credentials
  static String get googleApiKey {
    if (_googleApiKey == null) {
      log('Warning: Google API Key accessed before initialization or fetch failed.');
    }
    return _googleApiKey ?? ''; // Return empty string if null
  }

  static String get googleSearchEngineId {
    if (_googleSearchEngineId == null) {
      log('Warning: Google Search Engine ID accessed before initialization or fetch failed.');
    }
    return _googleSearchEngineId ?? ''; // Return empty string if null
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

  // Initialize and fetch Google Search Config from Cloud Function
  static Future<void> initializeAppConfig() async {
    try {
      // Call the Firebase Function to get Google Search credentials
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('get_google_search_config');
      final HttpsCallableResult result = await callable.call();
      final data = result.data as Map<String, dynamic>?;

      if (data != null) {
        _googleApiKey = data['apiKey'] as String?;
        _googleSearchEngineId = data['searchEngineId'] as String?;
        log('Successfully fetched Google Search config from Cloud Function.');
        if (_googleApiKey == null || _googleSearchEngineId == null) {
          log('Error: Google API Key or Search Engine ID is null after fetch.');
        }
      } else {
        log('Error: No data received from get_google_search_config function.');
      }
    } on FirebaseFunctionsException catch (e) {
      log('FirebaseFunctionsException fetching Google config: ${e.code} - ${e.message}');
    } catch (e) {
      // Handle any other errors, but continue with defaults or cached values
      log('Error fetching Google search config: $e');
    }

    // If you were using Firebase Remote Config for other values,
    // its initialization logic would remain here.
    // For example:
    // final remoteConfig = FirebaseRemoteConfig.instance;
    // await remoteConfig.setConfigSettings(RemoteConfigSettings(
    //   fetchTimeout: const Duration(minutes: 1),
    //   minimumFetchInterval: const Duration(hours: 1),
    // ));
    // await remoteConfig.setDefaults({
    //   // ... other remote config defaults
    // });
    // try {
    //   await remoteConfig.fetchAndActivate();
    // } catch (e) {
    //   log('Error fetching remote config: $e');
    // }
  }

  // Private constructor to prevent instantiation
  Config._();
}
