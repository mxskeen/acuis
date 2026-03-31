/// Velocity-based prediction for goal completion
/// Based on Agile/Scrum velocity tracking methodology
class VelocityPrediction {
  /// Expected number of days to complete remaining tasks
  final int expectedDays;

  /// Best case scenario (average velocity + 1 standard deviation)
  final int bestCaseDays;

  /// Worst case scenario (average velocity - 1 standard deviation)
  final int worstCaseDays;

  /// Confidence level (0-100) based on data quality
  final int confidence;

  /// Current velocity (tasks or points per day)
  final double velocity;

  /// Total tasks remaining
  final int remainingTasks;

  /// Data quality indicator
  final VelocityDataQuality dataQuality;

  const VelocityPrediction({
    required this.expectedDays,
    required this.bestCaseDays,
    required this.worstCaseDays,
    required this.confidence,
    required this.velocity,
    required this.remainingTasks,
    required this.dataQuality,
  });

  /// Create a prediction indicating insufficient data
  factory VelocityPrediction.insufficientData() => const VelocityPrediction(
        expectedDays: -1,
        bestCaseDays: -1,
        worstCaseDays: -1,
        confidence: 0,
        velocity: 0,
        remainingTasks: 0,
        dataQuality: VelocityDataQuality.insufficient,
      );

  /// Whether we have enough data for a reliable prediction
  bool get hasReliablePrediction =>
      dataQuality != VelocityDataQuality.insufficient && expectedDays > 0;

  /// Predicted completion date from now
  DateTime get expectedCompletionDate =>
      DateTime.now().add(Duration(days: expectedDays));

  /// Best case completion date
  DateTime get bestCaseCompletionDate =>
      DateTime.now().add(Duration(days: bestCaseDays));

  /// Worst case completion date
  DateTime get worstCaseCompletionDate =>
      DateTime.now().add(Duration(days: worstCaseDays));

  /// Human-readable prediction summary
  String get summary {
    if (!hasReliablePrediction) {
      return 'Not enough data to predict';
    }

    if (expectedDays == 0) {
      return 'Complete today!';
    } else if (expectedDays == 1) {
      return 'Complete tomorrow';
    } else if (expectedDays <= 7) {
      return 'Complete in $expectedDays days';
    } else if (expectedDays <= 30) {
      final weeks = (expectedDays / 7).round();
      return 'Complete in ${weeks == 1 ? '1 week' : '$weeks weeks'}';
    } else {
      final months = (expectedDays / 30).round();
      return 'Complete in ${months == 1 ? '1 month' : '$months months'}';
    }
  }

  /// Confidence level description
  String get confidenceDescription => switch (confidence) {
    >= 80 => 'High confidence',
    >= 50 => 'Moderate confidence',
    >= 25 => 'Low confidence',
    _ => 'Very low confidence',
  };

  Map<String, dynamic> toJson() => {
        'expectedDays': expectedDays,
        'bestCaseDays': bestCaseDays,
        'worstCaseDays': worstCaseDays,
        'confidence': confidence,
        'velocity': velocity,
        'remainingTasks': remainingTasks,
        'dataQuality': dataQuality.name,
      };

  factory VelocityPrediction.fromJson(Map<String, dynamic> json) =>
      VelocityPrediction(
        expectedDays: json['expectedDays'] as int? ?? -1,
        bestCaseDays: json['bestCaseDays'] as int? ?? -1,
        worstCaseDays: json['worstCaseDays'] as int? ?? -1,
        confidence: json['confidence'] as int? ?? 0,
        velocity: (json['velocity'] as num?)?.toDouble() ?? 0,
        remainingTasks: json['remainingTasks'] as int? ?? 0,
        dataQuality: VelocityDataQuality.values.firstWhere(
          (e) => e.name == json['dataQuality'],
          orElse: () => VelocityDataQuality.insufficient,
        ),
      );
}

/// Data quality levels for velocity predictions
enum VelocityDataQuality {
  insufficient,  // < 3 days of data
  poor,          // 3-7 days
  moderate,      // 1-2 weeks
  good,          // 2-4 weeks
  excellent,     // > 4 weeks
}

/// Historical velocity data point for tracking
class VelocitySnapshot {
  final DateTime date;
  final int tasksCompleted;
  final int pointsCompleted; // Weighted by effort
  final int totalTasks;
  final int completedTasks;

  const VelocitySnapshot({
    required this.date,
    required this.tasksCompleted,
    required this.pointsCompleted,
    required this.totalTasks,
    required this.completedTasks,
  });

  double get completionRate =>
      totalTasks > 0 ? completedTasks / totalTasks : 0.0;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'tasksCompleted': tasksCompleted,
        'pointsCompleted': pointsCompleted,
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
      };

  factory VelocitySnapshot.fromJson(Map<String, dynamic> json) =>
      VelocitySnapshot(
        date: DateTime.parse(json['date']),
        tasksCompleted: json['tasksCompleted'] as int? ?? 0,
        pointsCompleted: json['pointsCompleted'] as int? ?? 0,
        totalTasks: json['totalTasks'] as int? ?? 0,
        completedTasks: json['completedTasks'] as int? ?? 0,
      );
}
