/// Statistics for backfill operations
class BackfillStats {
  /// Total number of records to process
  final int total;

  /// Number of records processed so far
  final int processed;

  /// Number of records successfully updated with purchase links
  final int successful;

  /// Number of records that already had links and were skipped
  final int skipped;

  /// Number of records that failed to find purchase links
  final int failed;

  /// Number of API calls made
  final int apiCalls;

  /// Get the success rate as a percentage
  double get successRate =>
      processed > 0 ? (successful / processed) * 100 : 0.0;

  /// Get the completion percentage
  double get completionPercentage =>
      total > 0 ? (processed / total) * 100 : 0.0;

  /// Create a new BackfillStats object
  BackfillStats({
    required this.total,
    required this.processed,
    required this.successful,
    required this.skipped,
    required this.failed,
    required this.apiCalls,
  });

  /// Create an empty stats object
  factory BackfillStats.empty() {
    return BackfillStats(
      total: 0,
      processed: 0,
      successful: 0,
      skipped: 0,
      failed: 0,
      apiCalls: 0,
    );
  }

  /// Create a new BackfillStats by incrementing values
  BackfillStats copyWith({
    int? total,
    int? processed,
    int? successful,
    int? skipped,
    int? failed,
    int? apiCalls,
  }) {
    return BackfillStats(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      successful: successful ?? this.successful,
      skipped: skipped ?? this.skipped,
      failed: failed ?? this.failed,
      apiCalls: apiCalls ?? this.apiCalls,
    );
  }

  /// Convert to a map for storage
  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'processed': processed,
      'successful': successful,
      'skipped': skipped,
      'failed': failed,
      'apiCalls': apiCalls,
    };
  }

  /// Create from a map
  factory BackfillStats.fromMap(Map<String, dynamic> map) {
    return BackfillStats(
      total: map['total'] ?? 0,
      processed: map['processed'] ?? 0,
      successful: map['successful'] ?? 0,
      skipped: map['skipped'] ?? 0,
      failed: map['failed'] ?? 0,
      apiCalls: map['apiCalls'] ?? 0,
    );
  }
}
