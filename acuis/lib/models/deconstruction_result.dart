// Data model for First Principles Deconstruction
// 1. Identify assumptions the user is making
// 2. Find fundamental truths by challenging those assumptions
// 3. Reconstruct a minimal plan based on confirmed truths

class Assumption {
  final String text;
  final bool isChallenged; // user removed/disagreed with this assumption

  const Assumption({
    required this.text,
    this.isChallenged = false,
  });

  Assumption copyWith({
    String? text,
    bool? isChallenged,
  }) =>
      Assumption(
        text: text ?? this.text,
        isChallenged: isChallenged ?? this.isChallenged,
      );

  factory Assumption.fromJson(Map<String, dynamic> json) => Assumption(
        text: json['text'] as String? ?? '',
        isChallenged: json['isChallenged'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'isChallenged': isChallenged,
      };
}

class Truth {
  final String text;
  final String explanation;
  final bool isConfirmed; // user confirmed this truth

  const Truth({
    required this.text,
    required this.explanation,
    this.isConfirmed = false,
  });

  Truth copyWith({
    String? text,
    String? explanation,
    bool? isConfirmed,
  }) =>
      Truth(
        text: text ?? this.text,
        explanation: explanation ?? this.explanation,
        isConfirmed: isConfirmed ?? this.isConfirmed,
      );

  factory Truth.fromJson(Map<String, dynamic> json) => Truth(
        text: json['text'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
        isConfirmed: json['isConfirmed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'explanation': explanation,
        'isConfirmed': isConfirmed,
      };
}

class DeconstructionResult {
  final List<Assumption> assumptions;
  final List<Truth> truths;
  final List<ReconstructedTask> reconstructedTasks;

  const DeconstructionResult({
    this.assumptions = const [],
    this.truths = const [],
    this.reconstructedTasks = const [],
  });

  DeconstructionResult copyWith({
    List<Assumption>? assumptions,
    List<Truth>? truths,
    List<ReconstructedTask>? reconstructedTasks,
  }) =>
      DeconstructionResult(
        assumptions: assumptions ?? this.assumptions,
        truths: truths ?? this.truths,
        reconstructedTasks: reconstructedTasks ?? this.reconstructedTasks,
      );
}

/// A task generated from first principles reconstruction
class ReconstructedTask {
  final String title;
  final String? reason;
  final String? effort; // tiny, small, medium, large, huge
  final String? bestTime; // morning, afternoon, evening, anytime
  final int? estimatedMinutes;

  const ReconstructedTask({
    required this.title,
    this.reason,
    this.effort,
    this.bestTime,
    this.estimatedMinutes,
  });

  factory ReconstructedTask.fromJson(Map<String, dynamic> json) =>
      ReconstructedTask(
        title: json['title'] as String? ?? '',
        reason: json['reason'] as String?,
        effort: json['effort'] as String?,
        bestTime: json['best_time'] as String?,
        estimatedMinutes: json['estimated_minutes'] as int?,
      );
}
