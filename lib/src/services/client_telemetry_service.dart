import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:logging/logging.dart';

/// Best-effort client→server telemetry for debugging production issues.
///
/// Sends lightweight stage events to Cloud Logs via callable functions so we can
/// debug cases where the client fails before Firestore writes occur.
class ClientTelemetryService {
  const ClientTelemetryService();

  static final _log = Logger('ClientTelemetry');

  static Future<void> event({
    required String stage,
    String? message,
    String? runId,
    Map<String, dynamic>? context,
  }) async {
    try {
      // Fire-and-forget friendly; the caller can await if they want reliability.
      await FirebaseFunctions.instance.httpsCallable('report_client_event').call({
        'stage': stage,
        'message': message,
        'runId': runId,
        'context': context ?? const <String, dynamic>{},
      });
    } catch (e) {
      // Never fail user flows due to telemetry.
      _log.warning('Telemetry event failed', e);
    }
  }

  static Future<void> error({
    required String stage,
    required Object error,
    StackTrace? stackTrace,
    String? message,
    String? runId,
    Map<String, dynamic>? context,
  }) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('report_client_error').call({
        'stage': stage,
        'message': message,
        'runId': runId,
        'error': error.toString(),
        'stack': (stackTrace ?? StackTrace.current).toString(),
        'context': context ?? const <String, dynamic>{},
      });
    } catch (e) {
      _log.warning('Telemetry error report failed', e);
    }
  }

  /// Helper for non-blocking telemetry emission.
  static void emit(Future<void> f) {
    unawaited(f);
  }
}
