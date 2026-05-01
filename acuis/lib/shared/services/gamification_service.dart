import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/todo.dart';
import '../../models/goal.dart';
import '../../models/smart_scores.dart';
import '../../models/task_status.dart';
import 'streak_service.dart';
import 'xp_tracking_service.dart';


/// Gamification Service
///
/// Motivation and engagement features based on behavioral science:
/// - Variable Rewards (celebrations for achievements)
/// - Loss Aversion (streak protection)
/// - Progress Visualization (near-completion motivation)
/// - BJ Fogg's Tiny Habits (celebration triggers)
class GamificationService {
  static const _totalPointsKey = 'gamification_total_points';
  static const _levelKey = 'gamification_level';
  static const _achievementsKey = 'gamification_achievements';
  static const _lastNudgeKey = 'gamification_last_nudge';
  static const _dailyWinsKey = 'gamification_daily_wins';

  final SharedPreferences _prefs;
  final StreakService _streakService;
  final XPTrackingService _xpTracking;

  GamificationService(this._prefs, this._streakService, this._xpTracking);

  static Future<GamificationService> init() async {
    final prefs = await SharedPreferences.getInstance();
    final streakService = await StreakService.init();
    final xpTracking = await XPTrackingService.init();
    return GamificationService(prefs, streakService, xpTracking);
  }

  // ── Celebration Triggers ────────────────────────────────────────

  /// Check if completing this todo triggers a celebration
  Celebration? checkCelebration(Todo todo, Goal goal) {
    // High alignment completion - big win!
    if (todo.alignmentScore != null && todo.alignmentScore! >= 80) {
      return Celebration.highAlignment(
        message: _generateHighAlignmentMessage(todo, goal),
        points: _calculatePoints(todo),
      );
    }

    // SMART score excellence
    if (todo.smartScores != null && todo.smartScore >= 85) {
      return Celebration.smartExcellence(
        message: _generateSmartMessage(todo),
        points: _calculatePoints(todo),
      );
    }

    // Eisenhower Q1/Q2 completion (high impact)
    if (todo.isHighImpact && todo.isCompleted) {
      return Celebration.highImpact(
        message: _generateHighImpactMessage(todo),
        points: _calculatePoints(todo),
      );
    }

    // Goal completion celebration
    return null;
  }

  /// Check for goal completion celebration
  Celebration? checkGoalCompletion(Goal goal, List<Todo> todos) {
    final goalTodos = todos.where((t) => t.goalId == goal.id).toList();
    final completed = goalTodos.where((t) => t.isCompleted).length;

    if (completed == goalTodos.length && goalTodos.isNotEmpty) {
      final points = goalTodos.fold<int>(0, (sum, t) => sum + _calculatePoints(t));
      return Celebration.goalComplete(
        message: _generateGoalCompleteMessage(goal),
        points: points + 100, // Bonus for goal completion
      );
    }

    return null;
  }

  // ── Initiation XP (ADHD-Friendly Dopamine Hits) ───────────────────

  /// Award XP when user starts a task (not just completes it)
  /// This gives dopamine at the resistance point (starting), not the end
  InitiationResult? awardInitiationXP(Todo todo) {
    // Only award if task is now in progress and hasn't been started before
    if (todo.status != TaskStatus.inProgress) return null;
    if (_xpTracking.hasBeenStarted(todo.id)) return null;

    final points = _calculateInitiationPoints(todo);
    _xpTracking.markTodoAsStarted(todo.id);

    final levelUp = addPoints(points);

    return InitiationResult(
      points: points,
      levelUp: levelUp,
      isFirstTaskOfDay: _xpTracking.getStartedTodoIds().length == 1,
    );
  }

  /// Calculate points for starting a task (smaller than completion)
  int _calculateInitiationPoints(Todo todo) {
    int basePoints = 5; // Half of completion base

    // Difficulty bonus (bigger for hard tasks you actually started)
    basePoints += (todo.estimatedEffort ?? 3);

    // Eisenhower bonus (starting important tasks is hard)
    if (todo.effectiveEisenhowerClass == EisenhowerClass.doNow) {
      basePoints += 3; // Extra dopamine for tackling urgent+important
    } else if (todo.effectiveEisenhowerClass == EisenhowerClass.eliminate) {
      // If user is starting an "eliminate" task, they might be
      // avoiding real work - but still reward for momentum
      basePoints -= 2;
    }

    // First task bonus (helps build momentum)
    if (_xpTracking.getStartedTodoIds().isEmpty) {
      basePoints += 5;
    }

    return basePoints.clamp(3, 20);
  }

