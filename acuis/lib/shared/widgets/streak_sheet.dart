import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../services/streak_service.dart';

void showStreakSheet(BuildContext context, StreakService streakService) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _StreakSheet(streakService: streakService),
  );
}

class _StreakSheet extends StatelessWidget {
  final StreakService streakService;
  const _StreakSheet({required this.streakService});

  /// Returns the Monday of the week containing [date].
  DateTime _weekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Builds data for the current week and the 3 weeks before it.
  List<_WeekRow> _buildWeeks(Set<String> completedDates) {
    final today = DateTime.now();
    final weeks = <_WeekRow>[];

    for (int w = 0; w < 4; w++) {
      final monday = _weekStart(today.subtract(Duration(days: w * 7)));
      final days = List.generate(7, (i) => monday.add(Duration(days: i)));
      weeks.add(_WeekRow(days: days, completedDates: completedDates, today: today));
    }

    return weeks;
  }

  @override
  Widget build(BuildContext context) {
    final completedDates = streakService.getCompletionDates();
    final currentStreak = streakService.getCurrentStreak();
    final longestStreak = streakService.getLongestStreak();
    final weeks = _buildWeeks(completedDates);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 22, color: Color(0xFFFF6B35)),
              const SizedBox(width: 10),
              Text('Streak',
                  style: GoogleFonts.comfortaa(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              _StatChip(label: 'Current', value: '$currentStreak days'),
              const SizedBox(width: 10),
              _StatChip(label: 'Longest', value: '$longestStreak days'),
            ],
          ),
          const SizedBox(height: 24),
          // Day-of-week header
          _DayHeader(),
          const SizedBox(height: 8),
          // Weeks (most recent first)
          ...weeks.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WeekRowWidget(week: w),
              )),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _labels
          .map((l) => Expanded(
                child: Center(
                  child: Text(l,
                      style: GoogleFonts.comfortaa(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkFaint)),
                ),
              ))
          .toList(),
    );
  }
}

class _WeekRow {
  final List<DateTime> days;
  final Set<String> completedDates;
  final DateTime today;

  const _WeekRow({
    required this.days,
    required this.completedDates,
    required this.today,
  });

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isCompleted(DateTime d) => completedDates.contains(_fmt(d));
  bool isToday(DateTime d) => _fmt(d) == _fmt(today);
  bool isFuture(DateTime d) => d.isAfter(today);
}

class _WeekRowWidget extends StatelessWidget {
  final _WeekRow week;
  const _WeekRowWidget({required this.week});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: week.days.map((day) {
        final completed = week.isCompleted(day);
        final isToday = week.isToday(day);
        final isFuture = week.isFuture(day);

        return Expanded(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: completed
                    ? AppColors.ink
                    : isToday
                        ? AppColors.chip
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !completed
                    ? Border.all(color: AppColors.ink, width: 1.5)
                    : null,
              ),
              child: Center(
                child: isFuture
                    ? null
                    : completed
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${day.day}',
                            style: GoogleFonts.comfortaa(
                              fontSize: 12,
                              fontWeight: isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isToday
                                  ? AppColors.ink
                                  : AppColors.inkFaint,
                            ),
                          ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.comfortaa(
                  fontSize: 11, color: AppColors.inkFaint)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.comfortaa(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
        ],
      ),
    );
  }
}
