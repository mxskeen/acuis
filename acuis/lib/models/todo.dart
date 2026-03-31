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
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'goalId': goalId,
        'createdAt': createdAt.toIso8601String(),
        'alignmentScore': alignmentScore,
        'alignmentExplanation': alignmentExplanation,
        'aiGenerated': aiGenerated,
        'aiReason': aiReason,
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'],
        title: json['title'],
        completed: json['completed'] ?? false,
        goalId: json['goalId'],
        createdAt: DateTime.parse(json['createdAt']),
        alignmentScore: json['alignmentScore']?.toDouble(),
        alignmentExplanation: json['alignmentExplanation'],
        aiGenerated: json['aiGenerated'] ?? false,
        aiReason: json['aiReason'],
      );

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
  }) =>
      Todo(
        id: id ?? this.id,
        title: title ?? this.title,
        completed: completed ?? this.completed,
        goalId: goalId ?? this.goalId,
        createdAt: createdAt ?? this.createdAt,
        alignmentScore: alignmentScore ?? this.alignmentScore,
        alignmentExplanation: alignmentExplanation ?? this.alignmentExplanation,
        aiGenerated: aiGenerated ?? this.aiGenerated,
        aiReason: aiReason ?? this.aiReason,
      );
}
