import 'early_error_reporter_stub.dart'
    if (dart.library.html) 'early_error_reporter_web.dart';

/// Hooks very-early, web-specific error reporting.
///
/// This is separate from the Firebase callable error reporter because on the
/// web the app can crash before Firebase initializes, which makes callable
/// functions unavailable.
abstract class EarlyErrorReporter {
  static void install() => EarlyErrorReporterImpl.install();

  static Future<void> report({
    required String stage,
    required Object error,
    StackTrace? stackTrace,
    String? runId,
    Map<String, dynamic>? context,
  }) =>
      EarlyErrorReporterImpl.report(
        stage: stage,
        error: error,
        stackTrace: stackTrace,
        runId: runId,
        context: context,
      );
}
