import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../services/client_telemetry_service.dart';

/// Installs the app-wide log handler. Call once at startup, before any code logs.
///
/// Every record is written to `dart:developer` (visible in the IDE and DevTools).
/// SEVERE records are also sent to Cloud Logs via the `report_client_error` callable.
void configureLogging() {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;

  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      sequenceNumber: record.sequenceNumber,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );

    if (record.level >= Level.SEVERE) {
      unawaited(ClientTelemetryService.error(
        stage: record.loggerName,
        error: record.error ?? record.message,
        stackTrace: record.stackTrace,
        message: record.message,
      ));
    }
  });
}