  /// Award continuation XP for sustained focus (e.g., Pomodoro session)
  ContinuationResult? awardContinuationXP(String todoId, int minutesFocused) {
    if (minutesFocused < 5) return null; // Minimum 5 minutes

    // Award points based on focus duration
    final points = (minutesFocused / 10).round().clamp(1, 10);

    final levelUp = addPoints(points);

    return ContinuationResult(
      points: points,
      minutesFocused: minutesFocused,
      levelUp: levelUp,
    );
  }

  /// Check for streak support (ADHD-friendly, non-anxiety-inducing)
  /// Replaces the old anxious streak warning with supportive messaging
  Celebration? checkStreakSupport() {
    final streak = _streakService.getCurrentStreak();
    if (streak < 3) return null;

    final lastCompletion = _streakService.getLastCompletionDate();
    final today = _getTodayString();

    // Already completed today - positive reinforcement
    if (lastCompletion == today) {
      return Celebration.streakSupport(
        streak: streak,
        message: streak >= 7
            ? '$streak-day streak strong! Take it easy today if you need to.'
            : 'Building momentum! $streak days and counting.',
      );
    }

    // Check if streak is at risk (but not anxiety-inducing)
    if (lastCompletion != null) {
      final lastDate = DateTime.parse(lastCompletion);
      final todayDate = DateTime.parse(today);
      final hoursLeft = 24 - DateTime.now().hour;

      if (todayDate.difference(lastDate).inDays == 1 && hoursLeft <= 6) {
        // Check if we have grace days available
        final graceDays = _streakService.getGraceDaysRemaining();
        if (graceDays > 0) {
          return Celebration.streakSupport(
            streak: streak,
            message:
                '$streak-day streak! You have $graceDays grace day${graceDays == 1 ? '' : 's'} if you need a break.',
          );
        }

        return Celebration.streakSupport(
          streak: streak,
          message:
              '$streak days so far! Even a tiny task keeps the momentum.',
        );
      }
    }

    return null;
  }

  // ── Smart Nudges ─────────────────────────────────────────────────

  /// Generate AI-powered smart nudge
  /// Based on BJ Fogg's prompt design: "After [Trigger], I will [Action]"
  SmartNudge? generateNudge(String userName, List<Goal> goals, List<Todo> todos) {
    // Don't nudge too frequently
    final lastNudge = _prefs.getString(_lastNudgeKey);
    if (lastNudge != null) {
      final lastNudgeTime = DateTime.parse(lastNudge);
      if (DateTime.now().difference(lastNudgeTime).inHours < 4) {
        return null;
      }
    }

    final streak = _streakService.getCurrentStreak();
    final pendingTodos = todos.where((t) => !t.isCompleted).toList();

    // Empty pending tasks - encourage to add more
    if (pendingTodos.isEmpty && goals.isNotEmpty) {
      return SmartNudge.suggestion(
        title: 'Ready for more?',
        message: "You've completed all your tasks! Add more to keep your momentum.",
        suggestedAction: 'Add a new task',
      );
    }

    // Streak motivation
    if (streak >= 7 && pendingTodos.isNotEmpty) {
      final urgentTask = pendingTodos.firstWhere(
        (t) => t.effectiveEisenhowerClass == EisenhowerClass.doNow,
        orElse: () => pendingTodos.first,
      );

      return SmartNudge.streakMotivation(
        streak: streak,
        message: "$streak-day streak! Keep it going with: ${urgentTask.title}",
        suggestedTask: urgentTask,
      );
    }

    // Find high-impact task
    final highImpactTodos = pendingTodos
        .where((t) => t.isHighImpact && (t.alignmentScore ?? 0) >= 70)
        .toList();

    if (highImpactTodos.isNotEmpty) {
      final task = highImpactTodos.first;
      return SmartNudge.suggestion(
        title: 'High-impact opportunity',
        message: "${task.title} aligns well with your goals. Great time to tackle it!",
        suggestedAction: task.title,
      );
    }

    // Low pending time warning
    final now = DateTime.now();
    if (now.hour >= 18 && now.hour <= 21) {
      return SmartNudge.reminder(
        title: 'Evening check-in',
        message: 'One task before bed keeps the streak alive!',
        urgency: NudgeUrgency.medium,
      );
    }

    return null;
  }

  // ── Points & Levels ────────────────────────────────────────────────

  int getTotalPoints() => _prefs.getInt(_totalPointsKey) ?? 0;

