/// SMART goal criteria scores (0-100 each)
/// Based on Locke & Latham's Goal Setting Theory
class SMARTScores {
  final double specificity;    // How specific and clear is the task?
  final double measurability;  // Can progress be objectively measured?
  final double achievability;  // Is it realistic given constraints?
  final double relevance;      // How directly does it contribute to the goal?
  final double timeBound;      // Is there a clear timeframe?

  const SMARTScores({
    required this.specificity,
    required this.measurability,
    required this.achievability,
    required this.relevance,
    required this.timeBound,
  });

  /// Overall SMART score (weighted average)
  double get overall {
    // Relevance and Specificity weighted higher based on research
    return (specificity * 0.25 +
            measurability * 0.15 +
            achievability * 0.20 +
            relevance * 0.25 +
            timeBound * 0.15);
  }

  /// Get the weakest SMART dimension (for improvement suggestions)
  String get weakestDimension {
    final scores = {
      'specificity': specificity,
      'measurability': measurability,
      'achievability': achievability,
      'relevance': relevance,
      'timeBound': timeBound,
    };
    return scores.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  /// Get the strongest SMART dimension
  String get strongestDimension {
    final scores = {
      'specificity': specificity,
      'measurability': measurability,
      'achievability': achievability,
      'relevance': relevance,
      'timeBound': timeBound,
    };
    return scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  Map<String, dynamic> toJson() => {
        'specificity': specificity,
        'measurability': measurability,
        'achievability': achievability,
        'relevance': relevance,
        'timeBound': timeBound,
      };

  factory SMARTScores.fromJson(Map<String, dynamic> json) => SMARTScores(
        specificity: (json['specificity'] as num?)?.toDouble() ?? 0.0,
        measurability: (json['measurability'] as num?)?.toDouble() ?? 0.0,
        achievability: (json['achievability'] as num?)?.toDouble() ?? 0.0,
        relevance: (json['relevance'] as num?)?.toDouble() ?? 0.0,
        timeBound: (json['timeBound'] as num?)?.toDouble() ?? 0.0,
      );

  factory SMARTScores.defaultScores() => const SMARTScores(
        specificity: 50.0,
        measurability: 50.0,
        achievability: 50.0,
        relevance: 50.0,
        timeBound: 50.0,
      );
}

/// Eisenhower Matrix classification
enum EisenhowerClass {
  doNow,        // Urgent + Important: Crisis, deadlines
  schedule,     // Not Urgent + Important: Strategic, planning (most valuable!)
  delegate,     // Urgent + Not Important: Interruptions, some calls
  eliminate,    // Not Urgent + Not Important: Time-wasters
}

/// Extension for Eisenhower class helpers
extension EisenhowerClassExtension on EisenhowerClass {
  String get displayName {
    switch (this) {
      case EisenhowerClass.doNow: return 'Do Now';
      case EisenhowerClass.schedule: return 'Schedule';
      case EisenhowerClass.delegate: return 'Delegate';
      case EisenhowerClass.eliminate: return 'Eliminate';
    }
  }

  String get description {
    switch (this) {
      case EisenhowerClass.doNow: return 'Urgent & Important - Handle immediately';
      case EisenhowerClass.schedule: return 'Important but Not Urgent - Plan time for this';
      case EisenhowerClass.delegate: return 'Urgent but Not Important - Can someone else do this?';
      case EisenhowerClass.eliminate: return 'Not Urgent & Not Important - Consider dropping';
    }
  }

  int get quadrant => switch (this) {
    EisenhowerClass.doNow => 1,
    EisenhowerClass.schedule => 2,
    EisenhowerClass.delegate => 3,
    EisenhowerClass.eliminate => 4,
  };
}

/// Effort estimation levels (for velocity calculations)
enum EffortLevel {
  tiny,     // < 15 min
  small,    // 15-30 min
  medium,   // 30 min - 1 hour
  large,    // 1-2 hours
  huge,     // > 2 hours
}

extension EffortLevelExtension on EffortLevel {
  String get displayName => switch (this) {
    EffortLevel.tiny => 'Tiny',
    EffortLevel.small => 'Small',
    EffortLevel.medium => 'Medium',
    EffortLevel.large => 'Large',
    EffortLevel.huge => 'Huge',
  };

  /// Estimated minutes for this effort level
  int get estimatedMinutes => switch (this) {
    EffortLevel.tiny => 10,
    EffortLevel.small => 22,
    EffortLevel.medium => 45,
    EffortLevel.large => 90,
    EffortLevel.huge => 150,
  };

  /// Effort weight for velocity calculations (1-5 scale)
  int get weight => switch (this) {
    EffortLevel.tiny => 1,
    EffortLevel.small => 2,
    EffortLevel.medium => 3,
    EffortLevel.large => 4,
    EffortLevel.huge => 5,
  };
}
