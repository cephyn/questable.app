// Configuration values for the application
// This file stores constants and configuration settings used across the app

import 'dart:async'; // Added for Completer
import 'dart:developer';

import 'package:cloud_functions/cloud_functions.dart'; // Added for calling Firebase Functions

class Config {
  // Google PSE Configuration
  // Static variables to hold the fetched secrets
  static String? _googleApiKey;
  static String? _googleSearchEngineId;

  // Completer to manage the initialization state
  static Completer<void>? _initCompleter;

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
    // If initialization has already been attempted, return its future
    if (_initCompleter != null) {
      log('Configuration initialization already attempted or in progress.');
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();

    try {
      // Call the Firebase Function to get Google Search credentials
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('get_google_search_config');
      final HttpsCallableResult result = await callable.call();
      final data = result.data as Map<String, dynamic>?;

      if (data != null) {
        _googleApiKey = data['apiKey'] as String?;
        _googleSearchEngineId = data['searchEngineId'] as String?;
        log('Fetched Google API Key: $_googleApiKey'); // Added log
        log('Fetched Google Search Engine ID: $_googleSearchEngineId'); // Added log
        log('Successfully fetched Google Search config from Cloud Function.');
        if (_googleApiKey == null ||
            _googleApiKey!.isEmpty ||
            _googleSearchEngineId == null ||
            _googleSearchEngineId!.isEmpty) {
          log('Error: Google API Key or Search Engine ID is null or empty after fetch.');
          // Consider completing with an error if keys are essential and not found
          // For now, this will lead to _keysAreConfigured being false in the UI
        }
      } else {
        log('Error: No data received from get_google_search_config function.');
        // This is an error condition
      }
      _initCompleter!.complete();
    } on FirebaseFunctionsException catch (e) {
      log('FirebaseFunctionsException fetching Google config: ${e.code} - ${e.message}');
      _initCompleter!.completeError(e); // Propagate the error
    } catch (e) {
      log('Error fetching Google search config: $e');
      _initCompleter!.completeError(e); // Propagate the error
    }
    return _initCompleter!.future;
  }

  // Private constructor to prevent instantiation
  Config._();
}
