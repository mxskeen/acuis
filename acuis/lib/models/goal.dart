enum GoalType { shortTerm, longTerm }

class Goal {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final DateTime createdAt;
  final DateTime? targetDate;

  // ── New science-backed fields ─────────────────────────────
  /// Key milestones for this goal
  final List<String> milestones;

  /// Self-reported commitment level (1-10)
  final int? commitmentLevel;

  /// User's why - why this goal matters to them
  final String? motivationStatement;

  /// Category for grouping (health, career, learning, etc.)
  final String? category;

  /// Expected number of tasks to complete this goal
  final int? expectedTaskCount;

  /// Goal status
  final GoalStatus status;

  /// When the goal was achieved (if applicable)
  final DateTime? achievedAt;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.targetDate,
    // New fields with defaults
    this.milestones = const [],
    this.commitmentLevel,
    this.motivationStatement,
    this.category,
    this.expectedTaskCount,
    this.status = GoalStatus.active,
    this.achievedAt,
  });

  /// Days remaining until target date (0 if no target or passed)
  int get daysRemaining {
    if (targetDate == null) return 0;
    final remaining = targetDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// Is this goal overdue?
  bool get isOverdue {
    if (targetDate == null) return false;
    return DateTime.now().isAfter(targetDate!);
  }

  /// Is this goal approaching deadline (within 7 days)?
  bool get isApproachingDeadline {
    return daysRemaining > 0 && daysRemaining <= 7;
  }

  /// Get time context for the goal
  String get timeContext {
    if (type == GoalType.shortTerm) {
      return 'Short-term (1-3 months)';
    } else {
      return 'Long-term (6-12 months)';
    }
  }

  /// Get suggested timeframe based on type
  int get suggestedDays => type == GoalType.shortTerm ? 90 : 365;

  /// Is this a high-commitment goal?
  bool get isHighCommitment => (commitmentLevel ?? 5) >= 8;

  /// Calculate urgency score for prioritization
  int get urgencyScore {
    int score = 0;
    if (isOverdue) score += 40;
    else if (isApproachingDeadline) score += 30;
    else if (daysRemaining > 0 && daysRemaining <= 14) score += 20;

    score += (commitmentLevel ?? 5) * 5;
    return score.clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'targetDate': targetDate?.toIso8601String(),
        // New fields
        'milestones': milestones,
        'commitmentLevel': commitmentLevel,
        'motivationStatement': motivationStatement,
        'category': category,
        'expectedTaskCount': expectedTaskCount,
        'status': status.name,
        'achievedAt': achievedAt?.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        type: GoalType.values.firstWhere((e) => e.name == json['type']),
        createdAt: DateTime.parse(json['createdAt']),
        targetDate: json['targetDate'] != null
            ? DateTime.parse(json['targetDate'])
            : null,
        // New fields
        milestones: json['milestones'] != null
            ? List<String>.from(json['milestones'])
            : [],
        commitmentLevel: json['commitmentLevel'],
        motivationStatement: json['motivationStatement'],
        category: json['category'],
        expectedTaskCount: json['expectedTaskCount'],
        status: json['status'] != null
            ? GoalStatus.values.firstWhere(
                (e) => e.name == json['status'],
                orElse: () => GoalStatus.active,
              )
            : GoalStatus.active,
        achievedAt: json['achievedAt'] != null
            ? DateTime.parse(json['achievedAt'])
            : null,
      );

  Goal copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    DateTime? createdAt,
    DateTime? targetDate,
    List<String>? milestones,
    int? commitmentLevel,
    String? motivationStatement,
    String? category,
    int? expectedTaskCount,
    GoalStatus? status,
    DateTime? achievedAt,
    bool clearTargetDate = false,
    bool clearAchievedAt = false,
  }) =>
      Goal(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
        milestones: milestones ?? this.milestones,
        commitmentLevel: commitmentLevel ?? this.commitmentLevel,
        motivationStatement: motivationStatement ?? this.motivationStatement,
        category: category ?? this.category,
        expectedTaskCount: expectedTaskCount ?? this.expectedTaskCount,
        status: status ?? this.status,
        achievedAt: clearAchievedAt ? null : (achievedAt ?? this.achievedAt),
      );
}

/// Goal status enum
enum GoalStatus {
  active,       // Currently working on
  paused,       // Temporarily paused
  completed,    // Successfully achieved
  abandoned,    // No longer pursuing
}

extension GoalStatusExtension on GoalStatus {
  String get displayName => switch (this) {
    GoalStatus.active => 'Active',
    GoalStatus.paused => 'Paused',
    GoalStatus.completed => 'Completed',
    GoalStatus.abandoned => 'Archived',
  };

  String get emoji => switch (this) {
    GoalStatus.active => '🎯',
    GoalStatus.paused => '⏸️',
    GoalStatus.completed => '✅',
    GoalStatus.abandoned => '📁',
  };
}