  int getLevel() => _prefs.getInt(_levelKey) ?? 1;

  /// Calculate points for a completed todo
  int _calculatePoints(Todo todo) {
    int basePoints = 10;

    // Effort bonus
    basePoints += (todo.estimatedEffort ?? 3) * 2;

    // Alignment bonus
    if (todo.alignmentScore != null) {
      basePoints += ((todo.alignmentScore! / 100) * 15).round();
    }

    // SMART score bonus
    if (todo.smartScores != null) {
      basePoints += ((todo.smartScore / 100) * 10).round();
    }

    // Eisenhower bonus (Q1/Q2 are more valuable)
    if (todo.isHighImpact) {
      basePoints += 5;
    }

    // AI-generated bonus (using AI features)
    if (todo.aiGenerated) {
      basePoints += 3;
    }

    // Streak bonus
    final streak = _streakService.getCurrentStreak();
    if (streak >= 7) basePoints += 5;
    if (streak >= 14) basePoints += 5;
    if (streak >= 30) basePoints += 10;

    return basePoints;
  }

  /// Add points and check for level up
  LevelUpResult? addPoints(int points) {
    final currentTotal = getTotalPoints();
    final currentLevel = getLevel();
    final newTotal = currentTotal + points;

    _prefs.setInt(_totalPointsKey, newTotal);

    final newLevel = _calculateLevel(newTotal);
    if (newLevel > currentLevel) {
      _prefs.setInt(_levelKey, newLevel);
      return LevelUpResult(
        previousLevel: currentLevel,
        newLevel: newLevel,
        totalPoints: newTotal,
      );
    }

    return null;
  }

  int _calculateLevel(int totalPoints) {
    // Level progression: each level requires more points
    // Level 1: 0-50, Level 2: 51-150, Level 3: 151-300, etc.
    return (sqrt(totalPoints / 25)).floor() + 1;
  }

  int getPointsToNextLevel() {
    final currentLevel = getLevel();
    final pointsForNextLevel = (currentLevel * currentLevel * 25);
    return pointsForNextLevel - getTotalPoints();
  }

  double getLevelProgress() {
    final currentLevel = getLevel();
    final currentPoints = getTotalPoints();
    final levelStart = ((currentLevel - 1) * (currentLevel - 1) * 25);
    final levelEnd = (currentLevel * currentLevel * 25);

    return ((currentPoints - levelStart) / (levelEnd - levelStart)).clamp(0.0, 1.0);
  }

  // ── Achievements ────────────────────────────────────────────────────

