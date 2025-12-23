// ignore: avoid_classes_with_only_static_members
class EarlyErrorReporterImpl {
  static void install() {}

  static Future<void> report({
    required String stage,
    required Object error,
    StackTrace? stackTrace,
    String? runId,
    Map<String, dynamic>? context,
  }) async {}
}
