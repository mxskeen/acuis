/// A science-backed journey plan for achieving a goal
/// Evidence: Locke & Latham - specific, challenging goals with feedback
class JourneyPlan {
  final String id;
  final String goalId;

  // The "Why" - increases commitment (Locke & Latham)
  final String? commitmentStatement;

  // Milestones with implementation intentions (Gollwitzer)
  final List<JourneyMilestone> milestones;

  // Tiny habit anchor (Fogg)
  final HabitAnchor? primaryAnchor;

  // Duration parameters
  final int estimatedDaysTotal;
  final String difficulty; // easy, moderate, challenging
  final DateTime createdAt;

  // Daily commitment
  final int dailyMinutesCommitted;

  // Meta
  final DurationEstimate? durationEstimate;

  const JourneyPlan({
    required this.id,
    required this.goalId,
    this.commitmentStatement,
    this.milestones = const [],
    this.primaryAnchor,
    required this.estimatedDaysTotal,
    this.difficulty = 'moderate',
    required this.createdAt,
    this.dailyMinutesCommitted = 15,
    this.durationEstimate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'goalId': goalId,
        'commitmentStatement': commitmentStatement,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'primaryAnchor': primaryAnchor?.toJson(),
        'estimatedDaysTotal': estimatedDaysTotal,
        'difficulty': difficulty,
        'createdAt': createdAt.toIso8601String(),
        'dailyMinutesCommitted': dailyMinutesCommitted,
        'durationEstimate': durationEstimate?.toJson(),
      };

  factory JourneyPlan.fromJson(Map<String, dynamic> json) => JourneyPlan(
        id: json['id'] as String,
        goalId: json['goalId'] as String,
        commitmentStatement: json['commitmentStatement'] as String?,
        milestones: (json['milestones'] as List?)
                ?.map((m) => JourneyMilestone.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        primaryAnchor: json['primaryAnchor'] != null
            ? HabitAnchor.fromJson(json['primaryAnchor'] as Map<String, dynamic>)
            : null,
        estimatedDaysTotal: json['estimatedDaysTotal'] as int? ?? 90,
        difficulty: json['difficulty'] as String? ?? 'moderate',
        createdAt: DateTime.parse(json['createdAt'] as String),
        dailyMinutesCommitted: json['dailyMinutesCommitted'] as int? ?? 15,
        durationEstimate: json['durationEstimate'] != null
            ? DurationEstimate.fromJson(
                json['durationEstimate'] as Map<String, dynamic>)
            : null,
      );

  JourneyPlan copyWith({
    String? id,
    String? goalId,
    String? commitmentStatement,
    List<JourneyMilestone>? milestones,
    HabitAnchor? primaryAnchor,
    int? estimatedDaysTotal,
    String? difficulty,
    DateTime? createdAt,
    int? dailyMinutesCommitted,
    DurationEstimate? durationEstimate,
  }) {
    return JourneyPlan(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      commitmentStatement: commitmentStatement ?? this.commitmentStatement,
      milestones: milestones ?? this.milestones,
      primaryAnchor: primaryAnchor ?? this.primaryAnchor,
      estimatedDaysTotal: estimatedDaysTotal ?? this.estimatedDaysTotal,
      difficulty: difficulty ?? this.difficulty,
      createdAt: createdAt ?? this.createdAt,
      dailyMinutesCommitted:
          dailyMinutesCommitted ?? this.dailyMinutesCommitted,
      durationEstimate: durationEstimate ?? this.durationEstimate,
    );
  }
}

/// A milestone within a journey
class JourneyMilestone {
  final String id;
  final String title;
  final String description;
  final int startDay;
  final int endDay;
  final String phase; // foundation, building, advancing, finishing
  final List<String> keyOutcomes;
  final bool isCompleted;
  final DateTime? completedAt;

  const JourneyMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.startDay,
    required this.endDay,
    required this.phase,
    this.keyOutcomes = const [],
    this.isCompleted = false,
    this.completedAt,
  });

  int get durationDays => endDay - startDay + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'startDay': startDay,
        'endDay': endDay,
        'phase': phase,
        'keyOutcomes': keyOutcomes,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory JourneyMilestone.fromJson(Map<String, dynamic> json) =>
      JourneyMilestone(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        startDay: json['startDay'] as int,
        endDay: json['endDay'] as int,
        phase: json['phase'] as String? ?? 'building',
        keyOutcomes: (json['keyOutcomes'] as List?)
                ?.map((o) => o.toString())
                .toList() ??
            [],
        isCompleted: json['isCompleted'] as bool? ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );

  JourneyMilestone copyWith({
    String? id,
    String? title,
    String? description,
    int? startDay,
    int? endDay,
    String? phase,
    List<String>? keyOutcomes,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return JourneyMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDay: startDay ?? this.startDay,
      endDay: endDay ?? this.endDay,
      phase: phase ?? this.phase,
      keyOutcomes: keyOutcomes ?? this.keyOutcomes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Fogg's Tiny Habit anchor
class HabitAnchor {
  final String trigger;
  final String action;
  final String? celebration;
  final String timeOfDay;

  const HabitAnchor({
    required this.trigger,
    required this.action,
    this.celebration,
    this.timeOfDay = 'morning',
  });

  Map<String, dynamic> toJson() => {
        'trigger': trigger,
        'action': action,
        'celebration': celebration,
        'timeOfDay': timeOfDay,
      };

  factory HabitAnchor.fromJson(Map<String, dynamic> json) => HabitAnchor(
        trigger: json['trigger'] as String,
        action: json['action'] as String,
        celebration: json['celebration'] as String?,
        timeOfDay: json['timeOfDay'] as String? ?? 'morning',
      );
}

/// LLM-generated duration estimate with options
class DurationEstimate {
  final int minimumDays;
  final int recommendedDays;
  final int maximumDays;
  final int dailyMinutesMinimum;
  final int dailyMinutesRecommended;
  final int dailyMinutesMaximum;
  final String complexity;
  final String reasoning;

  const DurationEstimate({
    required this.minimumDays,
    required this.recommendedDays,
    required this.maximumDays,
    this.dailyMinutesMinimum = 10,
    this.dailyMinutesRecommended = 15,
    this.dailyMinutesMaximum = 30,
    this.complexity = 'moderate',
    this.reasoning = '',
  });

  Map<String, dynamic> toJson() => {
        'minimumDays': minimumDays,
        'recommendedDays': recommendedDays,
        'maximumDays': maximumDays,
        'dailyMinutesMinimum': dailyMinutesMinimum,
        'dailyMinutesRecommended': dailyMinutesRecommended,
        'dailyMinutesMaximum': dailyMinutesMaximum,
        'complexity': complexity,
        'reasoning': reasoning,
      };

  factory DurationEstimate.fromJson(Map<String, dynamic> json) =>
      DurationEstimate(
        minimumDays: json['minimumDays'] as int? ?? 30,
        recommendedDays: json['recommendedDays'] as int? ?? 90,
        maximumDays: json['maximumDays'] as int? ?? 180,
        dailyMinutesMinimum: json['dailyMinutesMinimum'] as int? ?? 10,
        dailyMinutesRecommended: json['dailyMinutesRecommended'] as int? ?? 15,
        dailyMinutesMaximum: json['dailyMinutesMaximum'] as int? ?? 30,
        complexity: json['complexity'] as String? ?? 'moderate',
        reasoning: json['reasoning'] as String? ?? '',
      );
}
