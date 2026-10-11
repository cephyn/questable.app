
// lib/src/config/app_constants.dart

/// Application constants
class AppConstants {
  /// The base URL for the web application, used for constructing shareable links.
  /// TODO: Consider moving this to Firebase Remote Config or build environment variables for flexibility.
  static const String baseUrl = 'https://questable.app';

  /// Public reCAPTCHA Enterprise site key for App Check on web. Not a secret.
  static const String recaptchaEnterpriseSiteKey =
      '6LeuOOotAAAAAKWAguiEUkhSBmVJVefU_4FTkTIw';
}