  List<Achievement> getAchievements() {
    final raw = _prefs.getString(_achievementsKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List;
    return list.map((j) => Achievement.fromJson(j)).toList();
  }

  /// Check for new achievements
  List<Achievement> checkAchievements(List<Goal> goals, List<Todo> todos) {
    final unlocked = <Achievement>[];
    final existingIds = getAchievements().map((a) => a.id).toSet();

    // Check each potential achievement
    final potentialAchievements = _getAllPotentialAchievements(goals, todos);

    for (final achievement in potentialAchievements) {
      if (!existingIds.contains(achievement.id) && achievement.isUnlocked) {
        unlocked.add(achievement);
      }
    }

    // Save new achievements
    if (unlocked.isNotEmpty) {
      final all = [...getAchievements(), ...unlocked];
      _prefs.setString(_achievementsKey, jsonEncode(all.map((a) => a.toJson()).toList()));
    }

    return unlocked;
  }

  List<Achievement> _getAllPotentialAchievements(List<Goal> goals, List<Todo> todos) {
    final streak = _streakService.getCurrentStreak();
    final completedTodos = todos.where((t) => t.isCompleted).length;
    final highAlignmentTodos = todos.where((t) => (t.alignmentScore ?? 0) >= 80).length;
    final totalPoints = getTotalPoints();

    return [
      // Streak achievements
      Achievement(
        id: 'streak_3',
        title: '3-Day Streak',
        description: 'Complete tasks for 3 consecutive days',
        emoji: '🔥',
        isUnlocked: streak >= 3,
        category: AchievementCategory.consistency,
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Maintain a 7-day streak',
        emoji: '⚔️',
        isUnlocked: streak >= 7,
        category: AchievementCategory.consistency,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Monthly Master',
        description: 'Achieve a 30-day streak',
        emoji: '👑',
        isUnlocked: streak >= 30,
        category: AchievementCategory.consistency,
      ),

      // Completion achievements
      Achievement(
        id: 'complete_10',
        title: 'Getting Started',
        description: 'Complete 10 tasks',
        emoji: '🌱',
        isUnlocked: completedTodos >= 10,
        category: AchievementCategory.productivity,
      ),
      Achievement(
        id: 'complete_50',
        title: 'Momentum Builder',
        description: 'Complete 50 tasks',
        emoji: '🚀',
        isUnlocked: completedTodos >= 50,
        category: AchievementCategory.productivity,
      ),
      Achievement(
        id: 'complete_100',
        title: 'Century Club',
        description: 'Complete 100 tasks',
        emoji: '💯',
        isUnlocked: completedTodos >= 100,
        category: AchievementCategory.productivity,
      ),

      // Alignment achievements
      Achievement(
        id: 'alignment_5',
        title: 'Sharp Shooter',
        description: 'Complete 5 tasks with 80%+ alignment',
        emoji: '🎯',
        isUnlocked: highAlignmentTodos >= 5,
        category: AchievementCategory.alignment,
      ),
      Achievement(
        id: 'alignment_20',
        title: 'Laser Focused',
        description: 'Complete 20 high-alignment tasks',
        emoji: '💎',
        isUnlocked: highAlignmentTodos >= 20,
        category: AchievementCategory.alignment,
      ),

      // Points achievements
      Achievement(
        id: 'points_500',
        title: 'Point Collector',
        description: 'Earn 500 points',
        emoji: '⭐',
        isUnlocked: totalPoints >= 500,
        category: AchievementCategory.mastery,
      ),
      Achievement(
        id: 'points_2000',
        title: 'Point Master',
        description: 'Earn 2,000 points',
        emoji: '🏆',
        isUnlocked: totalPoints >= 2000,
        category: AchievementCategory.mastery,
      ),
    ];
  }

  // ── Daily Wins ────────────────────────────────────────────────────

  List<String> getDailyWins() {
    return _prefs.getStringList(_dailyWinsKey) ?? [];
  }

  void addDailyWin(String win) {
    final wins = getDailyWins();
    final today = _getTodayString();

    // Reset wins if it's a new day
    final todayWins = wins.where((w) => w.startsWith(today)).toList();
    if (todayWins.length >= 3) return; // Max 3 wins per day

    wins.add('$today:$win');
    _prefs.setStringList(_dailyWinsKey, wins);
  }

  List<String> getTodaysWins() {
    final wins = getDailyWins();
    final today = _getTodayString();
    return wins
        .where((w) => w.startsWith(today))
        .map((w) => w.split(':').skip(1).join(':'))
        .toList();
  }

  // ── Message Generation ─────────────────────────────────────────────

  String _generateHighAlignmentMessage(Todo todo, Goal goal) {
    final messages = [
      "Bullseye! This task perfectly aligns with '${goal.title}'",
      "Right on target! ${todo.title} is highly aligned",
      "Laser focused! You're crushing it with this one",
      "Perfect alignment! This is exactly what moves the needle",
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _generateSmartMessage(Todo todo) {
    final strongArea = todo.smartScores?.strongestDimension ?? '';

    return "SMART score: ${todo.smartScore.round()}! Strong on $strongArea";
  }

  String _generateHighImpactMessage(Todo todo) {
    final eClass = todo.effectiveEisenhowerClass;
    if (eClass == EisenhowerClass.doNow) {
      return "Crisis handled! You knocked out an urgent task";
    } else {
      return "Strategic win! You invested in what matters most";
    }
  }

  String _generateGoalCompleteMessage(Goal goal) {
    final messages = [
      "Goal achieved! '${goal.title}' is complete!",
      "You did it! '${goal.title}' crossed off the list!",
      "Massive win! You've completed '${goal.title}'",
      "Champion! '${goal.title}' is now in your trophy case!",
    ];
    return messages[Random().nextInt(messages.length)];
  }

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ── Data Models ────────────────────────────────────────────────────

enum CelebrationType {
  highAlignment,
  smartExcellence,
  highImpact,
  goalComplete,
  streakSupport, // ADHD-friendly: supportive messages, not warnings
  levelUp,
  achievement,
  initiation, // ADHD-friendly: reward for starting
  continuation, // ADHD-friendly: reward for sustained focus
}

class Celebration {
  final CelebrationType type;
  final String message;
  final int points;
  final int? streak;
  final int? hoursLeft;
  final Achievement? achievement;

  const Celebration({
    required this.type,
    required this.message,
    this.points = 0,
    this.streak,
    this.hoursLeft,
    this.achievement,
  });

  factory Celebration.highAlignment({required String message, required int points}) =>
      Celebration(type: CelebrationType.highAlignment, message: message, points: points);

  factory Celebration.smartExcellence({required String message, required int points}) =>
      Celebration(type: CelebrationType.smartExcellence, message: message, points: points);

  factory Celebration.highImpact({required String message, required int points}) =>
      Celebration(type: CelebrationType.highImpact, message: message, points: points);

  factory Celebration.goalComplete({required String message, required int points}) =>
      Celebration(type: CelebrationType.goalComplete, message: message, points: points);

  factory Celebration.streakSupport({required int streak, required String message}) =>
      Celebration(
        type: CelebrationType.streakSupport,
        message: message,
        streak: streak,
      );

  factory Celebration.initiation({required String todoTitle, required int points}) =>
      Celebration(
        type: CelebrationType.initiation,
        message: 'Started "$todoTitle" - momentum begins!',
        points: points,
      );

  factory Celebration.continuation({required int minutesFocused, required int points}) =>
      Celebration(
        type: CelebrationType.continuation,
        message: '$minutesFocused min of focus - you\'re in the flow!',
        points: points,
      );

  factory Celebration.levelUp({required int level, required int points}) =>
      Celebration(
        type: CelebrationType.levelUp,
        message: 'Level Up! You reached Level $level!',
        points: points,
      );

  factory Celebration.achievementUnlocked(Achievement achievement) =>
      Celebration(
        type: CelebrationType.achievement,
        message: 'Achievement: ${achievement.title}',
        achievement: achievement,
      );

  String get emoji => switch (type) {
    CelebrationType.highAlignment => '🎯',
    CelebrationType.smartExcellence => '⭐',
    CelebrationType.highImpact => '💪',
    CelebrationType.goalComplete => '🏆',
    CelebrationType.streakSupport => '🔥',
    CelebrationType.levelUp => '🎉',
    CelebrationType.achievement => '🏅',
    CelebrationType.initiation => '🚀',
    CelebrationType.continuation => '⚡',
  };
}

enum NudgeUrgency { low, medium, high }

class SmartNudge {
  final String title;
  final String message;
  final String? suggestedAction;
  final Todo? suggestedTask;
  final NudgeUrgency urgency;
  final int? streak;

  const SmartNudge({
    required this.title,
    required this.message,
    this.suggestedAction,
    this.suggestedTask,
    required this.urgency,
    this.streak,
  });

  factory SmartNudge.suggestion({required String title, required String message, required String suggestedAction}) =>
      SmartNudge(title: title, message: message, suggestedAction: suggestedAction, urgency: NudgeUrgency.low);

  factory SmartNudge.streakMotivation({required int streak, required String message, required Todo suggestedTask}) =>
      SmartNudge(
        title: 'Keep the streak!',
        message: message,
        suggestedTask: suggestedTask,
        urgency: NudgeUrgency.high,
        streak: streak,
      );

  factory SmartNudge.reminder({required String title, required String message, required NudgeUrgency urgency}) =>
      SmartNudge(title: title, message: message, urgency: urgency);
}

class LevelUpResult {
  final int previousLevel;
  final int newLevel;
  final int totalPoints;

  const LevelUpResult({
    required this.previousLevel,
    required this.newLevel,
    required this.totalPoints,
  });
}

/// Result of awarding initiation XP (ADHD-friendly dopamine hit)
class InitiationResult {
  final int points;
  final LevelUpResult? levelUp;
  final bool isFirstTaskOfDay;

  const InitiationResult({
    required this.points,
    this.levelUp,
    required this.isFirstTaskOfDay,
  });
}

/// Result of awarding continuation XP (sustained focus reward)
class ContinuationResult {
  final int points;
  final int minutesFocused;
  final LevelUpResult? levelUp;

  const ContinuationResult({
    required this.points,
    required this.minutesFocused,
    this.levelUp,
  });
}

enum AchievementCategory {
  consistency,
  productivity,
  alignment,
  mastery,
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool isUnlocked;
  final AchievementCategory category;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.isUnlocked,
    required this.category,
    this.unlockedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'isUnlocked': isUnlocked,
        'category': category.name,
        'unlockedAt': unlockedAt?.toIso8601String(),
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        emoji: json['emoji'],
        isUnlocked: json['isUnlocked'] ?? false,
        category: AchievementCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => AchievementCategory.productivity,
        ),
        unlockedAt: json['unlockedAt'] != null ? DateTime.parse(json['unlockedAt']) : null,
      );
}
