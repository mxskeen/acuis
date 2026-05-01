import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_energy.dart';

/// Mood Check Service
///
/// Manages daily energy/mood check-ins for ADHD-aware task recommendations.
/// Tracks patterns and provides energy-appropriate nudges.
class MoodCheckService {
  static const _energyKey = 'user_energy_records';
  static const _lastCheckInKey = 'last_energy_check_in';
  static const _checkInDismissedKey = 'energy_check_in_dismissed';
  static const _insightsKey = 'energy_pattern_insights';

  static const int _minRecordsForInsight = 7;

  final SharedPreferences _prefs;

  MoodCheckService(this._prefs);

  static Future<MoodCheckService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return MoodCheckService(prefs);
  }

  // ── Check-in Management ─────────────────────────────────────

  /// Should show check-in today?
  bool shouldShowCheckIn() {
    // Show if:
    // 1. Never checked in before
    // 2. Last check-in was yesterday or earlier
    // 3. User hasn't dismissed it today

    final lastCheckIn = getLastCheckInDate();
    final today = _getTodayString();

    if (lastCheckIn == null) return true;
    if (lastCheckIn != today) {
      // New day - reset dismissed flag
      _prefs.remove(_checkInDismissedKey);
      return true;
    }

    // Same day - check if dismissed
    final dismissed = _prefs.getBool(_checkInDismissedKey);
    return dismissed != null ? !dismissed : true;
  }

  /// Mark check-in as dismissed today
  Future<void> dismissCheckIn() async {
    await _prefs.setBool(_checkInDismissedKey, true);
  }

  /// Mark "don't ask again" (permanently disabled until re-enabled)
  Future<void> disableCheckIn() async {
    await _prefs.setBool('energy_check_in_disabled', true);
  }

  /// Check if check-in is permanently disabled
  bool isCheckInDisabled() {
    return _prefs.getBool('energy_check_in_disabled') ?? false;
  }

  /// Re-enable check-in
  Future<void> enableCheckIn() async {
    await _prefs.remove('energy_check_in_disabled');
    await _prefs.remove(_checkInDismissedKey);
  }

  // ── Energy Recording ────────────────────────────────────────

  /// Record user's energy level for today
  Future<void> recordEnergy(
    EnergyLevel level, {
    MoodTag? mood,
    bool isCheckIn = true,
  }) async {
    final record = UserEnergy(
      level: level,
      mood: mood,
      recordedAt: DateTime.now(),
    );

    // Store in history
    final records = _getAllRecords();
    records.add(record);

    // Limit to last 90 days to prevent storage bloat
    while (records.length > 90) {
      records.removeAt(0);
    }

    await _prefs.setString(_energyKey, jsonEncode(
      records.map((r) => r.toJson()).toList(),
    ));

    // Mark check-in complete
    if (isCheckIn) {
      await _prefs.setString(_lastCheckInKey, _getTodayString());
      await _prefs.remove(_checkInDismissedKey);
    }

    // Generate insights if we have enough data
    await _generateInsights();
  }

  /// Get today's energy level (null if not set)
  UserEnergy? getTodaysEnergy() {
    final records = _getAllRecords();

    try {
      return records.lastWhere(
        (r) =>
            r.recordedAt.year == DateTime.now().year &&
            r.recordedAt.month == DateTime.now().month &&
            r.recordedAt.day == DateTime.now().day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get last check-in date string
  String? getLastCheckInDate() {
    return _prefs.getString(_lastCheckInKey);
  }

  /// Get all energy records
  List<UserEnergy> _getAllRecords() {
    final raw = _prefs.getString(_energyKey);
    if (raw == null) return [];

    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => UserEnergy.fromJson(j))
          .toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    } catch (e) {
      return [];
    }
  }

  // ── Energy-Aware Recommendations ────────────────────────────

  /// Get current energy recommendation
  EnergyRecommendation getRecommendation() {
    final energy = getTodaysEnergy();

    if (energy == null) {
      return const EnergyRecommendation(
        canShowNudges: true,
        suggestedTaskTypes: ['any'],
        tone: 'neutral',
        maxSuggestedTasks: 5,
      );
    }

    // Sick day - no nudges, just rest
    if (energy.mood == MoodTag.sick) {
      return const EnergyRecommendation(
        canShowNudges: false,
        suggestedTaskTypes: [],
        tone: 'supportive',
        message: 'Take care of yourself today. Your tasks can wait.',
      );
    }

    // Stressed - gentle suggestions only
    if (energy.mood == MoodTag.stressed) {
      return const EnergyRecommendation(
        canShowNudges: true,
        suggestedTaskTypes: ['quick_win', 'easy'],
        tone: 'gentle',
        maxSuggestedTasks: 2,
        message: 'One small step at a time. You\'ve got this.',
      );
    }

    // Low energy - tiny tasks only
    if (energy.level == EnergyLevel.low) {
      return const EnergyRecommendation(
        canShowNudges: true,
        suggestedTaskTypes: ['quick_win', '5min'],
        tone: 'encouraging',
        maxSuggestedTasks: 2,
        message: 'Low energy day? Even 5 minutes counts!',
      );
    }

    // Medium energy - normal suggestions
    if (energy.level == EnergyLevel.medium) {
      return const EnergyRecommendation(
        canShowNudges: true,
        suggestedTaskTypes: ['high_impact', 'scheduled'],
        tone: 'neutral',
        maxSuggestedTasks: 4,
      );
    }

    // High energy - tackle challenging tasks
    return const EnergyRecommendation(
      canShowNudges: true,
      suggestedTaskTypes: ['difficult', 'high_impact', 'challenging'],
      tone: 'energetic',
      maxSuggestedTasks: 6,
      message: 'High energy! Perfect time for challenging tasks.',
    );
  }

  /// Check if nudges should be shown based on energy
  bool shouldShowNudges() {
    return getRecommendation().canShowNudges;
  }

  /// Get suggested nudge message based on energy
  String? getNudgeMessage() {
    return getRecommendation().message;
  }

  // ── Pattern Insights ────────────────────────────────────────

  /// Detect patterns from user's energy tracking history
  List<PatternInsight> getInsights() {
    final insightsJson = _prefs.getString(_insightsKey);
    if (insightsJson == null) return [];

    try {
      final list = jsonDecode(insightsJson) as List;
      return list.map((j) => PatternInsight(
        pattern: j['pattern'],
        insight: j['insight'],
        confidence: j['confidence'],
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _generateInsights() async {
    final records = _getAllRecords();
    if (records.length < _minRecordsForInsight) return;

    final insights = <PatternInsight>[];

    // Pattern: Day of week
    final weekdayPatterns = _analyzeWeekdayPatterns(records);
    insights.addAll(weekdayPatterns);

    // Pattern: Energy trends
    final trendPatterns = _analyzeTrends(records);
    insights.addAll(trendPatterns);

    // Save insights
    await _prefs.setString(_insightsKey, jsonEncode(
      insights.map((i) => {
        'pattern': i.pattern,
        'insight': i.insight,
        'confidence': i.confidence,
      }).toList(),
    ));
  }

  List<PatternInsight> _analyzeWeekdayPatterns(List<UserEnergy> records) {
    final insights = <PatternInsight>[];
    final weekdayEnergy = <int, List<EnergyLevel>>{};

    for (final record in records) {
      final weekday = record.recordedAt.weekday;
      weekdayEnergy.putIfAbsent(weekday, () => []).add(record.level);
    }

    // Check for Monday pattern
    if (weekdayEnergy.containsKey(1)) {
      final mondays = weekdayEnergy[1]!;
      final lowCount = mondays.where((e) => e == EnergyLevel.low).length;
      if (lowCount > mondays.length * 0.5 && mondays.length >= 3) {
        insights.add(const PatternInsight(
          pattern: 'Monday Slump',
          insight: 'You often have low energy on Mondays. Consider scheduling lighter tasks.',
          confidence: 0.7,
        ));
      }
    }

    // Check for weekend high energy
    if (weekdayEnergy.containsKey(6) || weekdayEnergy.containsKey(7)) {
      final weekends = [
        ...(weekdayEnergy[6] ?? []),
        ...(weekdayEnergy[7] ?? []),
      ];
      final highCount = weekends.where((e) => e == EnergyLevel.high).length;
      if (highCount > weekends.length * 0.5 && weekends.length >= 3) {
        insights.add(const PatternInsight(
          pattern: 'Weekend Warrior',
          insight: 'You tend to have high energy on weekends. Save challenging tasks for then.',
          confidence: 0.7,
        ));
      }
    }

    return insights;
  }

  List<PatternInsight> _analyzeTrends(List<UserEnergy> records) {
    final insights = <PatternInsight>[];

    // Check for consecutive low energy days
    int lowStreak = 0;
    for (final record in records.reversed.take(7)) {
      if (record.level == EnergyLevel.low) {
        lowStreak++;
      } else {
        break;
      }
    }

    if (lowStreak >= 3) {
      insights.add(const PatternInsight(
        pattern: 'Low Energy Streak',
        insight: 'You\'ve had several low-energy days. Consider taking a full rest day.',
        confidence: 0.8,
      ));
    }

    return insights;
  }

  // ── Helper Methods ─────────────────────────────────────────

  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

/// Energy-based recommendation for task suggestions
class EnergyRecommendation {
  final bool canShowNudges;
  final List<String> suggestedTaskTypes;
  final String tone; // 'supportive', 'gentle', 'encouraging', 'neutral', 'energetic'
  final int? maxSuggestedTasks;
  final String? message;

  const EnergyRecommendation({
    required this.canShowNudges,
    required this.suggestedTaskTypes,
    required this.tone,
    this.maxSuggestedTasks,
    this.message,
  });
}
