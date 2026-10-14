import 'dart:convert';
import 'dart:js_interop';

import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

// ignore: avoid_classes_with_only_static_members
class EarlyErrorReporterImpl {
  static final _log = Logger('EarlyErrorReporterImpl');

  // Must be an HTTP endpoint, not a callable.
  static const String _endpoint =
      'https://us-central1-quest-cards-3c47a.cloudfunctions.net/report_client_error_http';

  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;

    web.window.addEventListener(
      'error',
      ((web.Event event) {
        final errorEvent = event.isA<web.ErrorEvent>()
            ? event as web.ErrorEvent
            : null;
        final message = errorEvent?.message ?? 'window.onerror';
        final errorObj = errorEvent?.error?.toString() ?? message;
        final ctx = <String, dynamic>{
          'filename': errorEvent?.filename,
          'lineno': errorEvent?.lineno,
          'colno': errorEvent?.colno,
        };
        // Best-effort; don't await.
        // ignore: discarded_futures
        report(stage: 'window_onError', error: errorObj, context: ctx);
      }).toJS,
    );
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
          'userAgent': web.window.navigator.userAgent,
          ...?context,
        },
      };

      final headers = web.Headers()
        ..append('Content-Type', 'application/json');
      final response = await web.window
          .fetch(
            _endpoint.toJS,
            web.RequestInit(
              method: 'POST',
              headers: headers,
              body: jsonEncode(payload).toJS,
            ),
          )
          .toDart;
      if (!response.ok) {
        throw Exception('HTTP ${response.status}');
      }
    } catch (e) {
      // Never fail user flows due to reporting.
      _log.warning('EarlyErrorReporterImpl.report failed', e);
    }
  }
}
