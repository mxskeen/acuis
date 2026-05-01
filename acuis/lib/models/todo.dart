import 'smart_scores.dart';
import 'task_status.dart';

class Todo {
  final String id;
  final String title;
  final bool completed;
  final String? goalId;
  final DateTime createdAt;
  final double? alignmentScore;
  final String? alignmentExplanation;
  final bool aiGenerated;
  final String? aiReason;

  // ── New science-backed tracking fields ─────────────────────
  /// When the task was actually completed
  final DateTime? completedAt;

  /// User-defined or AI-estimated effort (1-5 scale)
  final int? estimatedEffort;

  /// Manual urgency classification
  final bool? isUrgent;

  /// Manual importance classification
  final bool? isImportant;

  /// AI-calculated Eisenhower classification
  final EisenhowerClass? eisenhowerClass;

  /// SMART criteria scores
  final SMARTScores? smartScores;

  /// AI-generated improvement suggestion
  final String? improvementSuggestion;

  /// Estimated time to complete (in minutes)
  final int? estimatedMinutes;

  /// Best time to work on this task
  final String? bestTime; // morning, afternoon, evening, anytime

  /// Number of times this task was postponed
  final int postponeCount;

  // ── ADHD-Friendly Gamification Fields ─────────────────────
  /// Current status of the task (replaces boolean completed)
  final TaskStatus status;

