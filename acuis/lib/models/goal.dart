enum GoalType { shortTerm, longTerm }

class Goal {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final DateTime createdAt;
  final DateTime? targetDate;

  Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.createdAt,
    this.targetDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'createdAt': createdAt.toIso8601String(),
        'targetDate': targetDate?.toIso8601String(),
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        type: GoalType.values.firstWhere((e) => e.name == json['type']),
        createdAt: DateTime.parse(json['createdAt']),
        targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate']) : null,
      );
}
