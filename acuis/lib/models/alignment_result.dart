import 'smart_scores.dart';

/// Enhanced alignment result with science-backed breakdown
/// Combines SMART criteria, Eisenhower classification, and velocity fit
class AlignmentResult {
  /// Overall alignment score (0-100)
  final double score;

  /// Human-readable explanation
  final String explanation;

  /// SMART criteria breakdown
  final SMARTScores? smartScores;

  /// Eisenhower Matrix classification
  final EisenhowerClass? eisenhowerClass;

  /// Estimated effort level
  final EffortLevel? estimatedEffort;

  /// AI-generated suggestion for improvement
  final String? suggestion;

  /// Component scores for transparency
  final AlignmentComponents components;

  /// Whether this was AI-generated or rule-based fallback
  final bool isAIGenerated;

  const AlignmentResult({
    required this.score,
    required this.explanation,
    this.smartScores,
    this.eisenhowerClass,
    this.estimatedEffort,
    this.suggestion,
    required this.components,
    this.isAIGenerated = true,
  });

  /// Create a fallback result when AI fails
  factory AlignmentResult.fallback({
    required double score,
    required String explanation,
    SMARTScores? smartScores,
  }) =>
      AlignmentResult(
        score: score,
        explanation: explanation,
        smartScores: smartScores,
        components: AlignmentComponents(
          smartScore: smartScores?.overall ?? score,
          eisenhowerWeight: 50,
          velocityFit: 50,
        ),
        isAIGenerated: false,
      );

  /// Create an error result
  factory AlignmentResult.error(String message) => AlignmentResult(
        score: -1,
        explanation: message,
        components: const AlignmentComponents(
          smartScore: 0,
          eisenhowerWeight: 0,
          velocityFit: 0,
        ),
        isAIGenerated: false,
      );

  /// Get alignment quality label
  String get qualityLabel {
    if (score < 0) return 'Error';
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Good';
    if (score >= 50) return 'Moderate';
    if (score >= 25) return 'Low';
    return 'Poor';
  }

  /// Get the primary improvement area
  String? get primaryImprovementArea {
    if (smartScores == null) return null;
    return smartScores!.weakestDimension;
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'explanation': explanation,
        'smartScores': smartScores?.toJson(),
        'eisenhowerClass': eisenhowerClass?.name,
        'estimatedEffort': estimatedEffort?.name,
        'suggestion': suggestion,
        'components': components.toJson(),
        'isAIGenerated': isAIGenerated,
      };

  factory AlignmentResult.fromJson(Map<String, dynamic> json) =>
      AlignmentResult(
        score: (json['score'] as num?)?.toDouble() ?? 0,
        explanation: json['explanation'] as String? ?? '',
        smartScores: json['smartScores'] != null
            ? SMARTScores.fromJson(json['smartScores'])
            : null,
        eisenhowerClass: json['eisenhowerClass'] != null
            ? EisenhowerClass.values.firstWhere(
                (e) => e.name == json['eisenhowerClass'],
                orElse: () => EisenhowerClass.schedule,
              )
            : null,
        estimatedEffort: json['estimatedEffort'] != null
            ? EffortLevel.values.firstWhere(
                (e) => e.name == json['estimatedEffort'],
                orElse: () => EffortLevel.medium,
              )
            : null,
        suggestion: json['suggestion'] as String?,
        components: json['components'] != null
            ? AlignmentComponents.fromJson(json['components'])
            : AlignmentComponents.defaultComponents(),
        isAIGenerated: json['isAIGenerated'] as bool? ?? true,
      );
}

/// Component scores that make up the overall alignment
class AlignmentComponents {
  /// SMART criteria score (50% weight)
  final double smartScore;

  /// Eisenhower classification weight (25% weight)
  final double eisenhowerWeight;

  /// Velocity fit score - is this achievable given user's pace? (25% weight)
  final double velocityFit;

  const AlignmentComponents({
    required this.smartScore,
    required this.eisenhowerWeight,
    required this.velocityFit,
  });

  /// Calculate weighted overall score
  double get weightedOverall =>
      (smartScore * 0.50) + (eisenhowerWeight * 0.25) + (velocityFit * 0.25);

  factory AlignmentComponents.defaultComponents() => const AlignmentComponents(
        smartScore: 50,
        eisenhowerWeight: 50,
        velocityFit: 50,
      );

  Map<String, dynamic> toJson() => {
        'smartScore': smartScore,
        'eisenhowerWeight': eisenhowerWeight,
        'velocityFit': velocityFit,
      };

  factory AlignmentComponents.fromJson(Map<String, dynamic> json) =>
      AlignmentComponents(
        smartScore: (json['smartScore'] as num?)?.toDouble() ?? 50,
        eisenhowerWeight: (json['eisenhowerWeight'] as num?)?.toDouble() ?? 50,
        velocityFit: (json['velocityFit'] as num?)?.toDouble() ?? 50,
      );
}

/// Scoring context for alignment analysis
class ScoringContext {
  /// User's current velocity (tasks/day)
  final double velocity;

  /// Days until the goal's target date
  final int daysUntilTarget;

  /// User's current streak
  final int currentStreak;

  /// Number of tasks completed today
  final int tasksCompletedToday;

  /// Average effort of recent tasks
  final double avgEffort;

  const ScoringContext({
    required this.velocity,
    required this.daysUntilTarget,
    this.currentStreak = 0,
    this.tasksCompletedToday = 0,
    this.avgEffort = 2.0,
  });

  factory ScoringContext.empty() => const ScoringContext(
        velocity: 0,
        daysUntilTarget: 30,
      );

  /// Whether we have enough data for velocity-based predictions
  bool get hasVelocityData => velocity > 0;

  /// Whether the goal has a target date
  bool get hasTargetDate => daysUntilTarget > 0;
}
