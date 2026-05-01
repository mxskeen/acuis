/// User Energy Level
///
/// Represents the user's current energy state for ADHD-aware task recommendations.
enum EnergyLevel {
  low, // Low energy - suggest tiny tasks, rest is ok
  medium, // Normal energy - standard suggestions
  high, // High energy - tackle challenging tasks
}

/// Mood Tags
///
/// Emotional context that affects task recommendations and nudges.
enum MoodTag {
  sick, // Not feeling well - skip nudges, protect streak
  stressed, // High stress - reduce pressure
  tired, // Fatigued - gentle suggestions
  great, // Feeling good - celebrate
  focused, // In flow - sustain momentum
  neutral, // Default state
}

/// User Energy Record
///
/// Captures a snapshot of the user's energy and mood at a specific time.
class UserEnergy {
  final EnergyLevel level;
  final MoodTag? mood;
  final DateTime recordedAt;

  const UserEnergy({
    required this.level,
    this.mood,
    required this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'mood': mood?.name,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory UserEnergy.fromJson(Map<String, dynamic> json) => UserEnergy(
        level: EnergyLevel.values.firstWhere(
          (e) => e.name == json['level'],
          orElse: () => EnergyLevel.medium,
        ),
        mood: json['mood'] != null
            ? MoodTag.values.firstWhere(
                (e) => e.name == json['mood'],
                orElse: () => MoodTag.neutral,
              )
            : null,
        recordedAt: DateTime.parse(json['recordedAt']),
      );

  /// Check if this energy record is from today
  bool get isToday {
    final now = DateTime.now();
    return recordedAt.year == now.year &&
        recordedAt.month == now.month &&
        recordedAt.day == now.day;
  }

  /// Should we skip nudges on this energy level?
  bool get shouldSkipNudges =>
      level == EnergyLevel.low || mood == MoodTag.sick || mood == MoodTag.stressed;

  /// Get appropriate nudge tone for this energy level
  NudgeTone get nudgeTone {
    if (mood == MoodTag.sick) return NudgeTone.supportive;
    if (mood == MoodTag.stressed) return NudgeTone.gentle;
    if (level == EnergyLevel.low) return NudgeTone.encouraging;
    if (level == EnergyLevel.high) return NudgeTone.energetic;
    return NudgeTone.neutral;
  }
}

/// Tone of nudge messages based on user's energy
enum NudgeTone {
  supportive, // "Rest is productive too"
  gentle, // "Even 5 minutes counts"
  encouraging, // "You've got this"
  energetic, // "Let's crush it!"
  neutral, // Standard messages
}

/// Pattern Insight
///
/// Detected pattern from user's energy tracking history.
class PatternInsight {
  final String pattern;
  final String insight;
  final double confidence; // 0.0 to 1.0

  const PatternInsight({
    required this.pattern,
    required this.insight,
    required this.confidence,
  });
}
