import 'dart:convert';
import 'dart:developer';
import 'dart:html' as html;

// ignore: avoid_classes_with_only_static_members
class EarlyErrorReporterImpl {
  // Must be an HTTP endpoint, not a callable.
  static const String _endpoint =
      'https://us-central1-quest-cards-3c47a.cloudfunctions.net/report_client_error_http';

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;

    html.window.onError.listen((event) {
      final errorEvent = event is html.ErrorEvent ? event : null;
      final message = errorEvent?.message ?? 'window.onerror';
      final errorObj = errorEvent?.error ?? message;
      final ctx = <String, dynamic>{
        'filename': errorEvent?.filename,
        'lineno': errorEvent?.lineno,
        'colno': errorEvent?.colno,
      };
      // Best-effort; don't await.
      // ignore: discarded_futures
      report(stage: 'window_onError', error: errorObj, context: ctx);
    });
  }

  static Future<void> report({
    required String stage,
    required Object error,
    StackTrace? stackTrace,
    String? runId,
    Map<String, dynamic>? context,
  }) async {
    try {
      final payload = {
        'stage': stage,
        'message': 'Early error report',
        'runId': runId,
        'error': error.toString(),
        'stack': (stackTrace ?? StackTrace.current).toString(),
        'context': {
          'userAgent': html.window.navigator.userAgent,
          ...?context,
        },
      };

      await html.HttpRequest.request(
        _endpoint,
        method: 'POST',
        sendData: jsonEncode(payload),
        requestHeaders: const {
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      // Never fail user flows due to reporting.
      log('EarlyErrorReporterImpl.report failed: $e');
    }
  }
}