  /// When the user started working on this task
  final DateTime? startedAt;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    this.goalId,
    required this.createdAt,
    this.alignmentScore,
    this.alignmentExplanation,
    this.aiGenerated = false,
    this.aiReason,
    // New fields with defaults
    this.completedAt,
    this.estimatedEffort,
    this.isUrgent,
    this.isImportant,
    this.eisenhowerClass,
    this.smartScores,
    this.improvementSuggestion,
    this.estimatedMinutes,
    this.bestTime,
    this.postponeCount = 0,
    // ADHD-friendly fields with defaults
    this.status = TaskStatus.pending,
    this.startedAt,
  });

  /// Get effort level from estimated effort value
  EffortLevel get effortLevel {
    final effort = estimatedEffort ?? 3;
    return EffortLevel.values[(effort - 1).clamp(0, 4)];
  }

  /// Get Eisenhower class (auto-calculated if not set)
  EisenhowerClass get effectiveEisenhowerClass {
    if (eisenhowerClass != null) return eisenhowerClass!;

    // Derive from urgency/importance if available
    final urgent = isUrgent ?? false;
    final important = isImportant ?? (alignmentScore ?? 50) >= 50;

    if (urgent && important) return EisenhowerClass.doNow;
    if (!urgent && important) return EisenhowerClass.schedule;
    if (urgent && !important) return EisenhowerClass.delegate;
    return EisenhowerClass.eliminate;
  }

  /// Get overall SMART score
  double get smartScore => smartScores?.overall ?? 50.0;

  /// Is this a high-impact task (Q1 or Q2)?
  bool get isHighImpact =>
      effectiveEisenhowerClass == EisenhowerClass.doNow ||
      effectiveEisenhowerClass == EisenhowerClass.schedule;

  /// How long has this task been pending?
  int get daysPending =>
      DateTime.now().difference(createdAt).inDays;

  /// Is this task overdue (if it had an implied deadline from goal)?
  bool get isStale => daysPending > 7 && !status.isDone;

  /// Is this task completed? (backward compatible computed property)
  bool get isCompleted => status == TaskStatus.completed;

  /// Is this task in progress?
  bool get isInProgress => status == TaskStatus.inProgress;

  /// Can this task be started?
  bool get canStart => status == TaskStatus.pending;

  /// Get computed 'completed' for backward compatibility
  /// @deprecated Use status.isDone or isCompleted instead
  @Deprecated('Use status.isDone or isCompleted instead')
  bool get legacyCompleted => completed || status == TaskStatus.completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        // Keep both old and new fields for migration period
        'completed': completed || status == TaskStatus.completed,
        'goalId': goalId,
        'createdAt': createdAt.toIso8601String(),
        'alignmentScore': alignmentScore,
        'alignmentExplanation': alignmentExplanation,
        'aiGenerated': aiGenerated,
        'aiReason': aiReason,
        // New fields
        'completedAt': completedAt?.toIso8601String(),
        'estimatedEffort': estimatedEffort,
        'isUrgent': isUrgent,
        'isImportant': isImportant,
        'eisenhowerClass': eisenhowerClass?.name,
        'smartScores': smartScores?.toJson(),
        'improvementSuggestion': improvementSuggestion,
        'estimatedMinutes': estimatedMinutes,
        'bestTime': bestTime,
        'postponeCount': postponeCount,
      // ADHD-friendly fields
      'status': status.name,
      'startedAt': startedAt?.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> json) {
    // Migrate: determine status from new field, fall back to old completed bool
    final status = json['status'] != null
        ? TaskStatus.values.firstWhere(
            (e) => e.name == json['status'],
            orElse: () => json['completed'] == true
                ? TaskStatus.completed
                : TaskStatus.pending,
          )
        : (json['completed'] == true
            ? TaskStatus.completed
            : TaskStatus.pending);

    return Todo(
      id: json['id'],
      title: json['title'],
      completed: json['completed'] ?? false,
      goalId: json['goalId'],
      createdAt: DateTime.parse(json['createdAt']),
      alignmentScore: json['alignmentScore']?.toDouble(),
      alignmentExplanation: json['alignmentExplanation'],
      aiGenerated: json['aiGenerated'] ?? false,
      aiReason: json['aiReason'],
      // New fields
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      estimatedEffort: json['estimatedEffort'],
      isUrgent: json['isUrgent'],
      isImportant: json['isImportant'],
      eisenhowerClass: json['eisenhowerClass'] != null
          ? EisenhowerClass.values.firstWhere(
              (e) => e.name == json['eisenhowerClass'],
              orElse: () => EisenhowerClass.schedule,
            )
          : null,
      smartScores: json['smartScores'] != null
          ? SMARTScores.fromJson(json['smartScores'])
          : null,
      improvementSuggestion: json['improvementSuggestion'],
      estimatedMinutes: json['estimatedMinutes'],
      bestTime: json['bestTime'],
      postponeCount: json['postponeCount'] ?? 0,
      // ADHD-friendly fields
      status: status,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : null,
    );
  }

  Todo copyWith({
    String? id,
    String? title,
    bool? completed,
    String? goalId,
    DateTime? createdAt,
    double? alignmentScore,
    String? alignmentExplanation,
    bool? aiGenerated,
    String? aiReason,
    DateTime? completedAt,
    int? estimatedEffort,
    bool? isUrgent,
    bool? isImportant,
    EisenhowerClass? eisenhowerClass,
    SMARTScores? smartScores,
    String? improvementSuggestion,
    int? estimatedMinutes,
    String? bestTime,
    int? postponeCount,
    TaskStatus? status,
    DateTime? startedAt,
    bool clearCompletedAt = false,
    bool clearEisenhowerClass = false,
    bool clearStartedAt = false,
  }) {
    // Sync completed and status
    final effectiveCompleted = completed ?? this.completed;
    final TaskStatus effectiveStatus;
    if (status != null) {
      effectiveStatus = status;
    } else if (completed == true) {
      // Toggling completed to true → mark as completed
      effectiveStatus = TaskStatus.completed;
    } else if (completed == false && this.completed == true) {
      // Uncompleting → revert to pending
      effectiveStatus = TaskStatus.pending;
    } else {
      effectiveStatus = this.status;
    }

    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: effectiveCompleted,
      goalId: goalId ?? this.goalId,
      createdAt: createdAt ?? this.createdAt,
      alignmentScore: alignmentScore ?? this.alignmentScore,
      alignmentExplanation: alignmentExplanation ?? this.alignmentExplanation,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      aiReason: aiReason ?? this.aiReason,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      estimatedEffort: estimatedEffort ?? this.estimatedEffort,
      isUrgent: isUrgent ?? this.isUrgent,
      isImportant: isImportant ?? this.isImportant,
      eisenhowerClass: clearEisenhowerClass ? null : (eisenhowerClass ?? this.eisenhowerClass),
      smartScores: smartScores ?? this.smartScores,
      improvementSuggestion: improvementSuggestion ?? this.improvementSuggestion,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      bestTime: bestTime ?? this.bestTime,
      postponeCount: postponeCount ?? this.postponeCount,
      status: effectiveStatus,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    );
  }
}
