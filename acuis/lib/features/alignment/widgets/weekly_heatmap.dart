import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../models/todo.dart';

/// Weekly Heatmap Widget
///
/// GitHub-style heatmap showing completion patterns over the last 7 weeks
class WeeklyHeatmap extends StatelessWidget {
  final List<Todo> todos;

  const WeeklyHeatmap({super.key, required this.todos});

  @override
  Widget build(BuildContext context) {
    final heatmapData = _generateHeatmapData();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Activity Heatmap',
                style: GoogleFonts.comfortaa(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Last 49 days',
                  style: GoogleFonts.comfortaa(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeatmap(heatmapData),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  Map<DateTime, int> _generateHeatmapData() {
    final data = <DateTime, int>{};
    final now = DateTime.now();

    // Initialize last 49 days with 0
    for (int i = 0; i < 49; i++) {
      final date = now.subtract(Duration(days: i));
      final normalizedDate = DateTime(date.year, date.month, date.day);
      data[normalizedDate] = 0;
    }

    // Count completed todos per day
    for (final todo in todos.where((t) => t.completed)) {
      final date = DateTime(
        todo.createdAt.year,
        todo.createdAt.month,
        todo.createdAt.day,
      );
      if (data.containsKey(date)) {
        data[date] = (data[date] ?? 0) + 1;
      }
    }

    return data;
  }

  Widget _buildHeatmap(Map<DateTime, int> data) {
    final sortedDates = data.keys.toList()..sort();
    final weeks = <List<DateTime>>[];

    // Group by weeks (7 days each)
    for (int i = 0; i < sortedDates.length; i += 7) {
      final week = sortedDates.skip(i).take(7).toList();
      weeks.add(week);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weeks.map((week) => _buildWeekColumn(week, data)).toList(),
    );
  }

  Widget _buildWeekColumn(List<DateTime> week, Map<DateTime, int> data) {
    return Column(
      children: week.map((date) {
        final count = data[date] ?? 0;
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: _getColorForCount(count),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }

  Color _getColorForCount(int count) {
    if (count == 0) return AppColors.border;
    if (count == 1) return const Color(0xFFC6E48B);
    if (count == 2) return const Color(0xFF7BC96F);
    if (count >= 3) return const Color(0xFF239A3B);
    return AppColors.border;
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Less',
          style: GoogleFonts.comfortaa(
            fontSize: 9,
            color: AppColors.inkFaint,
          ),
        ),
        const SizedBox(width: 4),
        _buildLegendBox(AppColors.border),
        _buildLegendBox(const Color(0xFFC6E48B)),
        _buildLegendBox(const Color(0xFF7BC96F)),
        _buildLegendBox(const Color(0xFF239A3B)),
        const SizedBox(width: 4),
        Text(
          'More',
          style: GoogleFonts.comfortaa(
            fontSize: 9,
            color: AppColors.inkFaint,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
